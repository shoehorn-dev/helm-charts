# Shoehorn Kubernetes Agent Helm Chart

This Helm chart deploys the Shoehorn K8s Agent to your Kubernetes cluster.

## Prerequisites

- Kubernetes 1.24+
- Helm 3.8+
- A Shoehorn API token (generated in your Shoehorn Portal)
- (Optional) ArgoCD or FluxCD installed in the cluster for GitOps integration
- (Optional) metrics-server deployed for resource usage insights
- (Optional) Cilium CNI for CiliumNetworkPolicy visibility

## Installation

1. Register your cluster in your Shoehorn Portal (/admin/integrations/clusters) to get an API token.

2. Install the chart (add `--wait` to block until pods are ready):

**Option A: Set token directly** (chart creates the secret)

```bash
helm install shoehorn-k8s-agent oci://ghcr.io/shoehorn-dev/helm-charts/shoehorn-k8s-agent \
  --set shoehorn.apiURL=https://shoehorn.example.com \
  --set shoehorn.apiToken=sha_your_token_here \
  --set shoehorn.cluster.id=prod-us-east-1
```

**Option B: Use an existing secret** (created by kubectl, ESO, Vault, etc.)

```bash
# Create the secret yourself
kubectl create secret generic shoehorn-agent-credentials -n shoehorn \
  --from-literal=api-token=sha_your_token_here

# Install with existingSecret
helm install shoehorn-k8s-agent oci://ghcr.io/shoehorn-dev/helm-charts/shoehorn-k8s-agent \
  --set shoehorn.apiURL=https://shoehorn.example.com \
  --set shoehorn.existingSecret=shoehorn-agent-credentials \
  --set shoehorn.cluster.id=prod-us-east-1
```

When `existingSecret` is set, the chart does not create a secret — it references yours. Override `secretMappings` if your secret uses different key names.

## Configuration

### Required Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `shoehorn.apiURL` | Shoehorn API endpoint (REQUIRED) | `""` |
| `shoehorn.apiToken` | API token — set directly OR use `existingSecret` | `""` |
| `shoehorn.existingSecret` | Name of existing K8s secret (alternative to `apiToken`) | `""` |
| `shoehorn.cluster.id` | Unique cluster identifier (REQUIRED) | `""` |

### Cluster Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `shoehorn.cluster.name` | Human-readable cluster name | Defaults to `cluster.id` |
| `shoehorn.cluster.dashboardURL` | Dashboard URL (K8s Dashboard, ArgoCD, etc.) | `""` |

### Agent Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `agent.logLevel` | Log level (debug, info, warn, error) | `info` |
| `agent.logFormat` | Log format (json, console) | `json` |
| `agent.batchInterval` | Batch flush interval | `30s` |
| `agent.batchSize` | Max batch size | `100` |
| `agent.pushRetries` | Number of push retries | `3` |
| `agent.pushTimeout` | Push timeout | `30s` |
| `agent.heartbeatInterval` | Heartbeat interval | `5m` |
| `agent.healthPort` | Health server port | `8080` |
| `agent.livenessProbe` | Liveness probe configuration | See `values.yaml` |
| `agent.readinessProbe` | Readiness probe configuration | See `values.yaml` |

### Ownership Annotations

| Parameter | Description | Default |
|-----------|-------------|---------|
| `annotations.shoehorn.team` | Team owner for the agent resources (`shoehorn.dev/team`) | `""` |

### Kubernetes Filtering

| Parameter | Description | Default |
|-----------|-------------|---------|
| `agent.kubernetes.namespaces` | Namespaces to watch (empty = all) | `[]` |
| `agent.kubernetes.excludeNamespaces` | Namespaces to exclude | `[]` |
| `agent.kubernetes.labelSelector` | Label selector filter | `""` |
| `agent.kubernetes.watchedKinds` | Resource kinds to watch (empty = all defaults, includes Pod) | `[]` |

