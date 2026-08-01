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

## build: compile both binaries into ./bin
build:
	@mkdir -p $(BIN)
	go build -o $(BIN)/sonyliv-ingest ./cmd/sonyliv-ingest
	go build -o $(BIN)/sonyliv-gen    ./cmd/sonyliv-gen
	@echo "built $(BIN)/sonyliv-ingest and $(BIN)/sonyliv-gen"

## test: run unit tests
test:
	go test ./...

## check: vet, format check, and tests
check: test
	go vet ./...
	@out=$$(gofmt -l .); if [ -n "$$out" ]; then echo "gofmt needed:"; echo "$$out"; exit 1; fi
	@echo "check ok"

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

.PHONY: help build test check schema schema-print load verify demo loadtest ch-up ch-down clean
