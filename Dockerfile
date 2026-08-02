# One image, all five binaries.
#
# sonyliv-api, sonyliv-mock, sonyliv-ingest, sonyliv-gen and sonyliv-mcp share a
# module, a config loader and an embedded dashboard, and compose runs several of
# them at once. Five images would be five copies of the same 20 MB of Go with
# five build caches to invalidate; one image with five entrypoints is smaller,
# builds once, and makes "the API and the rollup are the same code" true by
# construction rather than by discipline.
#
#   docker compose up            builds this and runs the whole stack
#   docker build -t sonyliv .    just the image

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
FROM golang:1.25-alpine AS build

# git is not needed for the build itself, but a `go build` of a module with any
# VCS stamping enabled will look for it and fail confusingly if it is absent.
RUN apk add --no-cache git

WORKDIR /src

# go.mod and go.sum first, alone. This layer is cached across every source edit,
# so a one-line change to a handler does not re-download the module graph.
COPY ingest/go.mod ingest/go.sum ./
RUN go mod download

COPY ingest/ ./

# NOTE ON THE DASHBOARD. There is deliberately no Node stage here.
#
# The Next.js static export is committed at internal/mock/web (staged by
# `make -C ingest web`), so the Go build embeds it with no JavaScript toolchain
# involved. That is a decision the repo already made and this file inherits:
# adding a Node stage would put an `npm ci` — a network fetch of a few hundred
# packages — on the critical path of every `docker compose up`, to reproduce a
# directory that is already in the tree and already correct.
#
# The consequence, stated so it cannot surprise anyone: editing dashboard/ does
# NOT change this image until you re-run `make -C ingest web` and commit the
# export. That is the same rule as a native build.

# CGO off so the binaries are static and the runtime stage can be minimal.
# -trimpath keeps build paths out of the binary, matching deploy/deploy.sh.
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags='-s -w' -o /out/ ./cmd/...

# ---------------------------------------------------------------------------
# Runtime
# ---------------------------------------------------------------------------
FROM alpine:3.21

# ca-certificates: the same image can point at ClickHouse Cloud over TLS instead
# of the local container, and without these that fails as a certificate error.
# bash and curl are for docker/init.sh and the healthchecks.
RUN apk add --no-cache ca-certificates bash curl tzdata

# Unprivileged, matching the systemd units. Nothing here needs to write to disk.
RUN addgroup -S sonyliv && adduser -S -G sonyliv -H -s /sbin/nologin sonyliv

COPY --from=build /out/ /usr/local/bin/
COPY deploy/docker/init.sh /usr/local/bin/sonyliv-init

RUN chmod +x /usr/local/bin/sonyliv-init

USER sonyliv

# No default CMD on purpose. Every service in docker-compose.yml names the
# binary it runs, so an image started with no command should stop rather than
# silently become whichever one happened to be listed first here.
ENTRYPOINT []
CMD ["sh", "-c", "echo 'specify a command: sonyliv-api | sonyliv-mock | sonyliv-ingest | sonyliv-gen | sonyliv-mcp'; exit 64"]
