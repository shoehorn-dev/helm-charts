# Shoehorn Helm Charts

[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/shoehorn)](https://artifacthub.io/packages/search?repo=shoehorn)
[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/shoehorn-k8s-agent)](https://artifacthub.io/packages/search?repo=shoehorn-k8s-agent)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

Official Helm charts for [Shoehorn](https://shoehorn.dev), the Intelligent Platform for Engineering.

## Repositories

- OCI registry: `oci://ghcr.io/shoehorn-dev/helm-charts`
- GitHub Pages Helm repository: `https://charts.shoehorn.dev`

## Requirements

- Kubernetes 1.24+
- Helm 4.0+

## Charts

| Chart | Description |
|-------|-------------|
| [shoehorn](./shoehorn) | Internal Developer Portal — full platform deployment |
| [shoehorn-k8s-agent](./shoehorn-k8s-agent) | Kubernetes agent — workload discovery, GitOps, and eBPF network observability |

## Quick Start

### Shoehorn Platform

1. Create a Kubernetes Secret with your credentials (using kubectl, External Secrets Operator, Vault, etc.)
2. Install the chart:

```bash
helm repo add shoehorn https://charts.shoehorn.dev
helm repo update

helm install shoehorn shoehorn/shoehorn \
  --namespace shoehorn --create-namespace \
  --values custom-values.yaml \
  --wait
```

Or install directly from OCI:

```bash
helm install shoehorn oci://ghcr.io/shoehorn-dev/helm-charts/shoehorn \
  --namespace shoehorn --create-namespace \
  --values custom-values.yaml \
  --wait
```

See [shoehorn/README.md](./shoehorn/README.md) for secret setup and configuration.

### Kubernetes Agent

```bash
helm install shoehorn-k8s-agent shoehorn/shoehorn-k8s-agent \
  --set shoehorn.apiURL=https://shoehorn.example.com \
  --set shoehorn.apiToken=sha_your_token_here \
  --set shoehorn.cluster.id=my-cluster \
  --wait
```

Or install directly from OCI:

```bash
helm install shoehorn-k8s-agent oci://ghcr.io/shoehorn-dev/helm-charts/shoehorn-k8s-agent \
  --set shoehorn.apiURL=https://shoehorn.example.com \
  --set shoehorn.apiToken=sha_your_token_here \
  --set shoehorn.cluster.id=my-cluster \
  --wait
```

Or use an existing secret instead of passing the token directly — see [shoehorn-k8s-agent/README.md](./shoehorn-k8s-agent/README.md).

## Documentation

- [Shoehorn chart README](./shoehorn/README.md)
- [K8s Agent chart README](./shoehorn-k8s-agent/README.md)
- [Shoehorn Docs](https://docs.shoehorn.dev)

## GitHub Pages Setup

After this workflow is merged, enable GitHub Pages for the repository with:

1. `Settings -> Pages -> Build and deployment`
2. `Source: GitHub Actions`
3. `Custom domain: charts.shoehorn.dev`

Then add the DNS `CNAME` record for `charts.shoehorn.dev` pointing to `shoehorn-dev.github.io`.

## License

Apache 2.0 — see [LICENSE](LICENSE) for details.
