# Shoehorn

Self-hosted Intelligent Developer Platform on Kubernetes. Service catalog, scorecards, golden paths, TechDocs, and workflow automation.

## TL;DR

```bash
# 1. Create namespace and the credential secret.
kubectl create namespace shoehorn

kubectl create secret generic shoehorn-credentials -n shoehorn \
  --from-literal=postgres_password="$(openssl rand -base64 24)" \
  --from-literal=db_password="$(openssl rand -base64 24)" \
  --from-literal=valkey_password="$(openssl rand -base64 24)" \
  --from-literal=meilisearch_master_key="$(openssl rand -hex 32)" \
  --from-literal=jwt_secret="$(openssl rand -hex 32)" \
  --from-literal=auth_encryption_key="$(openssl rand -base64 32)" \
  --from-literal=secrets_encryption_key="$(openssl rand -hex 32)"

# 2. Install. Replace YOUR_* placeholders with values from your Zitadel project
#    (or switch to auth.provider=okta and use auth.okta.* instead).
#    If your cluster has no default StorageClass, add --set global.storageClass=YOUR_CLASS.
helm install shoehorn oci://ghcr.io/shoehorn-dev/helm-charts/shoehorn \
  --namespace shoehorn \
  --set secret.defaultName=shoehorn-credentials \
  --set global.domain=idp.example.com \
  --set global.organization.slug=my-company \
  --set global.organization.name="My Company" \
  --set auth.zitadel.projectId=YOUR_ZITADEL_PROJECT_ID \
  --set auth.zitadel.clientId=YOUR_ZITADEL_CLIENT_ID \
  --set auth.zitadel.externalUrl=https://YOUR_INSTANCE.zitadel.cloud \
  --wait
```

The `--set` values above are the minimum the chart requires beyond credentials. The full example with comments lives at [`examples/values-minimal.yaml`](examples/values-minimal.yaml).

## Introduction

