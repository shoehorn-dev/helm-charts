# Shoehorn Helm Chart

Official Helm chart for deploying Shoehorn, an Internal Developer Portal, on Kubernetes.

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
| **Meilisearch** | StatefulSet | 7700 | Fast search engine |
| **Valkey** | StatefulSet | 6379 | Redis-compatible cache |
| **Redpanda** | StatefulSet | 9092 | Kafka-compatible event streaming |

## Quick Start

### 1. Create Namespace

```bash
kubectl create namespace shoehorn
```

### 2. Create Secret

Shoehorn uses a single Kubernetes Secret for all credentials. Create it using whichever tool you prefer -- `kubectl`, External Secrets Operator, Vault, Sealed Secrets, etc.

```bash
kubectl create secret generic shoehorn-credentials -n shoehorn \
  --from-literal=postgres_password="$(openssl rand -base64 24)" \
  --from-literal=db_password="$(openssl rand -base64 24)" \
  --from-literal=valkey_password="$(openssl rand -base64 24)" \
  --from-literal=meilisearch_master_key="$(openssl rand -hex 32)" \
  --from-literal=jwt_secret="$(openssl rand -hex 32)" \
  --from-literal=auth_encryption_key="$(openssl rand -base64 32)" \
  --from-literal=session_encryption_key="$(openssl rand -hex 32)" \
  --from-literal=github_app_id="YOUR_APP_ID" \
  --from-literal=github_app_installation_id="YOUR_INSTALLATION_ID" \
  --from-literal=github_webhook_secret="$(openssl rand -hex 32)" \
  --from-file=github_app_private_key=/path/to/private-key.pem
```

Then reference it in your values:

```yaml
secret:
  existingSecret: shoehorn-credentials
```

The chart maps environment variables to keys in your secret via `secret.mappings`. The defaults match the key names shown above. Override mappings if your secret uses different key names.

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

### 4. Create Registry Secret (for Private Images)

```bash
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=YOUR_GITHUB_USERNAME \
  --docker-password=YOUR_GITHUB_PAT \
  --docker-email=YOUR_EMAIL \
  --namespace shoehorn
```

### 5. Install Shoehorn

```bash
helm install shoehorn oci://ghcr.io/shoehorn-dev/helm-charts/shoehorn \
  --namespace shoehorn \
  --values custom-values.yaml \
  --wait
```

### 6. Access Shoehorn

```bash
# Get ingress address
kubectl get ingress -n shoehorn

# Or with Traefik IngressRoute
kubectl get ingressroute -n shoehorn
```

## Secret Management

### How It Works

1. You create a Kubernetes Secret containing all credentials (using any tool you prefer)
2. You set `secret.existingSecret` to the name of that secret
3. The chart reads keys from the secret using `secret.mappings`

```yaml
secret:
  existingSecret: shoehorn-credentials  # Name of your K8s secret
  mappings:
    # Maps env var names -> keys in your secret
    DB_PASSWORD: db_password
    VALKEY_PASSWORD: valkey_password
    MEILISEARCH_MASTER_KEY: meilisearch_master_key
    # ... see values.yaml for full list
```

### Supported Secret Providers

Any tool that creates a standard Kubernetes Secret works:

| Provider | How |
|----------|-----|
| **kubectl** | `kubectl create secret generic ...` |
| **External Secrets Operator** | `ExternalSecret` CR targeting your vault |
| **HashiCorp Vault** | Vault Agent Injector or ESO |
| **Sealed Secrets** | `SealedSecret` CR |
| **AWS Secrets Manager** | ESO with AWS provider |
| **Azure Key Vault** | ESO with Azure provider |
| **GCP Secret Manager** | ESO with GCP provider |

### Required Keys

