# Build the healthz-proxy binary
FROM golang:1.13 as builder

# Copy in the go src
WORKDIR /go/src/github.com/pusher/healthz-proxy

COPY go.mod go.mod
COPY go.sum go.sum

RUN go mod download

COPY cmd/ cmd/

# Build
RUN GOPRIVATE=github.com/pusher/healthz-proxy CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o healthz-proxy github.com/pusher/healthz-proxy/cmd/healthz-proxy

FROM alpine:3.11
RUN apk --no-cache add ca-certificates
WORKDIR /bin
COPY --from=builder /go/src/github.com/pusher/healthz-proxy/healthz-proxy .
EXPOSE 8080
ENTRYPOINT ["/bin/healthz-proxy"]
