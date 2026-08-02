# Deploying to EC2

`deploy.sh` builds the Go binaries locally, ships them over SSH, installs them
atomically, and restarts the service. It does **not** provision the box — that is
a one-time root task, listed below, kept manual because it touches credentials
and a systemd unit and should be auditable rather than a side effect of shipping.

```bash
DEPLOY_HOST=ec2-1-2-3-4.eu-west-1.compute.amazonaws.com ./deploy/deploy.sh
```

`./deploy/deploy.sh --help` lists every flag and variable.

---

## One-time box setup

Everything here runs as root on the EC2 instance, once.

**1. Service account.** Unprivileged, no home, no shell.

```bash
sudo useradd --system --no-create-home --shell /usr/sbin/nologin sonyliv
```

**2. ClickHouse credentials.** `deploy.sh` never writes this file, so your
ClickHouse password never travels through the deploy path.

```bash
sudo mkdir -p /etc/sonyliv
sudo tee /etc/sonyliv/sonyliv.env >/dev/null <<'EOF'
CLICKHOUSE_HOST=your-service.aws.clickhouse.cloud
CLICKHOUSE_PORT=9440
CLICKHOUSE_USER=claude
CLICKHOUSE_PASSWORD=...
CLICKHOUSE_DATABASE=default
CLICKHOUSE_SECURE=true
EOF
sudo chown root:sonyliv /etc/sonyliv/sonyliv.env
sudo chmod 0640 /etc/sonyliv/sonyliv.env
```

Same variable names `ingest/internal/config` already reads, so the CLI and the
API pick them up with no extra wiring. `0640` root:sonyliv — readable by the
service, not by other users on the box.

**3. Sudo for the deploy user.** `deploy.sh` needs root to write `/usr/local/bin`
and restart the unit. Scope it to exactly that rather than granting blanket sudo:

```bash
echo 'ec2-user ALL=(root) NOPASSWD: /bin/bash' | sudo tee /etc/sudoers.d/sonyliv-deploy
sudo chmod 0440 /etc/sudoers.d/sonyliv-deploy
```

The remote half of the deploy is a single `sudo bash -s` invocation, which is why
this is `/bin/bash` rather than a list of commands. That is broad — if you want it
tighter, replace the remote block with a fixed script installed on the box and
grant NOPASSWD on that path alone.

**4. The unit** (only once `sonyliv-api` exists — until then `deploy.sh` detects
the missing unit and skips the restart):

```bash
sudo cp deploy/sonyliv-api.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable sonyliv-api
```

**5. Security group.** The API port should not be reachable from `0.0.0.0/0`. The
deploy's health check runs *on the box* against `127.0.0.1` precisely so shipping
never depends on the port being publicly open.

---

## SSH key

RSA, as chosen. Generate at a modern size:

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/sonyliv_deploy
ssh-copy-id -i ~/.ssh/sonyliv_deploy.pub ec2-user@HOST
chmod 600 ~/.ssh/sonyliv_deploy
DEPLOY_KEY=~/.ssh/sonyliv_deploy ./deploy/deploy.sh
```

Two things that produce a misleading `Permission denied (publickey)`:

- **Key permissions.** ssh refuses a group- or world-readable private key.
  `deploy.sh` checks this in preflight and tells you to `chmod 600`.
- **A genuinely old RSA key.** OpenSSH ≥ 8.8 disables the legacy `ssh-rsa`
  *signature algorithm* by default. Keys generated in the last few years work
  fine over `rsa-sha2-256/512`; only an ancient key fails, and it fails looking
  exactly like a wrong key. Diagnose with `ssh -v`.

Password authentication is not supported here, and would not work on a stock EC2
AMI anyway — the standard AMIs ship `PasswordAuthentication no`.

---

## What a deploy does

1. **Preflight** — `go` present, key readable and `0600`, host reachable. Fails
   before spending time on a build.
2. **`make check`** — tests, `go vet`, `gofmt`. `--skip-checks` to bypass.
3. **Cross-compile** `linux/amd64`, `CGO_ENABLED=0`, `-trimpath`. Every directory
   under `ingest/cmd/` is built, discovered rather than hardcoded, so a new binary
   ships with no change to the script.
4. **Ship and verify** — `scp` to `/tmp/sonyliv-deploy-<version>.<pid>/`, then
   compare `sha256sum` both sides. A truncated transfer is caught before it
   becomes a broken binary.
5. **Install atomically** — a running binary cannot be overwritten in place
   (`ETXTBSY`), so the new one is written alongside and `mv`'d over. `mv` within
   one filesystem is atomic, so the path is never missing or half-written. The
   previous binary is kept as `<name>.prev`.
6. **Restart** — only if the unit is installed. `daemon-reload`, `restart`, then
   require `is-active` to hold.
7. **Health check, then roll back on failure** — polls `DEPLOY_HEALTH_URL` from on
   the box for 30s. If the service will not come up, `.prev` binaries are restored
   and the unit restarted, and the script exits `4`. A deploy that leaves the
   service down is worse than one that refuses.

Exit codes: `0` ok, `1` usage/preflight, `2` build failed, `3` transfer or verify
failed, `4` service did not come up (rolled back).

What is running:

```bash
ssh ec2-user@HOST cat /usr/local/bin/.sonyliv-deployed-version
```

---

## Notes

**`sonyliv-ingest` is a CLI, not a service.** It gets installed and never
restarted. `schema`, `content`, `events` and `verify` stay manual, because
applying DDL or loading a day is a decision, not a deploy step.

**`sonyliv-gen` is also installed** and can be run by hand for the live-replay
demo, or wrapped in its own unit later. With `--duration 0 --max-events 0` it runs
indefinitely.

**Rolling back by hand:**

```bash
ssh ec2-user@HOST 'sudo mv /usr/local/bin/sonyliv-api.prev /usr/local/bin/sonyliv-api \
                   && sudo systemctl restart sonyliv-api'
```

Only one generation of `.prev` is kept. Two bad deploys in a row leave you
rebuilding from a known-good commit rather than rolling back twice.
