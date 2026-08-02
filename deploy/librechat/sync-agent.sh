#!/usr/bin/env bash
# sync-agent.sh — create or update the LibreChat Agent that owns the MCP tools.
#
#   Run ON THE BOX, from /opt/sonyliv/librechat, after langfuse-prompt-sync.sh:
#     ./sync-agent.sh
#
# WHY AN AGENT AT ALL, when librechat.yaml can already configure the MCP server.
#
# Because a plain endpoint requires the person to pick the MCP server from the chat-area
# dropdown, per conversation. Nobody does. And the failure when they do not is silent and
# actively misleading: the analyst prompt says "answer from a tool call, never from
# memory", so with no tools attached Gemini either invents a plausible-looking answer or
# returns an empty candidate. The first demo of this deployment hit exactly that -- an
# empty bubble, no error anywhere.
#
# An Agent binds the tools permanently. There is no state a user can forget to set.
#
# The instructions come from agent-instructions.txt, which langfuse-prompt-sync.sh writes
# from the production-labelled Langfuse prompt -- so Langfuse stays the source of truth on
# this path too, and the version stamp still rides in the system message.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
base="${LIBRECHAT_URL:-http://127.0.0.1:3080}"
instructions_file="${INSTRUCTIONS_FILE:-$here/agent-instructions.txt}"
id_file="${AGENT_ID_FILE:-$here/agent-id}"
mcp_server="${MCP_SERVER_NAME:-sonyliv-serving}"

: "${LIBRECHAT_EMAIL:?set LIBRECHAT_EMAIL (the account that owns the agent)}"
: "${LIBRECHAT_PASSWORD:?set LIBRECHAT_PASSWORD}"

[[ -r "$instructions_file" ]] || {
    echo "sync-agent: no $instructions_file — run langfuse-prompt-sync.sh first" >&2; exit 1; }

# LibreChat's uaParser middleware rejects anything it cannot parse as a BROWSER with the
# unhelpful message `{"message":"Illegal request"}` — and it returns that as an SSE `event:
# error` body under HTTP 200, so a status check passes and only the JSON parse fails, three
# steps later, with "Invalid numeric literal". An honest `sonyliv-deploy/1.0` is refused;
# only a browser-shaped string gets through. Not a header we would choose to send, but the
# alternative is no scripted access to the API at all.
UA='Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'
api() { # api METHOD PATH [DATA]
    local m="$1" p="$2"; shift 2
    curl -sS --max-time 60 -X "$m" "$base$p" \
        -H 'Content-Type: application/json' -H "User-Agent: $UA" \
        ${TOKEN:+-H "Authorization: Bearer $TOKEN"} "$@"
}

echo "== authenticating as $LIBRECHAT_EMAIL =="
TOKEN=""
TOKEN="$(api POST /api/auth/login --data-binary \
    "$(jq -n --arg e "$LIBRECHAT_EMAIL" --arg p "$LIBRECHAT_PASSWORD" \
        '{email:$e, password:$p}')" | jq -r '.token // empty')"
[[ -n "$TOKEN" ]] || { echo "sync-agent: login failed" >&2; exit 1; }

# Take the tool list from the running server rather than hardcoding it, so a tool added to
# sonyliv-mcp reaches the agent on the next sync instead of being silently absent.
echo "== reading tools from $mcp_server =="
tools="$(api GET "/api/mcp/tools" | jq -c --arg s "$mcp_server" '[.servers[$s].tools[].pluginKey]')"
n="$(jq 'length' <<<"$tools")"
[[ "$n" -gt 0 ]] || { echo "sync-agent: $mcp_server exposed no tools — is sonyliv-mcp up?" >&2; exit 1; }
echo "  $n tools"

# execute_code — the LibreChat Code Interpreter — is added ONLY when a key is configured.
#
# It cannot be self-hosted on this box. The open-source service (ClickHouse's
# code-interpreter) runs its sandboxes under KVM, and this instance has no /dev/kvm and no
# vmx/svm CPU flags: it is an ordinary EC2 guest, not a metal one. So the sandbox-runner
# cannot start, and the other five components have nothing to run code in.
#
# That leaves LibreChat's hosted API, which is a key and nothing else. Set
# LIBRECHAT_CODE_API_KEY in /etc/sonyliv/librechat.env and re-run this script; the tool
# appears and the agent can render matplotlib PNGs instead of Recharts components.
#
# Adding it WITHOUT a key would be worse than leaving it off: the tool shows up, the model
# reaches for it, and every call fails at the API — which looks like a broken agent rather
# than an unconfigured one.
if [[ -n "${LIBRECHAT_CODE_API_KEY:-}" ]]; then
    tools="$(jq -c '. + ["execute_code"]' <<<"$tools")"
    echo "  + execute_code (code interpreter key is set)"
else
    echo "  no LIBRECHAT_CODE_API_KEY — charts render as artifacts, not executed code"
fi

# artifacts: "default" is what turns "give me a graph" into an actual graph. Without it the
# model answers a charting question with a markdown table, because a table is the best it
# can render. With it, it emits a Recharts component and LibreChat renders an interactive
# chart beside the conversation -- no code execution and no sandbox involved.
body="$(jq -n --arg name 'SonyLIV Concurrency Analyst' \
    --arg desc 'Answers viewing-trend questions from the ClickHouse serving layer.' \
    --rawfile instr "$instructions_file" --argjson tools "$tools" \
    '{name:$name, description:$desc, instructions:$instr,
      provider:"SonyLIV", model:"gemini-3.1-pro", tools:$tools,
      artifacts:"default",
      model_parameters:{temperature:0, maxOutputTokens:8192}}')"