| Key | Description | Used By |
|-----|-------------|---------|
| `postgres_password` | PostgreSQL admin password | API (migrations) |
| `db_password` | PostgreSQL app user password | All backend services |
| `valkey_password` | Valkey/Redis password | All backend services |
| `meilisearch_master_key` | Meilisearch API key | All backend services |
| `jwt_secret` | JWT signing secret | API |
| `auth_encryption_key` | Auth provider encryption key | API |
| `session_encryption_key` | Session cookie encryption | API |
| `github_app_id` | GitHub App ID | API, Crawler |
| `github_app_installation_id` | GitHub App installation ID | API, Crawler |
| `github_webhook_secret` | GitHub webhook signature secret | API |

### Optional Keys

Add these to your secret and `secret.mappings` as needed:

| Key | Description |
|-----|-------------|
| `github_app_private_key` | GitHub App private key (mount as file via `extraVolumes`) |
| `github_forge_app_id` | GitHub Forge App ID |
| `github_forge_installation_id` | GitHub Forge installation ID |
| `github_forge_private_key` | GitHub Forge private key (mount as file) |
| `service_user_pat` | Zitadel service user PAT (if using Zitadel) |
| `okta_client_secret` | Okta client secret (if using Okta) |
| `okta_api_token` | Okta API token (if using Okta orgdata sync) |
| `entra_client_secret` | Entra ID client secret (if using Entra ID) |
| `smtp_password` | SMTP password (if SMTP enabled) |
| `argocd_token` | ArgoCD API token (if using ArgoCD sync) |
| `upcloud_token` | UpCloud API token (if using cloud discovery) |

### Custom Key Names

If your secret uses different key names (e.g., from a vault), override the mappings:

```yaml
secret:
  existingSecret: my-vault-secret
  mappings:
    DB_PASSWORD: database/password     # Your vault's key name
    VALKEY_PASSWORD: redis/auth-token  # Different naming convention
```

## Configuration

### Minimal values.yaml

```yaml
global:
  domain: shoehorn.local
  organization:
    slug: my-org

secret:
  existingSecret: shoehorn-credentials

auth:
  provider: zitadel
  zitadel:
    projectId: "YOUR_PROJECT_ID"
    clientId: "YOUR_CLIENT_ID"
    externalUrl: "https://auth.yourdomain.xyz"

rbac:
  roleAssignment:
    tenantAdmin:
      user: "admin@example.com"

# Mount GitHub private key
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

```yaml
global:
  domain: shoehorn.example.com
  storageClass: fast-ssd
  organization:
    slug: acme-corp
    name: Acme Corporation

secret:
  existingSecret: shoehorn-credentials

ingressRoute:
  enabled: true
  tls:
    enabled: true
    certResolver: letsencrypt

auth:
  provider: zitadel
  zitadel:
    projectId: "YOUR_PROJECT_ID"
    clientId: "YOUR_CLIENT_ID"
    externalUrl: "https://auth.yourdomain.xyz"

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

# Persistence
postgresql:
  persistence:
    enabled: true
    size: 50Gi

meilisearch:
  persistence:
    enabled: true
    size: 100Gi

redpanda:
  persistence:
    enabled: true
    size: 200Gi

valkey:
  persistence:
    enabled: true
    size: 10Gi
```

## Key Configuration Parameters

### Global Settings

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.domain` | Main domain for the application | `shoehorn.example.com` |
| `global.environment` | Environment name (`production`, `staging`, `development`) | `production` |
| `global.logLevel` | Log level for all backend services | `info` |
| `global.storageClass` | Default storage class for PVCs | `""` |
| `global.organization.slug` | URL-safe organization identifier (required) | `""` |
| `global.organization.name` | Display name for organization | `""` |
| `global.imagePullSecrets` | List of registry secrets | `[]` |
| `global.tracing.enabled` | Enable OpenTelemetry distributed tracing | `false` |
| `global.mtls.enabled` | Enable mTLS for gRPC services | `false` |

### Secret Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `secret.existingSecret` | Name of existing K8s secret (required) | `""` |
| `secret.mappings` | Map of env var names to secret keys | See `values.yaml` |
| `extraVolumes` | Additional volumes for all backend pods | `[]` |
| `extraVolumeMounts` | Additional volume mounts for all backend pods | `[]` |

