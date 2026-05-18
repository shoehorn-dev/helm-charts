# PostgreSQL pgaudit

How pgaudit is wired into the Shoehorn Platform helm chart, what it logs, and how to run it against a managed Postgres.

## What pgaudit does

[pgaudit](https://github.com/pgaudit/pgaudit) is a PostgreSQL extension for session and object audit logging. We use it to satisfy SOC 2, HIPAA, and PCI DSS audit-trail requirements.

With the default `pgaudit.log = 'write,ddl,role'`:

- `write`: INSERT, UPDATE, DELETE, TRUNCATE, COPY FROM
- `ddl`: CREATE, ALTER, DROP
- `role`: GRANT, REVOKE, CREATE/ALTER/DROP ROLE

## Setup

### Option 1: Built-in image (default)

The chart ships a custom Postgres image with pgaudit compiled in. Base is `dhi.io/postgres:18-alpine3.23` (Docker Hardened Image) with pgaudit built from source against `postgresql18-dev`.

```yaml
# values.yaml defaults
postgresql:
  enabled: true
  image:
    repository: shoehorned/shoehorn-postgres
    tag: "v18.3-pgaudit-1.0"   # see values.yaml for source of truth
  pgaudit:
    enabled: true
```

`shared_preload_libraries = 'pgaudit'` is set unconditionally by `templates/configmap-postgresql.yaml`. Migration 091 creates the extension. Nothing else to configure.

### Option 2: Managed Postgres (RDS, Cloud SQL, Azure)

Use external Postgres instead of the in-cluster StatefulSet. The cloud provider enables pgaudit; the chart's `pgaudit` block still controls runtime settings the app expects.

```yaml
postgresql:
  enabled: false
  external:
    enabled: true
    host: "your-instance.example.com"
    port: 5432
    database: shoehorn
    user: shoehorn_user
  pgaudit:
    enabled: true   # controls pgaudit.log values the app sets at session level
```

#### AWS RDS

In the parameter group, set `shared_preload_libraries = 'pgaudit'`. Then in psql:

```sql
CREATE EXTENSION pgaudit;
SET pgaudit.log = 'write,ddl,role';
SET pgaudit.log_relation = on;
SET pgaudit.log_parameter = on;
```

#### Google Cloud SQL

```bash
gcloud sql instances patch INSTANCE_NAME \
  --database-flags=shared_preload_libraries=pgaudit,cloudsql_pgaudit.log=write:ddl:role
```

#### Azure Database for PostgreSQL

```bash
az postgres server configuration set \
  --resource-group myresourcegroup \
  --server-name myserver \
  --name shared_preload_libraries \
  --value pgaudit
```

## Chart values

```yaml
postgresql:
  pgaudit:
    enabled: true
    # Comma-separated classes:
    #   read     SELECT, COPY TO
    #   write    INSERT, UPDATE, DELETE, TRUNCATE, COPY FROM
    #   function Function calls and DO blocks
    #   role     GRANT, REVOKE, CREATE/ALTER/DROP ROLE
    #   ddl      All DDL not covered by `role`
    #   misc     DISCARD, FETCH, CHECKPOINT, VACUUM, SET, etc.
    log: "write,ddl,role"
    logCatalog: false    # exclude system catalog queries
    logRelation: true    # include table/relation names
    logParameter: true   # include statement parameters
```

To disable logging while keeping the extension loaded (still required by migration 091):

```yaml
postgresql:
  pgaudit:
    enabled: false
```

This sets `pgaudit.log = 'none'`. The shared library stays preloaded.

## Log format

pgaudit writes to the regular PostgreSQL log destination (stderr in container deployments). Each entry has an `AUDIT:` prefix:

```
2026-01-19 10:30:45.123 UTC [12345] [shoehorn] [shoehorn_user] [API] AUDIT: SESSION,2,1,WRITE,INSERT,TABLE,public.user_roles,"INSERT INTO user_roles (user_id, role_name, tenant_id) VALUES ($1, $2, $3)",<tenant_id=abc123>
```

Fields:

- `SESSION`: audit type (always SESSION for our config)
- `2`: statement ID
- `1`: substatement ID
- `WRITE`: class
- `INSERT`: command
- `TABLE`: object type
- `public.user_roles`: object name
- The SQL statement
- `<tenant_id=...>`: RLS context captured by the app

## Querying audit logs

pgaudit writes to Postgres' log destination, not a SQL table. Querying depends on where you ship those logs (Loki, ELK, CloudWatch, Datadog, etc.). The examples below assume logs have been ingested into a log store with `message`, `timestamp`, and `user` fields.

Find all role changes in the last 24 hours:

```
message:"AUDIT:" AND message:"GRANT" AND timestamp:[now-24h TO now]
```

Find deletes against a specific table:

```
message:"AUDIT:" AND message:"DELETE" AND message:"FROM sensitive_table"
```

Track all operations by a user:

```
message:"AUDIT:" AND user:"admin@example.com"
```

## Troubleshooting

**No audit lines in logs:**

1. Extension loaded: `SELECT extname, extversion FROM pg_extension WHERE extname = 'pgaudit';`
2. Preload set: `SHOW shared_preload_libraries;` (must include `pgaudit`)
3. Logging active: `SHOW pgaudit.log;` (should be `write,ddl,role`, not `none`)

**Too much noise:**

```yaml
postgresql:
  pgaudit:
    log: "role"
    logCatalog: false
```

## Compliance mappings

### SOC 2 Type II

- CC6.1: logs changes to production data
- CC6.2: logs privileged operations
- CC6.3: tamper-evident audit trail

### HIPAA

- §164.312(b): audit controls for PHI access
- §164.308(a)(1)(ii)(D): information system activity review

### PCI DSS

- Requirement 10: logs access to cardholder data
- 10.2.2: actions by privileged users
- 10.2.4: invalid access attempts

## References

- [pgaudit GitHub](https://github.com/pgaudit/pgaudit)
- [PostgreSQL runtime logging](https://www.postgresql.org/docs/current/runtime-config-logging.html)
- [AWS RDS pgaudit guide](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Appendix.PostgreSQL.CommonDBATasks.Extensions.html#Appendix.PostgreSQL.CommonDBATasks.pgaudit)