> **Note**: NetworkPolicy (Kubernetes) and CiliumNetworkPolicy/CiliumClusterwideNetworkPolicy informers are always-on and not affected by `watchedKinds`. The agent automatically discovers network policies for the Network Policy Visibility feature.

> **Note**: Do not set both `namespaces` and `excludeNamespaces`. When `namespaces` (include list) is set, `excludeNamespaces` is ignored because only the explicitly listed namespaces are watched.

### Resource Usage Metrics

The agent samples metrics-server to provide resource optimization insights (over-provisioned / under-provisioned alerts). Gracefully degrades if metrics-server is not deployed.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `agent.metrics.sampleInterval` | How often to sample metrics-server | `5m` |
| `agent.metrics.windowHours` | Rolling window size in hours (168 = 7 days) | `168` |

### Annotation-Based Monitoring

Fine-grained control over which resources are monitored and at what detail level using `shoehorn.dev/*` annotations:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `agent.annotations.defaultBehavior` | Default behavior: `monitor-all`, `require-annotation`, or `monitor-none` | `monitor-all` |
| `agent.annotations.defaultLevel` | Default monitoring level: `basic`, `detailed`, or `full` | `basic` |

#### Monitoring Levels

| Level | Description | Overhead | Use Case |
|-------|-------------|----------|----------|
| **basic** | Workload status, replica counts, image info | Low | Production monitoring |
| **detailed** | Basic + restart counts, container states, pod events | Medium | Troubleshooting unhealthy workloads |
| **full** | Detailed + CPU/memory metrics, resource recommendations | High | Performance optimization, capacity planning |

#### Resource Annotations

Add these annotations to individual Kubernetes resources (Deployments, Pods, etc.):

| Annotation | Values | Description |
|------------|--------|-------------|
| `shoehorn.dev/monitor` | `"true"` or `"false"` | Enable/disable monitoring for this resource |
| `shoehorn.dev/monitoring-level` | `"basic"`, `"detailed"`, or `"full"` | Set monitoring detail level |
| `shoehorn.dev/scrape-interval` | Duration (e.g., `"30s"`, `"1m"`) | Override default scrape interval |
| `shoehorn.dev/collect-pod-metrics` | `"true"` or `"false"` | Enable pod-level CPU/memory metrics (requires metrics-server) |
| `shoehorn.dev/collect-events` | `"true"` or `"false"` | Enable event collection for this workload |

### GitOps Integration

Enables the agent to watch ArgoCD Applications or FluxCD resources and report their sync/health status to Shoehorn. GitOps resources are linked to k8s-workload entities automatically via the managed resources they control.

GitOps integration is **independent** of standard workload watching -- you can enable GitOps without changing any workload settings, and vice versa.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `agent.gitops.tool` | GitOps tool to watch: `argocd`, `fluxcd`, or `""` (disabled) | `""` |
| `agent.gitops.watchAllNamespaces` | Watch resources across all namespaces (requires ClusterRole). When `false`, only the tool's own namespace is watched (uses Role) | `false` |
| `agent.gitops.commandPollInterval` | How often to poll Shoehorn for pending sync/refresh commands | `10s` |
| `agent.gitops.argocd.namespace` | Namespace where ArgoCD is installed | `argocd` |
| `agent.gitops.argocd.serverURL` | ArgoCD server URL for executing sync/refresh commands | `""` |
| `agent.gitops.argocd.token` | ArgoCD API token (set via `--set`, never in plain values files) | `""` |
| `agent.gitops.fluxcd.namespace` | Namespace where FluxCD is installed | `flux-system` |

**RBAC note**: When `watchAllNamespaces: false` (default), the chart creates a namespaced `Role` scoped to the tool's namespace (`argocd.namespace` or `fluxcd.namespace`). When `watchAllNamespaces: true`, a `ClusterRole` is used instead -- required if resources are spread across multiple namespaces.

### Image Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `image.registry` | Container registry | `ghcr.io` |
| `image.repository` | Image repository | `shoehorn-dev/shoehorn-k8s-agent` |
| `image.tag` | Image tag | `.Chart.AppVersion` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |

