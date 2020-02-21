# healthz-proxy

`healthz-proxy` is a small Go program that will proxy `/healthz` requests to a configured upstream, and is intended to
be used as a sidecar to a pod.

When it receives SIGINT or SIGTERM it will stop proxying requests and respond with 503 for a configurable time period.
This can be useful if one is running for example [nginx-ingress](https://github.com/kubernetes/ingress-nginx/) controller
as a DaemonSet with a load balancer provisioned via other means (e.g. Terraform) than through Kubernetes, and want to
achieve zero downtime rollouts.

## Usage

```shell
$ healthz-proxy -help
Usage of healthz-proxy:
  -fail-period duration
        time to fail health checks for before stopping server (default 30s)
  -listen-addr string
        server listen address (default ":8080")
  -proxy-url string
        URL to proxy to (default "http://:8081/healthz")
  -shutdown-timeout duration
        time to wait for server to stop gracefully (default 5s)
```

## License

[MIT](./LICENSE.md)
