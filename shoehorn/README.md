# Shoehorn Helm Chart

Official Helm chart for deploying Shoehorn, the Intelligent Developer Platform, on Kubernetes.

## Prerequisites

**Minimum Requirements:**
- Kubernetes 1.24+
- Helm 4.0+
- Ingress Controller (Traefik recommended, Envoy supported)

**Optional:**
- Cert-Manager (for automatic TLS certificates)
- External database services (RDS, Cloud SQL, etc.)
- External caching/messaging services (ElastiCache, Redpanda Cloud, etc.)

## Architecture

```
                    Ingress (Traefik or Envoy)
                    TLS termination, routing
                            |
                +-----------+-----------+
                |                       |
                v                       v
         +-----------+          +-----------+
         |    Web    |          |    API    |
         | SvelteKit |          |  Go/Chi   |
         |   :4173   |          |   :8080   |
         +-----------+          +-----+-----+
                                      |
                   +--------+---------+---------+--------+
                   |        |         |         |        |
                   v        v         v         v        v
              EventBus   Worker   Crawler    Forge
               gRPC      gRPC     gRPC      gRPC
                   |        |         |         |        |
                   +--------+---------+---------+--------+
                                      |
                   +------------------+------------------+
                   |                  |                  |
                   v                  v                  v
             PostgreSQL          Meilisearch         Redpanda
                   |
                   v
                Valkey

         Cerbos (policy-based authorization) - always deployed
```

### Services

| Service | Type | Port | Purpose |
|---------|------|------|---------|
| **Web** | Deployment | 4173 | SvelteKit frontend |
| **API** | Deployment | 8080 | REST API Gateway (Go/Chi) |
| **EventBus** | Deployment | 8083/9083 | Event streaming service (gRPC) |
| **Worker** | Deployment | 8085/9085 | Background job processor (gRPC) |
| **Crawler** | Deployment | 8086/9086 | Repository discovery & GitHub integration (gRPC) |
| **Forge** | Deployment | 8087/9087 | Workflow engine & scaffolding (gRPC) |
| **Cerbos** | Deployment | 3592/3593 | Policy-based authorization (always deployed) |
| **PostgreSQL** | StatefulSet | 5432 | Primary database with RLS for multi-tenancy |
| **Meilisearch** | StatefulSet | 7700 | Search engine |
| **Valkey** | StatefulSet | 6379 | Redis-compatible cache |
| **Redpanda** | StatefulSet | 9092 | Kafka-compatible event streaming |

## Quick Start

### 1. Create Namespace

```bash
kubectl create namespace shoehorn
```

### 2. Create Secret(s)

The chart never creates Secrets. It only references them. Each credential has a typed `*SecretRef` block that mirrors Kubernetes' native `valueFrom.secretKeyRef`:

```yaml
<thing>SecretRef:
  name: <kubernetes-secret-name>   # optional if secret.defaultName is set
  key:  <key-inside-secret>        # the key holding the credential
```

Pick one of two workflows.

#### Path A: one Secret for everything (kubectl / Sealed Secrets)

Stuff every credential into a single Secret, then set `secret.defaultName`. Each `*SecretRef` can omit `name:` and just supply `key:` (most defaults already match the key names below).

```bash
kubectl create secret generic shoehorn-credentials -n shoehorn \
  --from-literal=postgres_password="$(openssl rand -base64 24)" \
  --from-literal=db_password="$(openssl rand -base64 24)" \
  --from-literal=valkey_password="$(openssl rand -base64 24)" \
  --from-literal=meilisearch_master_key="$(openssl rand -hex 32)" \
  --from-literal=jwt_secret="$(openssl rand -hex 32)" \
  --from-literal=auth_encryption_key="$(openssl rand -base64 32)" \
  --from-literal=secrets_encryption_key="$(openssl rand -hex 32)"
```

```yaml
secret:
  defaultName: shoehorn-credentials
```

See [`examples/values-minimal.yaml`](examples/values-minimal.yaml) for the full minimal layout.

#### Path B: per-credential Secrets (ESO + Vault / AWS / GCP)