### Resources and Deployment

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of replicas (use 3 for HA) | `1` |
| `resources.limits.cpu` | CPU limit | `100m` |
| `resources.limits.memory` | Memory limit | `150Mi` |
| `resources.requests.cpu` | CPU request | `30m` |
| `resources.requests.memory` | Memory request | `80Mi` |

### High Availability

| Parameter | Description | Default |
|-----------|-------------|---------|
| `leaderElection.enabled` | Enable leader election for HA | `true` |
| `leaderElection.namespace` | Namespace for leader election lease | Release namespace |
| `podDisruptionBudget.enabled` | Enable PodDisruptionBudget | `true` |
| `podDisruptionBudget.maxUnavailable` | Max unavailable pods | `0` |
| `podDisruptionBudget.minAvailable` | Min available pods | `null` |

> **Important**: When running multiple replicas (`replicaCount > 1`), `leaderElection.enabled` **must** be `true` to prevent duplicate events.

### Network Observer (eBPF)

Optional DaemonSet that captures pod-to-pod TCP connections using eBPF for service dependency mapping.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `netobserver.enabled` | Enable the network observer DaemonSet | `false` |
| `netobserver.image.registry` | Container registry | `ghcr.io` |
| `netobserver.image.repository` | Image repository | `shoehorn-dev/shoehorn-netobserver` |
| `netobserver.logLevel` | Log level (independent of main agent) | `info` |
| `netobserver.healthPort` | Health server port | `8082` |
| `netobserver.flushInterval` | Aggregation flush interval | `60s` |
| `netobserver.maxFlowsPerInterval` | Max flows per interval | `1000` |
| `netobserver.dropUnresolvable` | Drop flows with unresolvable endpoints | `true` |
| `netobserver.intraClusterOnly` | Only capture intra-cluster (pod-to-pod) flows | `true` |
| `netobserver.excludePorts` | TCP ports to exclude (comma-separated) | `443,5432,6379,3306,27017` |
| `netobserver.namespaces` | Namespaces to observe (empty = all) | `[]` |
| `netobserver.excludeNamespaces` | Namespaces to exclude | `[]` |

**Requirements**: Linux kernel >= 5.2 with BTF (`CONFIG_DEBUG_INFO_BTF=y`). Gracefully degrades (no-op) if eBPF loading fails.

For a complete list of parameters, see `values.yaml`.

## High Availability

For high availability, deploy with 3 replicas and adjust PodDisruptionBudget:

```bash
helm install shoehorn-k8s-agent oci://ghcr.io/shoehorn-dev/helm-charts/shoehorn-k8s-agent \
  --set shoehorn.apiURL=https://shoehorn.example.com \
  --set shoehorn.apiToken=sha_your_token_here \
  --set shoehorn.cluster.id=prod-us-east-1 \
  --set replicaCount=3 \
  --set leaderElection.enabled=true \
  --set podDisruptionBudget.maxUnavailable=null \
  --set podDisruptionBudget.minAvailable=2
```

Leader election ensures only one pod actively sends events to prevent duplicates.

## Advanced Configuration Examples

### Watch Specific Namespaces

Monitor only production namespaces:

```bash
helm install shoehorn-k8s-agent oci://ghcr.io/shoehorn-dev/helm-charts/shoehorn-k8s-agent \
  --set shoehorn.apiURL=https://shoehorn.example.com \
  --set shoehorn.apiToken=sha_your_token_here \
  --set shoehorn.cluster.id=prod-us-east-1 \
  --set agent.kubernetes.namespaces={prod,prod-east,prod-west}
```

### Exclude System Namespaces

Watch all namespaces except kube-system:

```bash
helm install shoehorn-k8s-agent oci://ghcr.io/shoehorn-dev/helm-charts/shoehorn-k8s-agent \
  --set shoehorn.apiURL=https://shoehorn.example.com \
  --set shoehorn.apiToken=sha_your_token_here \
  --set shoehorn.cluster.id=prod-us-east-1 \
  --set agent.kubernetes.excludeNamespaces={kube-system,kube-public,kube-node-lease}
```

