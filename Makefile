include .env

SHELL := /usr/bin/env bash
BINARY := healthz-proxy
VERSION := v$(shell date +%Y%m%d)-$(shell git describe --always --dirty --tags 2> /dev/null || "undefined")
ECHO = echo -e

# Image URL to use all building/pushing image targets
REPO ?= github.com/pusher/healthz-proxy
IMG ?= quay.io/pusher/healthz-proxy

DEFAULT_GOAL:=help

## Print this help
#  eg: 'make' or 'make help'
help:
	@awk -v skip=1 \
		'/^##/ { sub(/^[#[:blank:]]*/, "", $$0); doc_h=$$0; doc=""; skip=0; next } \
		 skip  { next } \
		 /^#/  { doc=doc "\n" substr($$0, 2); next } \
		 /:/   { sub(/:.*/, "", $$0); printf "\033[1m%-30s\033[0m\033[1m%s\033[0m %s\n\n", $$0, doc_h, doc; skip=1 }' \
		$(MAKEFILE_LIST)

## Build the binary
#  (placed in the root of repository)
build: clean $(BINARY)

## Remove built binary (if it exists)
clean:
	rm -f $(BINARY)

## Run go fmt against code
fmt:
	@ $(ECHO) "\033[36mFormatting code\033[0m"
	$(GO) fmt ./cmd/...

## Run go vet against code
vet:
	@ $(ECHO) "\033[36mVetting code\033[0m"
	$(GO) vet ./cmd/...

## Lint using golangci-lint
lint:
	@ $(ECHO) "\033[36mLinting code\033[0m"
	$(LINTER) run --disable-all \
                --exclude-use-default=false \
                --enable=govet \
                --enable=ineffassign \
                --enable=deadcode \
                --enable=golint \
                --enable=goconst \
                --enable=gofmt \
                --enable=goimports \
                --skip-dirs=pkg/client/ \
                --deadline=120s \
                --tests ./...
	@ $(ECHO)

## Run "tests"
test: fmt lint vet

## Build the binary
#  (placed in root of repository)
$(BINARY): test
	env GOPRIVATE=$(REPO) CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o $(BINARY) $(REPO)/cmd/$(BINARY)

## Build and tag the Docker image
docker-build:
	$(DOCKER) build -t ${IMG}:${VERSION} .
	@ $(ECHO) "\033[36mBuilt $(IMG):$(VERSION)\033[0m"

## Build and tag the Docker image
#  add extra tags with the $TAGS (comma seperated) variable
TAGS ?= latest
docker-tag: docker-build
	@IFS="," ; set -e ; tags=${TAGS}; for tag in $${tags}; do \
		$(DOCKER) tag ${IMG}:${VERSION} ${IMG}:$${tag} ; \
		$(ECHO) "\033[36mTagged $(IMG):$(VERSION) as $${tag}\033[0m" ; \
	done

## Build, tag and push the Docker image
#  add extra tags with the $PUSH_TAGS (comma seperated) variable
PUSH_TAGS ?= ${VERSION},latest
docker-push: docker-tag
	@IFS="," ; set -e ; tags=${PUSH_TAGS}; for tag in $${tags}; do \
		$(DOCKER) push ${IMG}:$${tag} ; \
		$(ECHO) "\033[36mPushed $(IMG):$${tag}\033[0m" ; \
	done
