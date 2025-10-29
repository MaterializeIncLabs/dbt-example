# Blue/Green Deployment Guide

Zero-downtime deployments using native dbt-materialize macros.

## Quick Start

### Automated (GitHub Actions)

**Via Release:**
```bash
git tag v1.0.0
git push origin v1.0.0
gh release create v1.0.0
```

**Manual Trigger:**
- Go to: Actions → "Blue/Green Production Deployment" → Run workflow
- Set retention hours (default: 1 hour for rollback safety)

### Manual Deployment

```bash
# 1. Initialize green environment
dbt run-operation deploy_init --target production

# 2. Deploy to green
dbt run --selector transformations --vars 'deploy: True' --target production

# 3. Wait for hydration (ensures lag < 1s)
dbt run-operation deploy_await --args '{poll_interval: 15, lag_threshold: "1s"}' --target production

# 4. Test green environment (after hydration!)
dbt test --vars 'deploy: True' --target production

# 5. Dry run validation
dbt run-operation deploy_promote --args '{dry_run: true}' --target production

# 6. Promote (atomic swap)
dbt run-operation deploy_promote --args '{wait: true}' --target production

# 7. Cleanup (or wait for scheduled cleanup)
dbt run-operation deploy_cleanup --target production
```

## How It Works

```
Current State (Blue):
  production_compute → production_staging, production_intermediate, production_marts

Step 1 - deploy_init:
  Creates: production_compute_dbt_deploy → production_*_dbt_deploy schemas

Step 2 - Deploy & Test Green:
  production_compute_dbt_deploy is fully deployed and validated

Step 3 - deploy_promote (atomic swap):
  Blue becomes: production_compute_dbt_deploy (old production)
  Green becomes: production_compute (new production)
  Sinks automatically cutover to new materialized views

Result: Zero downtime, instant rollback capability
```

## Configuration

### Retention Period

Control how long the old blue environment is kept for rollback:

**In GitHub Actions:**
```yaml
# workflow_dispatch input
retention_hours: 1  # Default: 1 hour

# Set to 0 for immediate cleanup
retention_hours: 0

# Increase for longer rollback window
retention_hours: 24
```

**Scheduled Cleanup:**
- Runs hourly via `dbt-cleanup.yml` workflow
- Automatically removes deployment environments older than retention period
- Works for both QA and Production

### Environment Separation

**Single Materialize Cloud Instance:**
```
Database: auction_team

QA Environment:
  Clusters: qa_compute
  Schemas: qa_staging, qa_intermediate, qa_marts

Production Environment:
  Clusters: production_compute
  Schemas: production_staging, production_intermediate, production_marts
```

**What's NOT in Blue/Green:**
- Source clusters (data ingestion continues)
- Sink clusters (automatically cutover during promotion)

## Native dbt-Materialize Macros

| Macro | Purpose |
|-------|---------|
| `deploy_init` | Create green environment with `_dbt_deploy` suffix |
| `deploy_await` | Wait for cluster hydration (lag < 1s) |
| `deploy_promote` | Atomic swap blue ↔ green + sink cutover |
| `deploy_cleanup` | Remove old deployment environment |

## Rollback Procedures

### Before Promotion (Safe)

Production is unchanged. Simply cleanup:
```bash
dbt run-operation deploy_cleanup --target production
```

### After Promotion (Quick Rollback)

Old environment is retained as `production_compute_dbt_deploy`:
```bash
# Swap back to old version
dbt run-operation deploy_promote --target production

# This restores the previous working version
```

**Important:** Rollback is only available until `deploy_cleanup` removes the old environment.

## Troubleshooting

**Cluster not hydrated:**
- Wait longer - complex models take time
- Check `deploy_await` logs for lag status

**Tests failing on green:**
- Ensure you ran `deploy_await` before testing
- Check test details: `dbt test --vars 'deploy: True' --store-failures`

**Promotion fails:**
- `deploy_promote` is atomic - automatic rollback
- Safe to retry: `dbt run-operation deploy_promote --target production`
- Production remains on blue if promotion fails

**Manual cleanup needed:**
```bash
# Remove old deployment environments
dbt run-operation deploy_cleanup --target production
dbt run-operation deploy_cleanup --target qa
```

## Best Practices

1. ✅ **Always wait for hydration** before testing
   - `deploy_await` ensures lag < 1s
   - Tests on hydrating clusters give false results

2. ✅ **Use dry run** before promotion
   - `deploy_promote --args '{dry_run: true}'`
   - Preview exactly what will happen

3. ✅ **Retain old environment** for rollback
   - Default: 1 hour retention
   - Quick rollback if issues discovered
   - Automatic cleanup after retention period

4. ✅ **Test thoroughly** on green
   - Full dbt test suite
   - Custom validation queries
   - Compare with blue if needed

5. ✅ **Monitor after promotion**
   - Query performance
   - Sink health
   - Data quality metrics

## Additional Resources

- [Materialize Blue/Green Docs](https://materialize.com/docs/manage/dbt/blue-green-deployments/)
- [CI/CD Setup Guide](./CI-CD-SETUP.md)
- [Deployment Checklist](./DEPLOYMENT-CHECKLIST.md)