### Filter by Labels

Monitor only resources managed by Helm:

```bash
helm install shoehorn-k8s-agent oci://ghcr.io/shoehorn-dev/helm-charts/shoehorn-k8s-agent \
  --set shoehorn.apiURL=https://shoehorn.example.com \
  --set shoehorn.apiToken=sha_your_token_here \
  --set shoehorn.cluster.id=prod-us-east-1 \
  --set agent.kubernetes.labelSelector="app.kubernetes.io/managed-by=Helm"
```

### Watch Specific Resource Kinds

Monitor only Deployments and Services:

```bash
helm install shoehorn-k8s-agent oci://ghcr.io/shoehorn-dev/helm-charts/shoehorn-k8s-agent \
  --set shoehorn.apiURL=https://shoehorn.example.com \
  --set shoehorn.apiToken=sha_your_token_here \
  --set shoehorn.cluster.id=prod-us-east-1 \
  --set agent.kubernetes.watchedKinds={Deployment,Service}
```

### With Cluster Dashboard URL

Include a link to your Kubernetes dashboard:

```bash
helm install shoehorn-k8s-agent oci://ghcr.io/shoehorn-dev/helm-charts/shoehorn-k8s-agent \
  --set shoehorn.apiURL=https://shoehorn.example.com \
  --set shoehorn.apiToken=sha_your_token_here \
  --set shoehorn.cluster.id=prod-us-east-1 \
  --set shoehorn.cluster.name="Production US East" \
  --set shoehorn.cluster.dashboardURL=https://k8s-dashboard.example.com
```

## GitOps Integration

### ArgoCD

Prerequisites: ArgoCD installed in the cluster and accessible. Generate an API token for the agent:

```bash
# Port-forward ArgoCD if not publicly accessible
kubectl port-forward svc/argocd-server -n argocd 8080:80

# Generate a token (uses the admin account; create a dedicated account for production)
argocd login localhost:8080
argocd account generate-token --account admin
```

Install with ArgoCD integration enabled:

```bash
helm install shoehorn-k8s-agent oci://ghcr.io/shoehorn-dev/helm-charts/shoehorn-k8s-agent \
  --set shoehorn.apiURL=https://shoehorn.example.com \
  --set shoehorn.apiToken=sha_your_token_here \
  --set shoehorn.cluster.id=prod-us-east-1 \
  --set agent.gitops.tool=argocd \
  --set agent.gitops.argocd.namespace=argocd \
  --set agent.gitops.argocd.serverURL=https://argocd.example.com \
  --set agent.gitops.argocd.token=<argocd-api-token>
```

Or via a values file (keep the token out of version control):

```yaml
# values-argocd.yaml
agent:
  gitops:
    tool: argocd
    argocd:
      namespace: argocd
      serverURL: https://argocd.example.com
      token: ""          # set via --set agent.gitops.argocd.token=<token>
    watchAllNamespaces: false
    commandPollInterval: 10s
```

```bash
helm install shoehorn-k8s-agent oci://ghcr.io/shoehorn-dev/helm-charts/shoehorn-k8s-agent \
  -f values-argocd.yaml \
  --set shoehorn.apiToken=sha_your_token_here \
  --set agent.gitops.argocd.token=<argocd-api-token>
```

For clusters where ArgoCD Applications are deployed across multiple namespaces, enable cluster-wide watching:

```bash
helm install shoehorn-k8s-agent oci://ghcr.io/shoehorn-dev/helm-charts/shoehorn-k8s-agent \
  --set shoehorn.apiURL=https://shoehorn.example.com \
  --set shoehorn.apiToken=sha_your_token_here \
  --set shoehorn.cluster.id=prod-us-east-1 \
  --set agent.gitops.tool=argocd \
  --set agent.gitops.argocd.namespace=argocd \
  --set agent.gitops.argocd.serverURL=https://argocd.example.com \
  --set agent.gitops.argocd.token=<argocd-api-token> \
  --set agent.gitops.watchAllNamespaces=true
```

