#!/usr/bin/env bash
# deploy-mcp.sh — build sonyliv-mcp for linux/amd64, ship it to EC2, restart the unit.
#
#   MCP_HOST=ec2-user@1.2.3.4 ./deploy/deploy-mcp.sh
#   MCP_HOST=... ./deploy/deploy-mcp.sh --check     verify a deployment without shipping
#
# Prerequisites on the box, once:
#   sudo useradd --system --shell /usr/sbin/nologin sonyliv
#   sudo mkdir -p /opt/sonyliv/bin /etc/sonyliv
#   sudo install -m 600 -o sonyliv -g sonyliv /dev/null /etc/sonyliv/mcp.env
#
# /etc/sonyliv/mcp.env must contain the RESTRICTED user, not the service user — the
# server refuses to start if it can read events_clean, but do not rely on that as the
# only check:
#
#   CLICKHOUSE_HOST=<service>.clickhouse.cloud
#   CLICKHOUSE_PORT=9440
#   CLICKHOUSE_SECURE=true
#   CLICKHOUSE_DATABASE=sonyliv_prod
#   CLICKHOUSE_USER=sonyliv_mcp
#   CLICKHOUSE_PASSWORD=<the password from 009_mcp_reader.sql>
#   SONYLIV_MCP_TOKEN=<openssl rand -hex 32>
#
# TLS is deliberately NOT handled here. The unit binds 127.0.0.1, so put nginx or a load
# balancer in front with a certificate. Publishing :8848 directly would carry the bearer
# token in plaintext, and that token is SQL access.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/.." && pwd)"

host="${MCP_HOST:-}"
[[ -n "$host" ]] || { echo "deploy-mcp.sh: set MCP_HOST=user@host" >&2; exit 2; }

remote_check() {
  echo "== remote health =="
  # shellcheck disable=SC2029
  ssh "$host" 'systemctl is-active sonyliv-mcp && curl -sS --max-time 5 http://127.0.0.1:8848/healthz'
  echo "== refusals, exercised on the box against the deployed process =="
  # shellcheck disable=SC2029
  ssh "$host" 'set -a; . /etc/sonyliv/mcp.env; set +a
    q() { curl -sS --max-time 30 -H "Content-Type: application/json" \
            -H "Authorization: Bearer $SONYLIV_MCP_TOKEN" -X POST http://127.0.0.1:8848/mcp -d "$1"; }
    echo -n "  currentUser via MCP: "
    q "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"run_select_query\",\"arguments\":{\"query\":\"SELECT 1 FROM serving_watermark\"}}}" | head -c 160; echo
    echo -n "  events_clean refused: "
    q "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"run_select_query\",\"arguments\":{\"query\":\"SELECT count() FROM events_clean\"}}}" | grep -o "outside the serving layer" || echo "NOT REFUSED — investigate"'
}

if [[ "${1:-}" == "--check" ]]; then
  remote_check
  exit 0
fi

echo "== build (linux/amd64) =="
cd "$repo/ingest"
version="$(git -C "$repo" rev-parse --short HEAD 2>/dev/null || echo dev)"
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
  -ldflags "-s -w -X main.buildVersion=$version" \
  -o "$repo/ingest/bin/sonyliv-mcp.linux-amd64" ./cmd/sonyliv-mcp
echo "  built $version"

echo "== ship =="
# Staged into /tmp then installed, so a partial transfer never becomes the live binary.
scp -q "$repo/ingest/bin/sonyliv-mcp.linux-amd64" "$host:/tmp/sonyliv-mcp.new"
scp -q "$here/sonyliv-mcp.service" "$host:/tmp/sonyliv-mcp.service"

echo "== install and restart =="
# shellcheck disable=SC2029
ssh "$host" 'set -euo pipefail
  sudo install -m 0755 -o root -g root /tmp/sonyliv-mcp.new /opt/sonyliv/bin/sonyliv-mcp
  sudo install -m 0644 -o root -g root /tmp/sonyliv-mcp.service /etc/systemd/system/sonyliv-mcp.service
  rm -f /tmp/sonyliv-mcp.new /tmp/sonyliv-mcp.service
  sudo systemctl daemon-reload
  sudo systemctl enable --now sonyliv-mcp
  sudo systemctl restart sonyliv-mcp
  sleep 2
  systemctl is-active sonyliv-mcp'

remote_check
echo
echo "done. Point an MCP client at https://<your-tls-frontend>/mcp with the bearer token."
