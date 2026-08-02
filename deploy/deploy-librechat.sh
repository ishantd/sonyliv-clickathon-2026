#!/usr/bin/env bash
# deploy-librechat.sh — render the Langfuse prompt, ship the LibreChat stack, bring it up.
#
#   LIBRECHAT_HOST=ec2-user@1.2.3.4 ./deploy/deploy-librechat.sh
#   LIBRECHAT_HOST=... ./deploy/deploy-librechat.sh --check    verify without shipping
#   LIBRECHAT_HOST=... ./deploy/deploy-librechat.sh --sync     prompt only, then restart api
#
# One-time box setup is in deploy/README.md: docker, nginx, /etc/sonyliv/librechat.env, and
# the security-group rule for 8443. This script assumes all of it and fails loudly if any
# is missing rather than half-configuring the box.
#
# Order matters: the prompt is rendered and validated LOCALLY first, so a Langfuse outage
# stops the deploy before anything on the box has been touched.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/.." && pwd)"

host="${LIBRECHAT_HOST:-${DEPLOY_HOST:-}}"
[[ -n "$host" ]] || { echo "deploy-librechat.sh: set LIBRECHAT_HOST=user@host" >&2; exit 2; }

remote_dir="${LIBRECHAT_DIR:-/opt/sonyliv/librechat}"

mode=deploy
case "${1:-}" in
    --check) mode=check ;;
    --sync)  mode=sync ;;
    "")      ;;
    *)       echo "deploy-librechat.sh: unknown flag $1" >&2; exit 2 ;;
esac

# ---------------------------------------------------------------------------
# Verification. Run after every deploy, and on its own with --check.
#
# Each step fails for a different reason, so they are separate lines with separate
# messages: "LibreChat is up but the MCP server is unreachable" and "LibreChat is down" want
# very different next actions.
# ---------------------------------------------------------------------------
remote_check() {
    # shellcheck disable=SC2029
    ssh "$host" "set -uo pipefail
        cd '$remote_dir'
        fail=0

        echo '== containers =='
        docker compose ps --format 'table {{.Service}}\t{{.Status}}'

        echo '== librechat =='
        if curl -fsS --max-time 10 http://127.0.0.1:3080/health >/dev/null; then
            echo '  ok  127.0.0.1:3080/health'
        else
            echo '  FAIL  LibreChat is not answering on 3080'; fail=1
        fi

        echo '== litellm -> gemini =='
        if docker compose exec -T litellm curl -fsS --max-time 10 \
             http://localhost:4000/health/liveliness >/dev/null; then
            echo '  ok  proxy alive'
        else
            echo '  FAIL  LiteLLM is not alive; traces will not reach Langfuse'; fail=1
        fi

        echo '== mcp, from inside the api container =='
        # The step that actually proves the integration. Reaching the MCP server from the
        # host proves nothing about whether the CONTAINER can, and that gap -- host.docker
        # .internal unresolved, or the server still bound to the host loopback -- is the
        # most likely way this deployment fails.
        eval \"\$(sudo bash -c 'grep -E \"^SONYLIV_MCP_TOKEN=\" /etc/sonyliv/mcp.env')\"
        body='{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2024-11-05\",\"capabilities\":{},\"clientInfo\":{\"name\":\"deploy-check\",\"version\":\"1\"}}}'
        if docker compose exec -T api curl -fsS --max-time 15 \
             -H 'Content-Type: application/json' \
             -H \"Authorization: Bearer \$SONYLIV_MCP_TOKEN\" \
             -X POST http://host.docker.internal:8848/mcp -d \"\$body\" \
             | grep -q 'NEVER SUM OR AVERAGE A PEAK'; then
            echo '  ok  reachable, and returning its operating rules'
        else
            echo '  FAIL  the api container cannot reach the MCP server'; fail=1
        fi

        echo '== nginx =='
        if curl -fsSk --max-time 10 https://127.0.0.1/ -o /dev/null; then
            echo '  ok  :443  -> LibreChat'
        else
            echo '  FAIL  :443 is not serving LibreChat'; fail=1
        fi
        if curl -fsSk --max-time 10 https://127.0.0.1:8443/ -o /dev/null; then
            echo '  ok  :8443 -> fleet dashboard'
        else
            echo '  FAIL  :8443 is not serving the dashboard'; fail=1
        fi

        exit \$fail"
}

if [[ "$mode" == check ]]; then
    remote_check
    exit $?
fi

# ---------------------------------------------------------------------------
# 1. Prompt. Local, and before anything is shipped.
# ---------------------------------------------------------------------------
echo "== rendering librechat.yaml from Langfuse =="
"$repo/deploy/langfuse-prompt-sync.sh"

# ---------------------------------------------------------------------------
# 2. Preflight the box. Cheaper to find a missing env file now than after a transfer.
# ---------------------------------------------------------------------------
echo "== preflight =="
# shellcheck disable=SC2029
ssh "$host" "set -euo pipefail
    command -v docker >/dev/null || { echo 'docker is not installed (see deploy/README.md)' >&2; exit 1; }
    docker compose version >/dev/null || { echo 'docker compose v2 is missing' >&2; exit 1; }
    sudo bash -c 'test -r /etc/sonyliv/librechat.env' \
        || { echo '/etc/sonyliv/librechat.env is missing (see deploy/librechat/.env.example)' >&2; exit 1; }
    sudo mkdir -p '$remote_dir'
    sudo chown \"\$(id -u):\$(id -g)\" '$remote_dir'

    # LibreChat + Mongo + LiteLLM want roughly 2 GB. Discovering that after the images are
    # pulled costs ten minutes and an OOM-killed container that looks like a config bug.
    avail=\$(free -m | awk '/^Mem:/{print \$7}')
    echo \"  available memory: \${avail} MB\"
    if [ \"\$avail\" -lt 1800 ]; then
        echo \"  WARNING: under 1.8 GB available. Expect the OOM killer.\" >&2
    fi"

# ---------------------------------------------------------------------------
# 3. Ship. rsync so a redeploy moves only what changed.
# ---------------------------------------------------------------------------
echo "== ship =="
rsync -az --delete \
    --exclude 'data-node/' --exclude 'images/' --exclude 'uploads/' --exclude 'logs/' \
    "$repo/deploy/librechat/" "$host:$remote_dir/"
echo "  synced $remote_dir"

if [[ "$mode" == sync ]]; then
    # shellcheck disable=SC2029
    ssh "$host" "cd '$remote_dir' && docker compose up -d --force-recreate api"
    echo "  api restarted on the new prompt"
    remote_check
    exit $?
fi

# ---------------------------------------------------------------------------
# 4. Up, then verify. `up -d` and not `restart`: the compose file itself may have changed.
# ---------------------------------------------------------------------------
echo "== up =="
# shellcheck disable=SC2029
ssh "$host" "set -euo pipefail
    cd '$remote_dir'
    docker compose pull --quiet
    docker compose up -d
    # LibreChat builds its client on first boot and is slow to answer until it has.
    for i in \$(seq 1 60); do
        curl -fsS --max-time 3 http://127.0.0.1:3080/health >/dev/null && break
        sleep 3
    done"

echo
remote_check
rc=$?

echo
if [[ $rc -eq 0 ]]; then
    echo "done."
    echo "  LibreChat  https://<host>/       (register once, then set ALLOW_REGISTRATION=false)"
    echo "  dashboard  https://<host>:8443/"
    echo "  traces     your Langfuse project"
else
    echo "deploy finished with failing checks above -- the stack is up but not proven." >&2
fi
exit $rc