### FluxCD

Prerequisites: FluxCD bootstrapped in the cluster (flux-system namespace present).

```bash
helm install shoehorn-k8s-agent oci://ghcr.io/shoehorn-dev/helm-charts/shoehorn-k8s-agent \
  --set shoehorn.apiURL=https://shoehorn.example.com \
  --set shoehorn.apiToken=sha_your_token_here \
  --set shoehorn.cluster.id=prod-us-east-1 \
  --set agent.gitops.tool=fluxcd
```

FluxCD does not require an API token -- the agent watches Kustomization and HelmRelease CRDs directly using the Kubernetes API.

For clusters where Flux resources are distributed across tenant namespaces:

```bash
helm install shoehorn-k8s-agent oci://ghcr.io/shoehorn-dev/helm-charts/shoehorn-k8s-agent \
  --set shoehorn.apiURL=https://shoehorn.example.com \
  --set shoehorn.apiToken=sha_your_token_here \
  --set shoehorn.cluster.id=prod-us-east-1 \
  --set agent.gitops.tool=fluxcd \
  --set agent.gitops.fluxcd.namespace=flux-system \
  --set agent.gitops.watchAllNamespaces=true
```

### Disable GitOps

Leave `agent.gitops.tool` unset (default) or set it to an empty string:

```bash
helm upgrade shoehorn-k8s-agent oci://ghcr.io/shoehorn-dev/helm-charts/shoehorn-k8s-agent \
  --set agent.gitops.tool=""
```

## RBAC

The chart creates a ClusterRole with read-only access to the following resources:

| API Group | Resources | Purpose |
|-----------|-----------|---------|
| `apps` | deployments, statefulsets, daemonsets | Workload discovery |
| `batch` | cronjobs, jobs | Batch workload discovery |
| `""` (core) | namespaces, pods, services, events | Core resource monitoring |
| `networking.k8s.io` | ingresses, networkpolicies | Ingress and network policy visibility |
| `cilium.io` | ciliumnetworkpolicies, ciliumclusterwidenetworkpolicies | Cilium network policy visibility (graceful skip if CRDs not installed) |
| `metrics.k8s.io` | pods | Resource usage metrics (requires metrics-server) |
| `coordination.k8s.io` | leases | Leader election for HA |

When `agent.gitops.watchAllNamespaces: true`, additional CRD access is added for ArgoCD (`argoproj.io`) or FluxCD (`kustomize.toolkit.fluxcd.io`, `helm.toolkit.fluxcd.io`, `source.toolkit.fluxcd.io`).

## Network Observer

Enable eBPF-based network flow capture for automatic service dependency mapping:

```bash
helm install shoehorn-k8s-agent oci://ghcr.io/shoehorn-dev/helm-charts/shoehorn-k8s-agent \
  --set shoehorn.apiURL=https://shoehorn.example.com \
  --set shoehorn.apiToken=sha_your_token_here \
  --set shoehorn.cluster.id=prod-us-east-1 \
  --set netobserver.enabled=true
```

The NetObserver runs as a DaemonSet on every node, capturing pod-to-pod TCP connections. It resolves source/destination IPs to catalog entities and reports flow data to Shoehorn for dependency visualization.

To exclude system namespaces from flow capture:

```bash
helm install shoehorn-k8s-agent oci://ghcr.io/shoehorn-dev/helm-charts/shoehorn-k8s-agent \
  --set shoehorn.apiURL=https://shoehorn.example.com \
  --set shoehorn.apiToken=sha_your_token_here \
  --set shoehorn.cluster.id=prod-us-east-1 \
  --set netobserver.enabled=true \
  --set netobserver.excludeNamespaces={kube-system,kube-public}
```

## Annotation-Based Monitoring

### Opt-In Monitoring (require-annotation mode)

Only monitor resources explicitly annotated with `shoehorn.dev/monitor=true`:

```bash
helm install shoehorn-k8s-agent oci://ghcr.io/shoehorn-dev/helm-charts/shoehorn-k8s-agent \
  --set shoehorn.apiURL=https://shoehorn.example.com \
  --set shoehorn.apiToken=sha_your_token_here \
  --set shoehorn.cluster.id=prod-us-east-1 \
  --set agent.annotations.defaultBehavior=require-annotation
```

Then annotate specific resources:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  annotations:
    shoehorn.dev/monitor: "true"
    shoehorn.dev/monitoring-level: "detailed"
spec:
  # ...
```

### Monitoring Levels by Namespace

Monitor production with basic level, staging with detailed level:

```bash
# Production: basic monitoring (default)
kubectl annotate namespace production shoehorn.dev/monitoring-level=basic

# Staging: detailed monitoring for troubleshooting
kubectl annotate namespace staging shoehorn.dev/monitoring-level=detailed
```

### High-Detail Monitoring for Critical Workloads

Monitor specific deployments with full detail:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-service
  namespace: production
  annotations:
    shoehorn.dev/monitoring-level: "full"
    shoehorn.dev/collect-pod-metrics: "true"
    shoehorn.dev/collect-events: "true"
spec:
  # ...
```

### Exclude Specific Resources

Monitor all resources except test deployments:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-deployment
  annotations:
    shoehorn.dev/monitor: "false"  # Explicitly exclude
spec:
  # ...
```

### Pod-Level Monitoring

The agent supports Pod watching with three monitoring levels:

**Basic** (default, low overhead):
- Pod status and phase
- Ready condition
- Owner references

**Detailed** (medium overhead):
- All basic fields
- Container restart counts (aggregated across all containers)
- Container states (waiting/running/terminated with reasons)
- Pod conditions (Ready, PodScheduled, Initialized, ContainersReady)

**Full** (high overhead, requires metrics-server):
- All detailed fields
- CPU and memory requests/limits per container
- QoS class (Guaranteed, Burstable, BestEffort)
- Enables pod-level metrics collection via metrics-server

Example with full Pod monitoring:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-server
  annotations:
    shoehorn.dev/monitoring-level: "full"
    shoehorn.dev/collect-pod-metrics: "true"
spec:
  template:
    metadata:
      annotations:
        # Pods inherit deployment annotations automatically
        shoehorn.dev/monitoring-level: "full"
    spec:
      # ...
```

## Example Configurations

Ready-to-use example values files are provided in the `examples/` directory:

| File | Description |
|------|-------------|
| `values-minimal.yaml` | Quick start with just required values |
| `values-production.yaml` | HA deployment with 3 replicas, anti-affinity, security hardening |
| `values-filtered.yaml` | Namespace and resource filtering examples |
| `values-annotations.yaml` | Annotation-based monitoring with Pod watching examples |

### Using Example Files

```bash
# Minimal deployment
helm install shoehorn-k8s-agent oci://ghcr.io/shoehorn-dev/helm-charts/shoehorn-k8s-agent \
  -f examples/values-minimal.yaml \
  --set shoehorn.apiToken=sha_your_token_here

# Production deployment
helm install shoehorn-k8s-agent oci://ghcr.io/shoehorn-dev/helm-charts/shoehorn-k8s-agent \
  -f examples/values-production.yaml \
  --set shoehorn.apiToken=sha_your_token_here
```

### IDE Autocompletion

This chart includes a `values.schema.json` file for IDE autocompletion. To enable:

**VS Code**: Install the [YAML extension](https://marketplace.visualstudio.com/items?itemName=redhat.vscode-yaml)

**JetBrains IDEs**: Autocompletion works automatically when editing `values.yaml`

## Validation

Required values are validated at template render time. If a required value is missing, `helm install` will fail immediately with a clear error:

```
Error: execution error: shoehorn.apiURL is required
```

Required values: `shoehorn.apiURL`, `shoehorn.apiToken`, `shoehorn.cluster.id`

## Uninstallation

```bash
helm uninstall shoehorn-k8s-agent
```