Sync each credential domain to its own K8s Secret (typically one per upstream path) and set `name:` explicitly on each `*SecretRef`:

```yaml
postgresql:
  superuserPasswordSecretRef:
    name: shoehorn-postgres
    key: postgres_password
  passwordSecretRef:
    name: shoehorn-postgres
    key: db_password

valkey:
  passwordSecretRef:
    name: shoehorn-valkey
    key: password

auth:
  session:
    jwtSecretRef:
      name: shoehorn-auth
      key: jwt_secret
    encryptionKeyRef:
      name: shoehorn-auth
      key: auth_encryption_key
    secretsEncryptionKeyRef:
      name: shoehorn-auth
      key: secrets_encryption_key
```

See [`examples/values-eso-vault.yaml`](examples/values-eso-vault.yaml) for a complete ExternalSecret + Vault setup.

Public identifiers (`auth.github.appId`, `installationId`, `forge.organization`, `auth.zitadel.projectId`, `auth.zitadel.clientId`, etc.) are plain values, not Secret references.

### 3. Configure File-Based Secrets

GitHub private keys must be mounted as files. Use `extraVolumes` and `extraVolumeMounts`:

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

### 4. Install Shoehorn

Images live on Docker Hub at [`shoehorned/`](https://hub.docker.com/u/shoehorned). They're public, so no pull secret is needed.

```bash
helm install shoehorn oci://ghcr.io/shoehorn-dev/helm-charts/shoehorn \
  --namespace shoehorn \
  --values custom-values.yaml \
  --wait
```

### 5. Access Shoehorn

```bash
# Get ingress address
kubectl get ingress -n shoehorn

# Or with Traefik IngressRoute
kubectl get ingressroute -n shoehorn
```

## Secret Management

### How It Works

The chart references credentials via per-credential typed `*SecretRef` blocks, one per credential, sitting next to the thing they belong to (e.g. `postgresql.passwordSecretRef`, `auth.session.jwtSecretRef`). Each ref takes the same shape as Kubernetes' built-in `valueFrom.secretKeyRef`:

```yaml
postgresql:
  passwordSecretRef:
    name: my-postgres-secret   # Kubernetes Secret name
    key:  db_password          # key inside that Secret
```

The chart wires each ref into the matching environment variable (or downstream config) on the pods that need it. The chart does **not** create Secrets. Bring your own Secret object via `kubectl`, Sealed Secrets, External Secrets Operator, Vault, AWS/Azure/GCP providers, etc.

`secret.defaultName` is an optional shortcut: when set, any `*SecretRef` with `name` left blank falls back to this value. This makes the one-Secret-for-everything workflow concise without changing the underlying mechanics.

### Supported Secret Providers

Any tool that creates a standard Kubernetes Secret works: kubectl, External Secrets Operator (Vault / AWS / Azure / GCP / 1Password / etc.), Sealed Secrets, Vault Agent Injector, CSI Secret Store, and so on. The chart only cares that a Secret object exists with the referenced `name` and `key` at install time.

### `*SecretRef` reference

Every credential the chart consumes, the values path that points at it, and the env var the chart emits on the consuming pods.

| Env var | Values path | Notes |
|---|---|---|
| `POSTGRES_PASSWORD` | `postgresql.superuserPasswordSecretRef` | shoehorn_user (migrations, BYPASSRLS) |
| `DB_PASSWORD` | `postgresql.passwordSecretRef` | app_user (runtime, NOBYPASSRLS) |
| `VALKEY_PASSWORD` | `valkey.passwordSecretRef` | |
| `MEILI_MASTER_KEY` (server) / `MEILISEARCH_API_KEY` (clients) | `meilisearch.masterKeySecretRef` | Same value, both sides |
| `JWT_SECRET` | `auth.session.jwtSecretRef` | Required |
| `AUTH_ENCRYPTION_KEY` | `auth.session.encryptionKeyRef` | Required |
| `SECRETS_ENCRYPTION_KEY` | `auth.session.secretsEncryptionKeyRef` | Required |
| `ZITADEL_SERVICE_USER_PAT` | `auth.zitadel.serviceUserPatSecretRef` | Optional, for orgdata sync |
| `OKTA_CLIENT_SECRET` | `auth.okta.clientSecretRef` | Required when `auth.provider=okta` |
| `OKTA_API_TOKEN` | `auth.okta.apiTokenSecretRef` | Optional, for Okta orgdata sync |
| `ENTRA_CLIENT_SECRET` | `auth.entraId.clientSecretRef` | Required when `auth.provider=entra-id` |
| `ARGOCD_TOKEN` | `auth.argocd.tokenSecretRef` | Optional, for ArgoCD sync |
| `UPCLOUD_TOKEN` | `cloudProviders.upcloud.tokenSecretRef` | Required when `cloudProviders.upcloud.enabled` |
| `SMTP_PASSWORD` | `smtp.passwordSecretRef` | Required when `smtp.enabled` |

### Public identifiers (not secrets)

These moved out of the Secret and into plain values. They're not sensitive and shouldn't be wrapped in `*SecretRef`:

| Values path | Description |
|---|---|
| `auth.github.appId` | GitHub App ID |
| `auth.github.installationId` | GitHub App installation ID |
| `auth.github.forge.appId` | Forge GitHub App ID (optional separate App for workflows) |
| `auth.github.forge.installationId` | Forge installation ID |
| `auth.github.forge.organization` | Forge target organization |
| `auth.zitadel.projectId` | Zitadel project ID |
| `auth.zitadel.clientId` | Zitadel OIDC client ID |

### File-based credentials

Things that have to land on disk as files (GitHub App private keys, custom CA bundles) are mounted via `extraVolumes` / `extraVolumeMounts`, not via `*SecretRef`. See the GitHub private key example in the Quick Start above.

### Worked examples

- One shared Secret + `secret.defaultName`: [`examples/values-minimal.yaml`](examples/values-minimal.yaml)
- Per-credential Secrets via External Secrets Operator + Vault: [`examples/values-eso-vault.yaml`](examples/values-eso-vault.yaml)

## Configuration

### Minimal values.yaml

Uses `secret.defaultName` so each `*SecretRef` only needs `key:`. See [`examples/values-minimal.yaml`](examples/values-minimal.yaml) for the full file.

```yaml
global:
  domain: shoehorn.local
  organization:
    slug: my-org

# All credentials live in one Secret named "shoehorn-credentials".
# The default keys on each *SecretRef already match the kubectl example
# in step 2, so no per-ref overrides are needed here.
secret:
  defaultName: shoehorn-credentials

auth:
  provider: zitadel
  zitadel:
    projectId: "YOUR_PROJECT_ID"
    clientId: "YOUR_CLIENT_ID"
    externalUrl: "https://auth.yourdomain.xyz"
  github:
    appId: "YOUR_APP_ID"
    installationId: "YOUR_INSTALLATION_ID"

rbac:
  roleAssignment:
    tenantAdmin:
      user: "admin@example.com"

# Mount GitHub private key (file-based credential, not a *SecretRef)
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

# Development: no persistence
postgresql:
  persistence:
    enabled: false
meilisearch:
  persistence:
    enabled: false
valkey:
  persistence:
    enabled: false
redpanda:
  persistence:
    enabled: false
```

### Production values.yaml

Per-credential Secrets, each `*SecretRef.name` set explicitly so credentials can come from independent vault paths. See [`examples/values-eso-vault.yaml`](examples/values-eso-vault.yaml) for an end-to-end ESO + Vault example.

```yaml
global:
  domain: shoehorn.example.com
  storageClass: fast-ssd
  organization:
    slug: acme-corp
    name: Acme Corporation

ingressRoute:
  enabled: true
  tls:
    enabled: true
    certResolver: letsencrypt

# Per-credential Secrets. Name set explicitly on every ref.
postgresql:
  superuserPasswordSecretRef:
    name: shoehorn-postgres
    key: postgres_password
  passwordSecretRef:
    name: shoehorn-postgres
    key: db_password
  persistence:
    enabled: true
    size: 50Gi

valkey:
  passwordSecretRef:
    name: shoehorn-valkey
    key: password
  persistence:
    enabled: true
    size: 10Gi

meilisearch:
  masterKeySecretRef:
    name: shoehorn-meilisearch
    key: master_key
  persistence:
    enabled: true
    size: 100Gi

redpanda:
  persistence:
    enabled: true
    size: 200Gi

auth:
  provider: zitadel
  zitadel:
    projectId: "YOUR_PROJECT_ID"
    clientId: "YOUR_CLIENT_ID"
    externalUrl: "https://auth.yourdomain.xyz"
    serviceUserPatSecretRef:
      name: shoehorn-zitadel
      key: service_user_pat
  session:
    jwtSecretRef:
      name: shoehorn-auth
      key: jwt_secret
    encryptionKeyRef:
      name: shoehorn-auth
      key: auth_encryption_key
    secretsEncryptionKeyRef:
      name: shoehorn-auth
      key: secrets_encryption_key
  github:
    appId: "YOUR_APP_ID"
    installationId: "YOUR_INSTALLATION_ID"

# Redundancy and zero-downtime rolling updates
replicaCount:
  api: 2
  web: 2
  eventbus: 2
  worker: 2
  crawler: 2
  forge: 2

api:
  autoscaling:
    enabled: true
    minReplicas: 3
    maxReplicas: 20
    targetCPUUtilizationPercentage: 70
```

## Key Configuration Parameters

### Global Settings

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.domain` | Main domain for the application | `shoehorn.example.com` |
| `global.storageClass` | Default storage class for PVCs | `""` |
| `<service>.logLevel` | Per-service log level (`debug`, `info`, `warn`, `error`). Set on `api`, `web`, `eventbus`, `worker`, `crawler`, `forge`. | `"info"` |
| `global.organization.slug` | URL-safe organization identifier (required) | `""` |
| `global.organization.name` | Display name for organization | `""` |
| `global.imagePullSecrets` | List of registry secrets | `[]` |
| `global.tracing.enabled` | Enable OpenTelemetry distributed tracing | `false` |
| `global.mtls.enabled` | Enable mTLS for gRPC services | `false` |

### Secret Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `secret.defaultName` | Optional fallback Secret name. When set, any `*SecretRef.name` left blank resolves to this; per-ref `name:` always wins. | `""` |
| `<thing>SecretRef.name` | Name of the Kubernetes Secret holding this credential. Required unless `secret.defaultName` is set. | `""` |
| `<thing>SecretRef.key` | Key inside the Secret that holds the credential value. | per-ref default |
| `extraVolumes` | Additional volumes for all backend pods (file-based secrets like GitHub private keys). | `[]` |
| `extraVolumeMounts` | Additional volume mounts for all backend pods. | `[]` |

See the [`*SecretRef` reference](#secretref-reference) above for the full list of credential paths.

### Authentication

| Parameter | Description | Default |
|-----------|-------------|---------|
| `auth.provider` | Auth provider (`zitadel`, `okta`, `entra-id`) | `zitadel` |
| `auth.zitadel.projectId` | Zitadel project ID | `""` |
| `auth.zitadel.clientId` | Zitadel OIDC client ID | `""` |
| `auth.zitadel.externalUrl` | Zitadel instance URL | `""` |
| `auth.okta.domain` | Okta org domain (e.g. `your-org.okta.com`). Required when `auth.provider=okta`. | `""` |
| `auth.okta.clientId` | Okta OIDC client ID. Required when `auth.provider=okta`. | `""` |
| `auth.okta.issuer` | Optional issuer override. Leave empty for the default. | `""` |
| `auth.entraId.tenantId` / `clientId` / `authority` | Entra ID config. Required when `auth.provider=entra-id`. | `""` |
| `auth.github.appId` / `installationId` | GitHub App for catalog discovery (api + crawler). Public identifiers. | `""` |
| `auth.github.forge.appId` / `installationId` / `organization` | GitHub Forge App for workflow execution (api + forge). Separate App from the catalog one. | `""` |
| `auth.argocd.tokenSecretRef` | ArgoCD API token for direct sync/refresh calls. Optional. | `{}` |
| `auth.csrf.enabled` | Double-submit CSRF protection on state-changing requests. | `true` |
| `auth.adminAssignment.adminUsers` / `adminGroups` | Comma-separated admin emails / IdP groups (env-var role mapping). | `""` |
| `auth.orgdata.enabled` | Sync users and teams from one or more identity providers. Wired on api and forge (forge needs it for group-based approvals). | `false` |
| `auth.orgdata.providers` | Provider list, e.g. `["okta"]`, `["zitadel"]`, or mixed. | `[]` |
| `auth.orgdata.primaryProvider` | Primary provider for conflict resolution. | `""` |

When `auth.provider=okta`, `values.schema.json` enforces that both `auth.okta.domain` and `auth.okta.clientId` are set. Helm refuses to install otherwise.

#### Okta

See the [Okta integration guide](https://docs.shoehorn.dev/integrations/okta) for the full Okta app configuration (sign-in redirect URIs, groups claim, API token). A working Helm example lives in [`examples/values-okta.yaml`](examples/values-okta.yaml).

### RBAC

| Parameter | Description | Default |
|-----------|-------------|---------|
| `rbac.enabled` | Enable Cerbos RBAC | `true` |
| `rbac.roleAssignment.tenantAdmin.user` | Bootstrap admin email | `""` |
| `rbac.roleAssignment.tenantAdmin.group` | Bootstrap admin group | `""` |

### Ingress

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ingressRoute.enabled` | Enable Traefik IngressRoute | `true` |
| `ingressRoute.tls.enabled` | Enable TLS | `true` |
| `ingress.enabled` | Enable standard Ingress | `false` |

### SMTP

| Parameter | Description | Default |
|-----------|-------------|---------|
| `smtp.enabled` | Enable SMTP email delivery | `false` |
| `smtp.host` | SMTP server host | `""` |
| `smtp.port` | SMTP server port | `587` |
| `smtp.username` | SMTP username | `""` |
| `smtp.from` | Sender email address | `""` |
| `smtp.feedbackEmail` | Recipient for user feedback | `""` |

When SMTP is enabled, set `smtp.passwordSecretRef.name` and `smtp.passwordSecretRef.key` (or rely on `secret.defaultName` and just set `key:`).

### GitHub Integration

Configure repository discovery via `api.env`:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `api.env.GITHUB_ORGANIZATIONS` | Comma-separated GitHub orgs to crawl | `""` |
| `api.env.GITHUB_REPOSITORIES` | Specific repos to include (org/repo) | `""` |
| `api.env.GITHUB_FORGE_ORGANIZATION` | Organization for Forge workflows | `""` |
| `api.env.GITHUB_RATE_LIMIT_PER_HOUR` | GitHub API rate limit budget | `1000` |

GitHub App IDs and installation IDs are plain values under `auth.github` (and `auth.github.forge` for the optional Forge App). Private keys are file-based credentials mounted via `extraVolumes` / `extraVolumeMounts`.

### Database (PostgreSQL)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `postgresql.enabled` | Deploy PostgreSQL StatefulSet | `true` |
| `postgresql.persistence.enabled` | Enable persistent storage | `true` |
| `postgresql.persistence.size` | PVC size | `20Gi` |
| `postgresql.external.enabled` | Use external PostgreSQL | `false` |
| `postgresql.external.host` | External host | `""` |

### Cache (Valkey)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `valkey.enabled` | Deploy Valkey StatefulSet | `true` |
| `valkey.persistence.enabled` | Enable persistent storage | `true` |
| `valkey.persistence.size` | PVC size | `5Gi` |
| `valkey.external.enabled` | Use external Redis/Valkey | `false` |

### Search (Meilisearch)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `meilisearch.enabled` | Deploy Meilisearch StatefulSet | `true` |
| `meilisearch.persistence.enabled` | Enable persistent storage | `true` |
| `meilisearch.persistence.size` | PVC size | `10Gi` |
| `meilisearch.external.enabled` | Use Meilisearch Cloud | `false` |

### Events (Redpanda)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `redpanda.enabled` | Deploy Redpanda StatefulSet | `true` |
| `redpanda.persistence.enabled` | Enable persistent storage | `true` |
| `redpanda.persistence.size` | PVC size | `20Gi` |
| `redpanda.external.enabled` | Use external Kafka/Redpanda | `false` |

## Multi-Tenant Architecture

Shoehorn uses PostgreSQL Row-Level Security (RLS) for database-level tenant isolation. This is always enabled. There is no toggle.

### How It Works

All database tables have RLS policies that filter data by `tenant_id`. Runtime services connect as `app_user` (NOBYPASSRLS) so PostgreSQL enforces tenant isolation automatically. Migrations run as `shoehorn_user` (BYPASSRLS) to manage schema.

### Database Users

| User | RLS | Purpose |
|------|-----|---------|
| `shoehorn_user` | BYPASSRLS | Schema migrations, admin operations |
| `app_user` | NOBYPASSRLS | All runtime queries. RLS enforced by PostgreSQL. |

### Required Secret Keys

Your secret must contain both database passwords:

- `postgres_password`: used by `shoehorn_user` for migrations
- `db_password`: used by `app_user` for runtime queries

For single-tenant deployments, RLS still runs but the middleware auto-injects a fixed tenant ID via the `global.organization.slug` configuration.

## Validation

The chart validates required configuration at template render time. If a required value is missing, `helm install` or `helm template` will fail with a clear error message:

```
Error: execution error at (shoehorn/templates/deployment-api.yaml:1:4):

postgresql.passwordSecretRef.name is required.

Set the Secret name on the ref directly, or set secret.defaultName
to a Secret containing all credentials.

See README.md for details.
```

Validated at render time:
- Every required `*SecretRef` resolves to a Secret name (either via its own `name:` or via `secret.defaultName`)
- Auth provider fields are set (`projectId`, `clientId`, etc. based on `auth.provider`)

## Upgrading

```bash
helm upgrade shoehorn oci://ghcr.io/shoehorn-dev/helm-charts/shoehorn \
  --namespace shoehorn \
  --values custom-values.yaml \
  --wait

# View release history
helm history shoehorn --namespace shoehorn

# Rollback if needed
helm rollback shoehorn 1 --namespace shoehorn
```

### PostgreSQL is decoupled from chart upgrades

The postgres StatefulSet uses `updateStrategy: OnDelete`. `helm upgrade` doesn't restart the postgres pod even when chart values bump platform images. Roll it explicitly when needed:

```bash
kubectl delete pod -n shoehorn shoehorn-postgresql-0
```

The StatefulSet recreates the pod against the current spec on the same PVC. This avoids data downtime on every platform release and prevents the schedule wedges that hit small clusters when postgres can't reserve its CPU during a multi-service rollout.

The postgres image tag is pinned in `values.yaml` (e.g. `v18.3-pgaudit-1.0`) and follows postgres releases, not platform releases. Bump it deliberately to upgrade the database.

## Uninstalling

The postgres StatefulSet carries `helm.sh/resource-policy: keep`. `helm uninstall` removes everything else but leaves the StatefulSet and its PVC standing, so a later reinstall reattaches the same data.

```bash
# Uninstall release (keeps PostgreSQL StatefulSet + PVC)
helm uninstall shoehorn --namespace shoehorn

# Drop the database explicitly (DESTROYS DATA)
kubectl delete sts -n shoehorn shoehorn-postgresql
kubectl delete pvc -n shoehorn data-shoehorn-postgresql-0

# Delete remaining PVCs (search index, cache, event log)
kubectl delete pvc -n shoehorn --all

# Delete namespace
kubectl delete namespace shoehorn
```

## Operational notes

### cert-manager bundling is unsupported

`certManager.install: true` exists in `values.yaml` but bundling cert-manager
as a sub-chart of this chart isn't reliable: Helm validates the chart's
`Certificate` and `ClusterIssuer` manifests against the API server before
applying them, and the cert-manager CRDs from the same release aren't
registered yet at validation time.

Install cert-manager out-of-band, then deploy this chart with
`certManager.install: false`:

```bash
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --version v1.20.0 --set crds.enabled=true --wait
```

### Use a namespaced `Issuer` on small clusters

`certManager.issuer.kind: ClusterIssuer` (the default) looks for the CA
secret in cert-manager's `clusterResourceNamespace` (default `cert-manager`),
not the release namespace. The chart creates the CA secret in the release
namespace, so the issuer will fail with `secrets "shoehorn-ca-secret" not found`.

Either configure cert-manager with `--cluster-resource-namespace=<release-ns>`,
or switch this chart to a namespaced Issuer:

```yaml
certManager:
  issuer:
    kind: Issuer
global:
  mtls:
    issuerKind: Issuer
```

### Cerbos mTLS requires `caCert`

When `global.mtls.enabled: true`, Cerbos requires a `caCert` path so it can
verify client certs. The chart wires this from `global.mtls.caFile`
automatically; no extra config needed. Note that this enables full mTLS: the
api and forge clients must present a valid client cert (the chart mounts the
shared `shoehorn-grpc-mtls-cert` secret).

### `redpanda.replicas: 3` needs 3+ nodes

The Redpanda StatefulSet uses pod anti-affinity, so each replica needs its
own node. On 1- or 2-node clusters the third replica stays `Pending`. Set
`redpanda.replicas: 1` for small clusters, or scale your node pool first.

## Troubleshooting

### Pods Not Starting

```bash
kubectl get pods -n shoehorn
kubectl logs -n shoehorn <pod-name>
kubectl describe pod -n shoehorn <pod-name>
```

### Secret Issues

```bash
# Verify secret exists
kubectl get secret shoehorn-credentials -n shoehorn

# Check which keys are present
kubectl get secret shoehorn-credentials -n shoehorn -o jsonpath='{.data}' | jq 'keys'
```

### Database Connection Issues

```bash
kubectl get pods -n shoehorn -l app.kubernetes.io/component=postgresql
kubectl logs -n shoehorn <postgresql-pod>
```

### Ingress Not Working

```bash
kubectl get ingress -n shoehorn
kubectl get ingressroute -n shoehorn
```

## Production Checklist

### Infrastructure
- [ ] Kubernetes cluster provisioned (1.24+) with at least 3 nodes if you want `redpanda.replicas: 3`
- [ ] Ingress controller installed (Traefik or Envoy)
- [ ] Storage class configured for PVCs
- [ ] DNS configured and pointing to ingress
- [ ] cert-manager installed in the cluster (out-of-band, see Operational notes)

### Secrets
- [ ] Kubernetes Secrets created for every required credential
- [ ] Every required `*SecretRef` resolves (per-ref `name:` or `secret.defaultName`)
- [ ] GitHub private keys mounted via `extraVolumes` (one per App: catalog and Forge)
- [ ] Auth provider credentials referenced (Zitadel PAT / Okta client secret + API token / Entra client secret)

### Configuration
- [ ] `global.domain` set to production domain
- [ ] `global.organization.slug` configured
- [ ] `auth.provider` configured with correct values
- [ ] RBAC role assignments configured
- [ ] Persistence enabled for all StatefulSets
- [ ] Resource limits sized for production workload (Cerbos especially, every authz check goes through it)
- [ ] Replica counts increased for HA
- [ ] Per-service `logLevel` set if you need anything other than `info`

### Security
- [ ] Secret contains separate `postgres_password` (migration user, BYPASSRLS) and `db_password` (app user, NOBYPASSRLS)
- [ ] `global.mtls.enabled: true` for inter-service gRPC (recommended)
- [ ] `certManager.issuer.kind: Issuer` if cert-manager's `clusterResourceNamespace` is the default
- [ ] Network policies configured (optional)

## Support

- **Documentation**: https://docs.shoehorn.dev
