# Shoehorn Kubernetes Agent

Discovers Kubernetes workloads, GitOps applications, and pod-to-pod network flows, then syncs them to Shoehorn for the service catalog and dependency map.

## TL;DR

Get an API token from your Shoehorn portal at `/admin/integrations/clusters`, then:

```bash
helm install shoehorn-k8s-agent oci://ghcr.io/shoehorn-dev/helm-charts/shoehorn-k8s-agent \
  --namespace shoehorn --create-namespace \
  --set shoehorn.apiURL=https://shoehorn.example.com \
  --set shoehorn.apiToken=sha_your_token_here \
  --set shoehorn.cluster.id=prod-us-east-1
```

## Introduction

This chart deploys the Shoehorn Kubernetes agent on a Kubernetes cluster using [Helm](https://helm.sh). The agent runs as a Deployment with leader election for HA. An optional eBPF DaemonSet (`netobserver`) captures pod-to-pod TCP flows for service dependency mapping.

The agent image is published to [`docker.io/shoehorned/shoehorn-k8s-agent`](https://hub.docker.com/r/shoehorned/shoehorn-k8s-agent). The chart is published to `oci://ghcr.io/shoehorn-dev/helm-charts/shoehorn-k8s-agent`.

## Prerequisites

- Kubernetes 1.24+
- Helm 4.0+
- A Shoehorn API token (generated in the portal)
- metrics-server (optional, for `full` monitoring level)
- ArgoCD or FluxCD installed (optional, for GitOps integration)
- Cilium CNI (optional, for `CiliumNetworkPolicy` visibility)
- Linux kernel 5.2+ with BTF (`CONFIG_DEBUG_INFO_BTF=y`) on nodes if `netobserver.enabled=true`

## Installing the Chart

The chart needs three things: a Shoehorn API URL, an API token, and a cluster ID.

**Inline token (chart creates the Secret):**

```bash
helm install shoehorn-k8s-agent oci://ghcr.io/shoehorn-dev/helm-charts/shoehorn-k8s-agent \
  --namespace shoehorn --create-namespace \
  --set shoehorn.apiURL=https://shoehorn.example.com \
  --set shoehorn.apiToken=sha_your_token_here \
  --set shoehorn.cluster.id=prod-us-east-1
```

**Existing Secret (kubectl, ESO, Vault, etc.):**

```bash
kubectl create secret generic shoehorn-agent-credentials -n shoehorn \
  --from-literal=api-token=sha_your_token_here

helm install shoehorn-k8s-agent oci://ghcr.io/shoehorn-dev/helm-charts/shoehorn-k8s-agent \
  --namespace shoehorn --create-namespace \
  --set shoehorn.apiURL=https://shoehorn.example.com \
  --set shoehorn.existingSecret=shoehorn-agent-credentials \
  --set shoehorn.cluster.id=prod-us-east-1
```

When `existingSecret` is set, the chart references your Secret instead of creating one. Use `secretMappings` to override the key names if yours differ from the chart defaults.

Example values files ship with the chart:

| File | Use |
|---|---|
| [`examples/values-minimal.yaml`](examples/values-minimal.yaml) | Quick start with required values only |
| [`examples/values-production.yaml`](examples/values-production.yaml) | 3 replicas, anti-affinity, security hardening |
| [`examples/values-filtered.yaml`](examples/values-filtered.yaml) | Namespace and resource filtering |
| [`examples/values-annotations.yaml`](examples/values-annotations.yaml) | Annotation-based monitoring + Pod watching |
| [`examples/values-large-cluster.yaml`](examples/values-large-cluster.yaml) | Tuned channel and rate limits for 200+ node clusters |
| [`examples/values-scoped.yaml`](examples/values-scoped.yaml) | Namespace-scoped watching with per-namespace RBAC (one install per tenant) |

## Uninstalling the Chart

```bash
helm uninstall shoehorn-k8s-agent -n shoehorn
```

## Configuration

The full parameter list lives in [`values.yaml`](values.yaml), with [`values.schema.json`](values.schema.json) for IDE autocompletion and template-time validation. Key parameters:

### Required

| Parameter | Description |
|---|---|
| `shoehorn.apiURL` | Shoehorn API endpoint |
| `shoehorn.apiToken` | API token (or use `shoehorn.existingSecret`) |
| `shoehorn.cluster.id` | Unique cluster identifier |

The chart fails template rendering if any of these are missing, with a clear error in `helm install` output.

### Cluster identity

| Parameter | Description | Default |
|---|---|---|
| `shoehorn.cluster.name` | Display name | falls back to `cluster.id` |
| `shoehorn.cluster.dashboardURL` | Link to K8s dashboard, ArgoCD UI, etc. | `""` |
| `shoehorn.cluster.provider` | Cloud provider (auto-detected if empty) | `""` |
| `shoehorn.cluster.region` | Cloud region (auto-detected if empty) | `""` |
| `shoehorn.cluster.environment` | Deployment environment, e.g. production, staging | `""` |
| `annotations.shoehorn.team` | Team owner annotation (`shoehorn.dev/team`) | `""` |

### Watching

| Parameter | Description | Default |
|---|---|---|
| `agent.kubernetes.namespaces` | Namespaces to watch (empty = all) | `[]` |
| `agent.kubernetes.excludeNamespaces` | Namespaces to skip | `[]` |
| `agent.kubernetes.labelSelector` | Label selector filter | `""` |
| `agent.kubernetes.watchedKinds` | Resource kinds to watch (empty = defaults, includes Pod) | `[]` |
| `agent.kubernetes.scopeMode` | `cluster` (cluster-wide watch) or `namespaces` (one watch per namespace, per-namespace RBAC) | `cluster` |

`namespaces` and `excludeNamespaces` are mutually exclusive: when `namespaces` is set, `excludeNamespaces` is ignored. NetworkPolicy and CiliumNetworkPolicy informers are always on and unaffected by `watchedKinds`.

With `scopeMode: cluster` (the default), the agent watches the whole cluster and filters to `namespaces` in-process. With `scopeMode: namespaces` it runs one watch per entry in `namespaces` (which must be non-empty) and the chart swaps the cluster-wide ClusterRole for a Role in each watched namespace plus a minimal ClusterRole. Use it to run one install per tenant on a shared cluster. See [`examples/values-scoped.yaml`](examples/values-scoped.yaml).

### Monitoring levels

Set the cluster-wide default with `agent.annotations.defaultLevel`, override per resource with the `shoehorn.dev/monitoring-level` annotation.

| Level | What it collects | Overhead |
|---|---|---|
| `basic` (default) | Workload status, replica counts, image info | Low |
| `detailed` | + restart counts, container states, pod conditions | Medium |
| `full` | + CPU/memory metrics and recommendations (needs metrics-server) | High |

Set `agent.annotations.defaultBehavior` to `require-annotation` for opt-in monitoring, or `monitor-none` to disable cluster-wide.

Per-resource annotations:

| Annotation | Values |
|---|---|
| `shoehorn.dev/monitor` | `"true"` / `"false"` |
| `shoehorn.dev/monitoring-level` | `"basic"` / `"detailed"` / `"full"` |
| `shoehorn.dev/scrape-interval` | duration (e.g. `"30s"`) |
| `shoehorn.dev/collect-pod-metrics` | `"true"` / `"false"` |
| `shoehorn.dev/collect-events` | `"true"` / `"false"` |

### High availability

| Parameter | Description | Default |
|---|---|---|
| `replicaCount` | Replicas (use 3 for HA) | `1` |
| `leaderElection.enabled` | Leader election (required when `replicaCount > 1`) | `true` |
| `podDisruptionBudget.enabled` | PDB | `true` |
| `podDisruptionBudget.maxUnavailable` | | `0` |

Without leader election, multiple replicas would emit duplicate events.

### GitOps

| Parameter | Description | Default |
|---|---|---|
| `agent.gitops.tool` | `argocd`, `fluxcd`, or `""` (off) | `""` |
| `agent.gitops.watchAllNamespaces` | `false` = scoped Role on the tool's namespace; `true` = ClusterRole | `false` |
| `agent.gitops.argocd.namespace` | | `argocd` |
| `agent.gitops.argocd.serverURL` | For sync/refresh commands | `""` |
| `agent.gitops.argocd.token` | ArgoCD API token (pass via `--set`, never check in) | `""` |
| `agent.gitops.fluxcd.namespace` | | `flux-system` |
| `agent.gitops.commandPollInterval` | How often to poll Shoehorn for pending commands | `10s` |

GitOps watching is independent of workload watching. Enable one without changing the other. FluxCD doesn't need a token (the agent watches `Kustomization` and `HelmRelease` CRDs directly).

### Network Observer (eBPF)

Optional DaemonSet that captures pod-to-pod TCP connections.

| Parameter | Description | Default |
|---|---|---|
| `netobserver.enabled` | Deploy the DaemonSet | `false` |
| `netobserver.flushInterval` | Aggregation flush | `60s` |
| `netobserver.intraClusterOnly` | Only intra-cluster flows | `true` |
| `netobserver.excludePorts` | Ports to skip | `443,5432,6379,3306,27017` |
| `netobserver.namespaces` / `excludeNamespaces` | Namespace filter | `[]` |

Gracefully no-ops if eBPF loading fails.

### Resources and image

| Parameter | Default |
|---|---|
| `image.registry` | `docker.io` |
| `image.repository` | `shoehorned/shoehorn-k8s-agent` |
| `image.tag` | `.Chart.AppVersion` |
| `resources.limits` | `100m` CPU / `150Mi` memory |
| `resources.requests` | `30m` CPU / `80Mi` memory |

### Agent runtime

| Parameter | Default |
|---|---|
| `agent.logLevel` / `logFormat` | `info` / `json` |
| `agent.batchInterval` / `batchSize` | `30s` / `100` |
| `agent.heartbeatInterval` | `5m` |
| `agent.metrics.sampleInterval` | `5m` |
| `agent.metrics.windowHours` | `168` (7 days) |

## Common scenarios

### Only watch production

```bash
--set agent.kubernetes.namespaces={prod,prod-east,prod-west}
```

### Skip system namespaces

```bash
--set agent.kubernetes.excludeNamespaces={kube-system,kube-public,kube-node-lease}
```

### Opt-in monitoring (annotation required)

```bash
--set agent.annotations.defaultBehavior=require-annotation
```

Then on each workload:

```yaml
metadata:
  annotations:
    shoehorn.dev/monitor: "true"
    shoehorn.dev/monitoring-level: "detailed"
```

### ArgoCD with cluster-wide watch

Generate a token first:

```bash
argocd login <argocd-server>
argocd account generate-token --account <account>
```

Then install:

```bash
helm install shoehorn-k8s-agent oci://ghcr.io/shoehorn-dev/helm-charts/shoehorn-k8s-agent \
  -f examples/values-production.yaml \
  --set shoehorn.apiToken=sha_... \
  --set agent.gitops.tool=argocd \
  --set agent.gitops.argocd.serverURL=https://argocd.example.com \
  --set agent.gitops.argocd.token=<argocd-token> \
  --set agent.gitops.watchAllNamespaces=true
```

### FluxCD

```bash
--set agent.gitops.tool=fluxcd
```

No token needed. Add `--set agent.gitops.watchAllNamespaces=true` if Flux resources are spread across tenant namespaces.

### Enable network flow capture

```bash
--set netobserver.enabled=true
```

## RBAC

The chart creates a ClusterRole with read-only access:

| API Group | Resources | Purpose |
|---|---|---|
| `apps` | deployments, statefulsets, daemonsets | Workload discovery |
| `batch` | cronjobs, jobs | Batch workloads |
| `""` (core) | namespaces, pods, services, events | Core resources |
| `networking.k8s.io` | ingresses, networkpolicies | Ingress and NetworkPolicy visibility |
| `cilium.io` | ciliumnetworkpolicies, ciliumclusterwidenetworkpolicies | Cilium visibility (skipped if CRDs missing) |
| `metrics.k8s.io` | pods | Resource usage (needs metrics-server) |
| `coordination.k8s.io` | leases | Leader election |

When `agent.gitops.watchAllNamespaces=true`, additional CRD access is added for ArgoCD (`argoproj.io`) or FluxCD (`kustomize.toolkit.fluxcd.io`, `helm.toolkit.fluxcd.io`, `source.toolkit.fluxcd.io`). When `watchAllNamespaces=false`, the chart creates a namespaced `Role` instead, scoped to the tool's namespace.

### Namespace-scoped RBAC

With `agent.kubernetes.scopeMode: namespaces`, the cluster-wide ClusterRole is replaced by:

- A `Role` plus `RoleBinding` in each watched namespace, carrying the workload, networking, Cilium, metrics, and (if `agent.helm.enabled`) Secret-list rules.
- A `Role` plus `RoleBinding` for leader-election leases in the release namespace.
- A minimal ClusterRole (`<release>-scoped`) granting `get` on the listed namespaces by name, read-only `nodes` (node count and provider detection), and read access to cluster-scoped Cilium policies. The node and Cilium rules are read-only and not tenant-sensitive; drop them from your copy if policy forbids cluster-scoped reads, and the agent degrades gracefully.

## Upgrading

```bash
helm upgrade shoehorn-k8s-agent oci://ghcr.io/shoehorn-dev/helm-charts/shoehorn-k8s-agent \
  -n shoehorn -f custom-values.yaml --wait

helm history shoehorn-k8s-agent -n shoehorn
helm rollback shoehorn-k8s-agent 1 -n shoehorn
```

## Troubleshooting

```bash
kubectl get pods -n shoehorn
kubectl logs -n shoehorn -l app.kubernetes.io/name=shoehorn-k8s-agent
kubectl describe pod -n shoehorn <pod-name>

# Verify the credentials Secret
kubectl get secret -n shoehorn -o name | grep shoehorn-agent
```

## Support

- Documentation: <https://docs.shoehorn.dev>
- Source: <https://github.com/shoehorn-dev/helm-charts>
- Issues: <https://github.com/shoehorn-dev/helm-charts/issues>

## License

Apache-2.0
