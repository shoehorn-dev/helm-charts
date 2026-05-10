# Shoehorn Helm Charts

[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/shoehorn)](https://artifacthub.io/packages/search?repo=shoehorn)
[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/shoehorn-k8s-agent)](https://artifacthub.io/packages/search?repo=shoehorn-k8s-agent)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

Helm charts for [Shoehorn](https://shoehorn.dev), the Intelligent Developer Platform.

## Charts

| Chart | Description |
|-------|-------------|
| [shoehorn](./shoehorn) | Full platform deployment (api, web, eventbus, worker, crawler, forge + datastores) |
| [shoehorn-k8s-agent](./shoehorn-k8s-agent) | Kubernetes agent for workload discovery, GitOps, and eBPF network flows |

## Repository

OCI registry: `oci://ghcr.io/shoehorn-dev/helm-charts`

## Requirements

- Kubernetes 1.24+
- Helm 4.0+

## Quick Start

### Shoehorn Platform

Create a Kubernetes Secret with your credentials (kubectl, External Secrets Operator, Vault, etc.), then:

```bash
helm install shoehorn oci://ghcr.io/shoehorn-dev/helm-charts/shoehorn \
  --namespace shoehorn --create-namespace \
  --values custom-values.yaml \
  --wait
```

See [shoehorn/README.md](./shoehorn/README.md) for the Secret keys and configuration.

### Kubernetes Agent

```bash
helm install shoehorn-k8s-agent oci://ghcr.io/shoehorn-dev/helm-charts/shoehorn-k8s-agent \
  --namespace shoehorn --create-namespace \
  --set shoehorn.apiURL=https://shoehorn.example.com \
  --set shoehorn.apiToken=sha_your_token_here \
  --set shoehorn.cluster.id=my-cluster \
  --wait
```

To pass the token via an existing Secret instead, see [shoehorn-k8s-agent/README.md](./shoehorn-k8s-agent/README.md).

## Documentation

Full product docs: <https://docs.shoehorn.dev>

## License

Apache 2.0. See [LICENSE](LICENSE).
