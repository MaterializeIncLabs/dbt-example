# Blue/Green Deployment Guide

Zero-downtime deployments using native dbt-materialize macros.

## Workflow Options

This project provides two GitHub Actions workflows for production deployment:

### 1. Single Approval (Default) - `dbt-blue-green.yml`
**Best for:** Fast deployments, trusted CI/CD pipeline, experienced teams

- **Approval timing:** Before any steps run
- **Runs:** Automatically through all 7 steps once approved
- **Triggered by:** GitHub releases (automatic) or manual workflow dispatch
- **Use when:** Your CI tests are comprehensive and you trust the automated validation

**Flow:**
```
[Approve] → Build Green → Test → Validate → Promote → Complete
           └─────────── All automatic ──────────────┘
```

### 2. Two-Stage Approval - `dbt-blue-green-two-stage.yml`
**Best for:** Critical deployments, extra caution, regulatory requirements

- **First approval:** Before building green environment
- **Second approval:** After tests pass, before promotion (you review test results first)
- **Triggered by:** Manual workflow dispatch only
- **Use when:** You want to manually verify test results and dry run output before promoting

**Flow:**
```
[Approve Stage 1] → Build Green → Test → Validate → [Review & Approve Stage 2] → Promote → Complete
                   └──────── Stage 1 ────────────┘                              └─ Stage 2 ─┘
```

## Quick Start

### Automated (GitHub Actions)

**Via Release (Single Approval):**
```bash
git tag v1.0.0
git push origin v1.0.0
gh release create v1.0.0
# Uses dbt-blue-green.yml - one approval at start
```

**Manual Trigger (Choose Workflow):**
- Go to: Actions → Choose workflow:
  - "Blue/Green Production Deployment (Single Approval)" - Fast, one approval
  - "Blue/Green Production Deployment (Two-Stage Approval)" - Extra caution, two approvals
- Click "Run workflow"
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

### GitHub Environment Protection

Both workflows require GitHub environment protection to be configured:

**Single Approval Workflow:**
- Environment: `production`
- Required reviewers: Set in Settings → Environments → production

**Two-Stage Approval Workflow:**
- Environment 1: `production-deploy` (approves building green)
- Environment 2: `production-promote` (approves promotion after reviewing test results)
- Configure both in Settings → Environments with appropriate reviewers

**To set up:**
1. Go to Settings → Environments → New environment
2. Add required reviewers (users or teams who can approve deployments)
3. (Optional) Set wait timer for additional safety delay
4. (Optional) Restrict to specific branches (e.g., `main` only)

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

1. ✅ **Choose the right workflow**
   - **Single approval:** Regular deployments, strong CI pipeline, off-hours deploys
   - **Two-stage approval:** Critical changes, peak hours, schema migrations, new team members
   - Use releases for single approval (automatic trigger)
   - Use manual dispatch for two-stage approval

2. ✅ **Always wait for hydration** before testing
   - `deploy_await` ensures lag < 1s
   - Tests on hydrating clusters give false results

3. ✅ **Use dry run** before promotion
   - `deploy_promote --args '{dry_run: true}'`
   - Preview exactly what will happen
   - Two-stage workflow shows this automatically before second approval

4. ✅ **Retain old environment** for rollback
   - Default: 1 hour retention
   - Quick rollback if issues discovered
   - Automatic cleanup after retention period
   - Increase retention for critical deployments (24+ hours)

5. ✅ **Test thoroughly** on green
   - Full dbt test suite
   - Custom validation queries
   - Compare with blue if needed
   - Two-stage workflow lets you review results before promoting

6. ✅ **Monitor after promotion**
   - Query performance
   - Sink health
   - Data quality metrics

## Additional Resources

- [Materialize Blue/Green Docs](https://materialize.com/docs/manage/dbt/blue-green-deployments/)
- [CI/CD Setup Guide](./CI-CD-SETUP.md)
- [Deployment Checklist](./DEPLOYMENT-CHECKLIST.md)