This chart deploys Shoehorn on a Kubernetes cluster using the [Helm](https://helm.sh) package manager. It bundles the Shoehorn microservices (api, web, eventbus, worker, crawler, forge) along with PostgreSQL, Valkey, Meilisearch, and Redpanda.

Container images live on [Docker Hub](https://hub.docker.com/u/shoehorned). The chart is published to `oci://ghcr.io/shoehorn-dev/helm-charts/shoehorn`.

## Prerequisites

- Kubernetes 1.24+
- Helm 4.0+
- An ingress controller. Traefik or Envoy Gateway recommended. If you don't have one yet, install Traefik:
  ```bash
  helm repo add traefik https://traefik.github.io/charts
  helm install traefik traefik/traefik --namespace traefik --create-namespace --version 36.0.0
  ```
  Or skip ingress entirely and reach the app with `kubectl port-forward` (set `--set ingressRoute.enabled=false --set ingress.enabled=false`).
- cert-manager (optional, for automatic TLS). Install [out-of-band](#cert-manager-bundling-is-unsupported).
- A Kubernetes Secret with credentials (see [Secrets](#secrets)). On Windows without `openssl`, see [Generating secrets on Windows](#generating-secrets-on-windows).

## Installing the Chart

```bash
helm install shoehorn oci://ghcr.io/shoehorn-dev/helm-charts/shoehorn \
  --namespace shoehorn --create-namespace \
  --values custom-values.yaml \
  --wait
```

Two example values files ship with the chart:

- [`examples/values-minimal.yaml`](examples/values-minimal.yaml): single Secret, no persistence, dev-friendly
- [`examples/values-eso-vault.yaml`](examples/values-eso-vault.yaml): per-credential Secrets via External Secrets Operator + Vault

Verify the install:

```bash
kubectl get pods -n shoehorn
kubectl get ingressroute -n shoehorn   # or: kubectl get ingress -n shoehorn
```

## Uninstalling the Chart

```bash
helm uninstall shoehorn -n shoehorn
```

The PostgreSQL StatefulSet carries `helm.sh/resource-policy: keep`, so the database survives `helm uninstall`. A reinstall reattaches the same PVC.

To drop the database explicitly:

```bash
kubectl delete sts -n shoehorn shoehorn-postgresql
kubectl delete pvc -n shoehorn --all
kubectl delete namespace shoehorn
```

## Secrets

The chart never creates Secrets. It only references them. Each credential has a typed `*SecretRef` block matching Kubernetes' native `valueFrom.secretKeyRef`:

```yaml
<thing>SecretRef:
  name: <kubernetes-secret-name>   # optional if secret.defaultName is set
  key:  <key-inside-secret>
```

Two workflows:

**One Secret for everything.** Set `secret.defaultName: shoehorn-credentials`. Every `*SecretRef` falls back to that name, so each ref only needs `key:` (and most defaults already match the keys in the TL;DR `kubectl` command).

**Per-credential Secrets.** Set `name:` explicitly on each ref. Useful with External Secrets Operator, Sealed Secrets, or Vault when each credential domain syncs from its own upstream path.

### Credentials reference

| Env var | Values path | Notes |
|---|---|---|
| `POSTGRES_PASSWORD` | `postgresql.superuserPasswordSecretRef` | `shoehorn_user`, BYPASSRLS, runs migrations |
| `DB_PASSWORD` | `postgresql.passwordSecretRef` | `app_user`, NOBYPASSRLS, runtime queries |
| `VALKEY_PASSWORD` | `valkey.passwordSecretRef` | |
| `MEILI_MASTER_KEY` | `meilisearch.masterKeySecretRef` | Same value used by server and clients |
| `JWT_SECRET` | `auth.session.jwtSecretRef` | Required |
| `AUTH_ENCRYPTION_KEY` | `auth.session.encryptionKeyRef` | Required |
| `SECRETS_ENCRYPTION_KEY` | `auth.session.secretsEncryptionKeyRef` | Required |
| `ZITADEL_SERVICE_USER_PAT` | `auth.zitadel.serviceUserPatSecretRef` | Optional, for orgdata sync |
| `OKTA_CLIENT_SECRET` | `auth.okta.clientSecretRef` | Required when `auth.provider=okta` |
| `OKTA_API_TOKEN` | `auth.okta.apiTokenSecretRef` | Optional, for Okta orgdata sync |
| `ARGOCD_TOKEN` | `auth.argocd.tokenSecretRef` | Optional |
| `UPCLOUD_TOKEN` | `cloudProviders.upcloud.tokenSecretRef` | Required when `cloudProviders.upcloud.enabled` |
| `SMTP_PASSWORD` | `smtp.passwordSecretRef` | Required when `smtp.enabled` |

Public identifiers (`auth.github.appId`, `auth.github.installationId`, `auth.zitadel.projectId`, `auth.zitadel.clientId`) are plain values, not Secret references.

### Generating secrets on Windows

The TL;DR uses `openssl rand`, which isn't on stock Windows. PowerShell equivalent:

```powershell
function New-Hex { param([int]$Bytes) -join ((48..57)+(97..102) | Get-Random -Count ($Bytes * 2) | ForEach-Object { [char]$_ }) }

kubectl create secret generic shoehorn-credentials -n shoehorn `
  --from-literal=postgres_password=(New-Hex 16) `
  --from-literal=db_password=(New-Hex 16) `
  --from-literal=valkey_password=(New-Hex 16) `
  --from-literal=meilisearch_master_key=(New-Hex 32) `
  --from-literal=jwt_secret=(New-Hex 32) `
  --from-literal=auth_encryption_key=(New-Hex 32) `
  --from-literal=secrets_encryption_key=(New-Hex 32)
```

### File-based credentials

GitHub App private keys must land on disk as files. Mount them via `extraVolumes` and `extraVolumeMounts`:

```yaml
extraVolumes:
- name: github-private-key
  secret:
    secretName: shoehorn-credentials
    items:
    - key: github_app_private_key
      path: private-key

extraVolumeMounts:
- name: github-private-key
  mountPath: /var/secrets/github
  readOnly: true
```

## Configuration

The full parameter list lives in [`values.yaml`](values.yaml), with a [`values.schema.json`](values.schema.json) for IDE autocompletion and template-time validation.

Key parameters:

| Parameter | Description | Default |
|---|---|---|
| `global.domain` | Hostname users reach Shoehorn at (no default — chart fails fast if unset, e.g. `idp.acme.internal`) | _(required)_ |
| `global.organization.slug` | URL-safe org identifier (required) | `""` |
| `global.storageClass` | Default storage class for PVCs | `""` |
| `secret.defaultName` | Fallback Secret name for refs without `name:` | `""` |
| `auth.provider` | `zitadel` or `okta` | `zitadel` |
| `auth.audience` | Expected JWT audience; empty defaults to the provider's client_id | `""` |
| `ingressRoute.enabled` | Traefik IngressRoute | `true` |
| `ingress.enabled` | Standard Kubernetes Ingress | `false` |
| `postgresql.persistence.size` | PVC size | `20Gi` |
| `postgresql.external.enabled` | Use external PostgreSQL | `false` |
| `valkey.external.enabled` | Use external Redis/Valkey | `false` |
| `meilisearch.external.enabled` | Use Meilisearch Cloud | `false` |
| `redpanda.external.enabled` | Use external Kafka/Redpanda | `false` |
| `smtp.enabled` | SMTP delivery | `false` |
| `global.tracing.enabled` | OpenTelemetry tracing | `false` |
| `global.mtls.enabled` | gRPC mTLS between services | `false` |
| `auth.orgdata.enabled` | Sync users and teams from IdPs | `false` |

Per-service overrides (`api`, `web`, `eventbus`, `worker`, `crawler`, `forge`) accept `replicaCount`, `autoscaling`, `resources`, `env`, and `logLevel`.

The chart fails template rendering when a required `*SecretRef` can't resolve to a Secret name, or when an auth provider is missing required fields. Errors surface as plain messages in `helm install` output.

### Multi-tenancy

PostgreSQL Row-Level Security is always on. There is no toggle. Runtime services connect as `app_user` (NOBYPASSRLS); migrations run as `shoehorn_user` (BYPASSRLS). Both passwords are required (`postgres_password`, `db_password`).

For single-tenant deployments, RLS still runs but the middleware injects a fixed tenant ID derived from `global.organization.slug`.

### Identity providers

Supported: Zitadel (default), Okta. See:

- [`examples/values-okta.yaml`](examples/values-okta.yaml)
- [Okta integration guide](https://docs.shoehorn.dev/integrations/okta)

## Upgrading

```bash
helm upgrade shoehorn oci://ghcr.io/shoehorn-dev/helm-charts/shoehorn \
  --namespace shoehorn --values custom-values.yaml --wait

helm history shoehorn -n shoehorn
helm rollback shoehorn 1 -n shoehorn
```

### PostgreSQL is decoupled from chart upgrades

The postgres StatefulSet uses `updateStrategy: OnDelete`. Chart upgrades don't restart the database pod, so platform releases don't block on postgres rolling. Roll it explicitly when bumping the postgres image:

```bash
kubectl delete pod -n shoehorn shoehorn-postgresql-0
```

The postgres image tag is pinned in `values.yaml` and tracks postgres releases, not platform releases.

## Operational notes

### cert-manager bundling is unsupported

`certManager.install: true` exists in `values.yaml` but doesn't work reliably: Helm validates the chart's `Certificate` and `ClusterIssuer` manifests against the API server before applying them, and cert-manager CRDs from the same release aren't registered yet at validation time.

Install cert-manager out-of-band, then deploy this chart with `certManager.install: false`:

```bash
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --version v1.20.0 --set crds.enabled=true --wait
```

### Use a namespaced `Issuer` on small clusters

`certManager.issuer.kind: ClusterIssuer` (the default) looks for the CA secret in cert-manager's `clusterResourceNamespace` (default `cert-manager`), not the release namespace. The chart creates the CA secret in the release namespace, so the issuer fails with `secrets "shoehorn-ca-secret" not found`.

Either configure cert-manager with `--cluster-resource-namespace=<release-ns>`, or switch this chart to a namespaced Issuer:

```yaml
certManager:
  issuer:
    kind: Issuer
global:
  mtls:
    issuerKind: Issuer
```

### `redpanda.replicas: 3` needs 3+ nodes

Redpanda uses pod anti-affinity, so each replica needs its own node. On 1- or 2-node clusters the third replica stays `Pending`. Set `redpanda.replicas: 1` for small clusters, or scale the node pool first.

## Troubleshooting

```bash
# Pod state and logs
kubectl get pods -n shoehorn
kubectl logs -n shoehorn <pod-name>
kubectl describe pod -n shoehorn <pod-name>

# Secret keys
kubectl get secret shoehorn-credentials -n shoehorn -o jsonpath='{.data}' | jq 'keys'

# Database
kubectl logs -n shoehorn -l app.kubernetes.io/component=postgresql

# Ingress
kubectl get ingressroute -n shoehorn   # Traefik
kubectl get ingress -n shoehorn        # standard
```

## Support

- Documentation: <https://docs.shoehorn.dev>
- Source: <https://github.com/shoehorn-dev/helm-charts>
- Issues: <https://github.com/shoehorn-dev/helm-charts/issues>

## License

Apache-2.0