agent_id="$(cat "$id_file" 2>/dev/null || true)"
if [[ -n "$agent_id" ]] && api GET "/api/agents/$agent_id" | jq -e '.id' >/dev/null 2>&1; then
    echo "== updating $agent_id =="
    out="$(api PATCH "/api/agents/$agent_id" --data-binary "$body")"
else
    echo "== creating agent =="
    out="$(api POST /api/agents --data-binary "$body")"
fi

agent_id="$(jq -r '.id // empty' <<<"$out")"
[[ -n "$agent_id" ]] || { echo "sync-agent: no agent id in response: ${out:0:300}" >&2; exit 1; }
printf '%s' "$agent_id" >"$id_file"

echo "  $agent_id with $(jq -r '(.tools|length)' <<<"$out") tools"
echo "  wrote $id_file — librechat.yaml.tmpl reads it for the default modelSpec"

# ---------------------------------------------------------------------------
# Share it. Without this step the agent works for exactly one account.
# ---------------------------------------------------------------------------
#
# THE BUG THIS FIXES, because it is not guessable from the symptom. LibreChat
# 0.8 moved agents onto per-resource ACLs (the `aclentries` collection, granting
# an `accessRoleId` to a principal). Creating an agent grants `agent_owner` to
# its author and nobody else. So the analyst worked perfectly for
# LIBRECHAT_EMAIL and every other account — including the two humans on this
# team — got:
#
#     {"error":"Forbidden","message":"Insufficient permissions to access this agent"}
#
# rendered as a red bubble under their own first message. Nothing in the logs,
# nothing wrong with the model, the MCP server or the prompt. It reads as a
# broken deployment and it is a missing grant.
#
# The share is therefore part of syncing the agent, not a thing someone
# remembers to click afterwards. A deploy step that only works for the person
# who ran it is not a deploy step.
#
# WHY NAMED ACCOUNTS AND NOT `public: true`. The permissions API will happily
# make an agent world-readable, and that is the wrong default here: registration
# on this host is open, so public means anyone who signs up can drive the agent
# and spend the Gemini key. Judges are handed the LIBRECHAT_EMAIL credentials
# and that account OWNS the agent, so they need no grant at all — the only
# people who do are the team, and they are a short list.
#
# LIBRECHAT_SHARE_EMAILS is that list: comma-separated, matched against
# registered accounts, missing ones skipped with a warning rather than failing
# the deploy. Set it in /etc/sonyliv/librechat.env. Unset means "owner only",
# which is the safe reading of an absent variable.
#
# agent_editor rather than agent_viewer: a teammate who can open the agent but
# cannot change its instructions has to come back through this script for every
# prompt tweak, which defeats the point of them having access at all.
if [[ -n "${LIBRECHAT_SHARE_EMAILS:-}" ]]; then
    echo "== sharing $agent_id =="

    # The ACL is keyed on the agent's Mongo _id, NOT on the agent_xxx id the rest
    # of this script uses. They are different identifiers for the same object and
    # passing the wrong one 404s.
    resource_id="$(api GET "/api/agents/$agent_id" | jq -r '._id // empty')"
    if [[ -z "$resource_id" ]]; then
        echo "  cannot read the agent's _id — skipping the share" >&2
    else
        # Resolve emails to user ids through the principal search the sharing UI
        # itself uses, so an address that never registered is reported here rather
        # than silently granted to nothing.
        updated='[]'
        IFS=',' read -ra emails <<<"$LIBRECHAT_SHARE_EMAILS"
        for raw in "${emails[@]}"; do
            email="$(printf '%s' "$raw" | tr -d '[:space:]')"
            [[ -n "$email" ]] || continue
            uid="$(api GET "/api/permissions/search-principals?q=$email&limit=5" \
                | jq -r --arg e "$email" '[.results[]? | select(.email == $e)][0].id // empty')"
            if [[ -z "$uid" ]]; then
                echo "  $email — no such account, skipped (they must sign up first)" >&2
                continue
            fi
            updated="$(jq -c --arg id "$uid" \
                '. + [{type:"user", id:$id, accessRoleId:"agent_editor"}]' <<<"$updated")"
            echo "  $email -> agent_editor"
        done

        if [[ "$(jq 'length' <<<"$updated")" -gt 0 ]]; then
            # public:false is passed explicitly rather than omitted. This endpoint
            # sets the whole sharing state, so leaving it out on a PUT is how an
            # agent quietly becomes public on some future refactor of the payload.
            share="$(jq -n --argjson u "$updated" '{updated:$u, removed:[], public:false}')"
            api PUT "/api/permissions/agent/$resource_id" --data-binary "$share" >/dev/null
            echo "  shared with $(jq 'length' <<<"$updated") account(s), not public"
        fi
    fi
else
    echo "  LIBRECHAT_SHARE_EMAILS unset — agent is owner-only"
    echo "  (any other account gets 'Insufficient permissions to access this agent')"
fi