### Authentication

| Parameter | Description | Default |
|-----------|-------------|---------|
| `auth.provider` | Auth provider (`zitadel`, `okta`, `entra-id`) | `zitadel` |
| `auth.zitadel.projectId` | Zitadel project ID | `""` |
| `auth.zitadel.clientId` | Zitadel OIDC client ID | `""` |
| `auth.zitadel.externalUrl` | Zitadel instance URL | `""` |

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

When SMTP is enabled, add `SMTP_PASSWORD: smtp_password` to your `secret.mappings`.

### GitHub Integration

Configure repository discovery via `api.env`:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `api.env.GITHUB_ORGANIZATIONS` | Comma-separated GitHub orgs to crawl | `""` |
| `api.env.GITHUB_REPOSITORIES` | Specific repos to include (org/repo) | `""` |
| `api.env.GITHUB_FORGE_ORGANIZATION` | Organization for Forge workflows | `""` |
| `api.env.GITHUB_RATE_LIMIT_PER_HOUR` | GitHub API rate limit budget | `1000` |

GitHub App credentials (IDs, private keys) are configured via the secret and `extraVolumes`, not values.

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

Shoehorn uses PostgreSQL Row-Level Security (RLS) for database-level tenant isolation. This is always enabled -- there is no toggle.

### How It Works

All database tables have RLS policies that filter data by `tenant_id`. Runtime services connect as `app_user` (NOBYPASSRLS) so PostgreSQL enforces tenant isolation automatically. Migrations run as `shoehorn_user` (BYPASSRLS) to manage schema.

### Database Users

| User | RLS | Purpose |
|------|-----|---------|
| `shoehorn_user` | BYPASSRLS | Schema migrations, admin operations |
| `app_user` | NOBYPASSRLS | All runtime queries -- RLS enforced by PostgreSQL |

### Required Secret Keys

Your secret must contain both database passwords:

- `postgres_password`: used by `shoehorn_user` for migrations
- `db_password`: used by `app_user` for runtime queries

For single-tenant deployments, RLS still runs but the middleware auto-injects a fixed tenant ID via the `global.organization.slug` configuration.

## Validation

The chart validates required configuration at template render time. If a required value is missing, `helm install` or `helm template` will fail with a clear error message:

```
Error: execution error at (shoehorn/templates/deployment-api.yaml:1:4):

secret.existingSecret is required.

Create a Kubernetes Secret and set:
  secret:
    existingSecret: <your-secret-name>

See README.md for details.
```

Validated at render time:
- `secret.existingSecret` is set
- Auth provider fields are set (projectId, clientId, etc. based on `auth.provider`)

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

## Uninstalling

```bash
# Uninstall release (keeps PVCs)
helm uninstall shoehorn --namespace shoehorn

# Delete PVCs (WARNING: deletes all data!)
kubectl delete pvc -n shoehorn --all

# Delete namespace
kubectl delete namespace shoehorn
```

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
- [ ] Kubernetes cluster provisioned (1.24+)
- [ ] Ingress controller installed (Traefik or Envoy)
- [ ] Storage class configured for PVCs
- [ ] DNS configured and pointing to ingress
- [ ] TLS certificates configured

### Secrets
- [ ] Kubernetes Secret created with all required keys
- [ ] `secret.existingSecret` set in values
- [ ] GitHub private keys mounted via `extraVolumes`
- [ ] Auth provider credentials included (Zitadel PAT / Okta secret / Entra secret)

### Configuration
- [ ] `global.domain` set to production domain
- [ ] `global.organization.slug` configured
- [ ] `auth.provider` configured with correct values
- [ ] RBAC role assignments configured
- [ ] Persistence enabled for all StatefulSets
- [ ] Resource limits set for production workload
- [ ] Replica counts increased for HA

### Security
- [ ] Secret contains separate `postgres_password` and `db_password`
- [ ] Network policies configured (optional)
- [ ] gRPC mTLS enabled (optional)

## Support

- **Documentation**: https://docs.shoehorn.dev
