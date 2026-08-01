SHELL := /bin/bash
BIN   := bin
DATA  ?= ../data

# Paths to the supplied extracts. Override on the command line:
#   make load DATA=/path/to/SonyLiv/data
RAW_CSV     ?= $(DATA)/ch-hackathon-raw-data.csv
CONTENT_CSV ?= $(DATA)/ch-hackathon-content-data.csv

.DEFAULT_GOAL := help

## help: list targets
help:
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/^## /  /' | column -t -s ':'

## web: rebuild the Next.js dashboard and stage its static export for embedding
##      Requires Node >= 20.9 (Next 16). The export is committed, so `make build`
##      works with no Node toolchain — run this only after changing dashboard/.
web:
	cd ../dashboard && npm ci --silent && npm run build
	rm -rf internal/mock/web && mkdir -p internal/mock/web
	cp -R ../dashboard/out/. internal/mock/web/
	@echo "staged $$(du -sh internal/mock/web | cut -f1) into internal/mock/web"

## build: compile all binaries into ./bin
build:
	@mkdir -p $(BIN)
	go build -o $(BIN)/sonyliv-ingest ./cmd/sonyliv-ingest
	go build -o $(BIN)/sonyliv-gen    ./cmd/sonyliv-gen
	go build -o $(BIN)/sonyliv-mock   ./cmd/sonyliv-mock
	@echo "built $(BIN)/sonyliv-ingest, $(BIN)/sonyliv-gen and $(BIN)/sonyliv-mock"

## mock: serve the load simulator and the event stepper on localhost:8088
mock: build
	$(BIN)/sonyliv-mock

## test: run unit tests
test:
	go test ./...

## check: vet, format check, and tests
check: test
	go vet ./...
	@out=$$(gofmt -l .); if [ -n "$$out" ]; then echo "gofmt needed:"; echo "$$out"; exit 1; fi
	@echo "check ok"

## doctor: preflight the configured service before loading into it
doctor: build
	$(BIN)/sonyliv-ingest doctor

## schema: apply the DDL (idempotent)
schema: build
	$(BIN)/sonyliv-ingest schema

## schema-print: print the DDL without connecting (password redacted)
schema-print: build
	$(BIN)/sonyliv-ingest schema --dry-run

## load: apply schema, then load the content catalogue and the event CSV
load: schema
	$(BIN)/sonyliv-ingest content --file $(CONTENT_CSV)
	$(BIN)/sonyliv-ingest events  --file $(RAW_CSV)

## verify: post-load integrity and storage report
verify: build
	$(BIN)/sonyliv-ingest verify

## demo: live replay — 2,000 concurrent sessions, 10 event-minutes at 30x
demo: build
	$(BIN)/sonyliv-gen --concurrency 2000 --duration 10m --speed 30 --ramp-up 1m

## loadtest: 5M generated events as fast as the service accepts them
loadtest: build
	$(BIN)/sonyliv-gen --concurrency 20000 --max-events 5000000 --ramp-up 2m

## ch-up: start a local ClickHouse in Docker for development
ch-up:
	docker run -d --rm --name sonyliv-ch \
		-p 9000:9000 -p 8123:8123 \
		-e CLICKHOUSE_PASSWORD=hackathon \
		--ulimit nofile=262144:262144 \
		clickhouse/clickhouse-server:latest
	@echo "waiting for ClickHouse..."
	@for i in $$(seq 1 60); do \
		curl -sf http://localhost:8123/ping >/dev/null 2>&1 && { echo "ready"; exit 0; }; \
		sleep 1; \
	done; echo "timed out" && exit 1

## ch-down: stop the local ClickHouse container
ch-down:
	-docker stop sonyliv-ch

## clean: remove build output
clean:
	rm -rf $(BIN)

.PHONY: help build test check doctor schema schema-print load verify demo loadtest ch-up ch-down clean
