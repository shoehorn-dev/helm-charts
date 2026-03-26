# PostgreSQL - PgAudit

This document explains how pgaudit is used in the Shoehorn Platform

## What is pgaudit?

`pgaudit` is a PostgreSQL extension that provides detailed session and object audit logging for compliance requirements (SOC 2, HIPAA, PCI DSS, etc.).

- **Official Repository**: https://github.com/pgaudit/pgaudit
- **Documentation**: https://github.com/pgaudit/pgaudit/blob/master/README.md

## What Gets Logged

With our default configuration (`pgaudit.log = 'write,ddl,role'`):

- **write**: INSERT, UPDATE, DELETE operations
- **ddl**: CREATE, ALTER, DROP statements
- **role**: GRANT, REVOKE, role assignments

## Production Setup Options

### Option 1: Use Our Custom Image (Default - Recommended)

**This is what we ship.** The Helm chart uses our custom PostgreSQL image with pgaudit pre-installed by default:

```yaml
# values.yaml (default configuration)
postgresql:
  enabled: true
  image:
    repository: ghcr.io/shoehorn-dev/shoehorn-postgres
    tag: "latest"
  pgaudit:
    enabled: true
```

**No additional configuration needed** - pgaudit works out of the box.

### Option 2: Managed PostgreSQL Services (Alternative)

**Use this if you want managed PostgreSQL** (RDS, Cloud SQL, Azure Database) instead of running PostgreSQL in your cluster.

Most managed PostgreSQL services support pgaudit:

#### AWS RDS PostgreSQL

```sql
-- Enable pgaudit in RDS parameter group
-- Set: shared_preload_libraries = 'pgaudit'

-- In psql:
CREATE EXTENSION pgaudit;

-- Configure (via parameter group or session):
SET pgaudit.log = 'write,ddl,role';
SET pgaudit.log_relation = on;
SET pgaudit.log_parameter = on;
```

Helm configuration:
```yaml
postgresql:
  enabled: false  # Don't deploy PostgreSQL StatefulSet
  external:
    enabled: true
    host: "your-rds-endpoint.rds.amazonaws.com"
    port: 5432
    database: shoehorn
    user: shoehorn_user
  pgaudit:
    enabled: true  # Config for application awareness
```

#### Google Cloud SQL for PostgreSQL

```bash
# Enable pgaudit via Cloud SQL flags
gcloud sql instances patch INSTANCE_NAME \
  --database-flags=shared_preload_libraries=pgaudit,cloudsql_pgaudit.log=write:ddl:role
```

#### Azure Database for PostgreSQL

```bash
# Enable via Azure Portal or CLI
az postgres server configuration set \
  --resource-group myresourcegroup \
  --server-name myserver \
  --name shared_preload_libraries \
  --value pgaudit
```

## Helm Chart Configuration

### Full pgaudit Configuration

```yaml
postgresql:
  pgaudit:
    enabled: true
    # What to audit (comma-separated):
    # - read: SELECT, COPY TO
    # - write: INSERT, UPDATE, DELETE, TRUNCATE, COPY FROM
    # - function: Function calls and DO blocks
    # - role: GRANT, REVOKE, CREATE/ALTER/DROP ROLE
    # - ddl: All DDL not included in ROLE
    # - misc: DISCARD, FETCH, CHECKPOINT, VACUUM, SET, etc.
    log: "write,ddl,role"

    # Exclude system catalog queries (reduces noise)
    logCatalog: false

    # Include table/relation names in audit logs
    logRelation: true

    # Include statement parameters in audit logs
    logParameter: true
```

### Disable pgaudit

If you don't need audit logging:

```yaml
postgresql:
  pgaudit:
    enabled: false
```

The ConfigMap and volume mounts won't be created.

## Log Format

Audit logs are written to PostgreSQL logs with `AUDIT:` prefix:

```
2026-01-19 10:30:45.123 UTC [12345] [shoehorn] [shoehorn_user] [API] AUDIT: SESSION,2,1,WRITE,INSERT,TABLE,public.user_roles,"INSERT INTO user_roles (user_id, role_name, tenant_id) VALUES ($1, $2, $3)",<tenant_id=abc123>
```

### Log Fields

- `SESSION`: Session audit logging (default)
- `2`: Statement ID
- `1`: Substatement ID
- `WRITE`: Audit class
- `INSERT`: Command
- `TABLE`: Object type
- `public.user_roles`: Object name
- `"INSERT INTO..."`: SQL statement
- `<tenant_id=abc123>`: RLS context (automatically captured)

## Querying Audit Logs

### Example: Find all role assignments in last 24 hours

```sql
-- In PostgreSQL logs or log aggregation system
SELECT * FROM logs
WHERE message LIKE '%AUDIT:%'
  AND message LIKE '%GRANT%'
  AND timestamp > NOW() - INTERVAL '24 hours';
```

### Example: Find who deleted data

```sql
SELECT * FROM logs
WHERE message LIKE '%AUDIT:%'
  AND message LIKE '%DELETE%'
  AND message LIKE '%FROM sensitive_table%';
```

### Example: Track all operations by specific user

```sql
SELECT * FROM logs
WHERE message LIKE '%AUDIT:%'
  AND user = 'admin@company.com';
```

### Logs not appearing

**Check**:
1. Extension enabled: `SELECT * FROM pg_extension WHERE extname = 'pgaudit';`
2. Configuration loaded: `SHOW shared_preload_libraries;` (should include `pgaudit`)
3. Settings active: `SHOW pgaudit.log;` (should show `write,ddl,role`)

### Too many logs

**Reduce noise**:
```yaml
postgresql:
  pgaudit:
    log: "role"  # Only audit GRANT/REVOKE
    logCatalog: false  # Exclude system queries
```

## Compliance Mappings

### SOC 2 Type II

- **CC6.1**: pgaudit logs all changes to production data
- **CC6.2**: pgaudit logs all privileged operations
- **CC6.3**: pgaudit provides tamper-evident audit trail

### HIPAA

- **§164.312(b)**: Audit controls - pgaudit tracks all PHI access
- **§164.308(a)(1)(ii)(D)**: Information system activity review

### PCI DSS

- **Requirement 10**: pgaudit logs all access to cardholder data
- **10.2.2**: Logs all actions by privileged users
- **10.2.4**: Logs invalid access attempts

## Resources

- [pgaudit GitHub](https://github.com/pgaudit/pgaudit)
- [PostgreSQL Audit Logging](https://www.postgresql.org/docs/current/runtime-config-logging.html)
- [AWS RDS pgaudit](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Appendix.PostgreSQL.CommonDBATasks.Extensions.html#Appendix.PostgreSQL.CommonDBATasks.pgaudit)
