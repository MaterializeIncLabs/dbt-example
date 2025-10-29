# CI/CD Setup Guide

Complete guide to setting up GitHub Actions for dbt + Materialize deployments.

## Overview

This project includes 5 GitHub Actions workflows:

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| **dbt CI** | Pull requests | Validate SQL compilation |
| **Deploy to QA** | Push to `main` | Auto-deploy to QA environment |
| **Blue/Green Production** | Release tags | Zero-downtime production deploy |
| **Cleanup** | Hourly schedule | Remove old deployment environments |
| **Generate dbt Docs** | Push to `main` | Create documentation artifacts |

## Prerequisites

### 1. Materialize Setup

You'll need a Materialize Cloud or self-managed instance with:

**Option A - Single Instance (Recommended):**
- One Materialize Cloud or self-managed environment
- Use namespacing for QA/Production separation

**Option B - Separate Instances:**
- Separate QA and Production environments
- Higher cost, better isolation

### 2. Create Clusters

Create the required clusters in Materialize:

```sql
-- QA Environment
CREATE CLUSTER qa_compute SIZE = 'xsmall', REPLICATION FACTOR = 1;
CREATE CLUSTER qa_sources SIZE = 'xsmall', REPLICATION FACTOR = 1;
CREATE CLUSTER qa_sinks SIZE = 'xsmall', REPLICATION FACTOR = 1;

-- Production Environment
CREATE CLUSTER production_compute SIZE = 'small', REPLICATION FACTOR = 2;
CREATE CLUSTER production_sources SIZE = 'small', REPLICATION FACTOR = 2;
CREATE CLUSTER production_sinks SIZE = 'small', REPLICATION FACTOR = 2;
```

### 3. Create Database

```sql
CREATE DATABASE auction_team;
```

## GitHub Configuration

### Step 1: Add Repository Secrets

Go to: **Settings > Secrets and variables > Actions**

Click "New repository secret" and add:

#### Shared Instance (Most Common):

```
MATERIALIZE_HOST
Value: your-instance.aws.materialize.cloud (or your self-managed host)

MATERIALIZE_PORT
Value: 6875

MATERIALIZE_USER
Value: your_user@example.com

MATERIALIZE_PASSWORD
Value: your_materialize_password
```

#### Separate Instances (Optional):

If you have separate QA and Production instances:

```
MATERIALIZE_QA_HOST
MATERIALIZE_QA_USER
MATERIALIZE_QA_PASSWORD

MATERIALIZE_PROD_HOST
MATERIALIZE_PROD_USER
MATERIALIZE_PROD_PASSWORD
```

The profiles-ci.yml automatically falls back to shared credentials if separate ones aren't provided.

### Step 2: Configure Environments

Go to: **Settings > Environments**

#### Create QA Environment:

1. Click "New environment"
2. Name: `qa`
3. No required reviewers needed (auto-deploy)
4. Save

#### Create Production Environment:

1. Click "New environment"
2. Name: `production`
3. **Enable "Required reviewers"**
4. Add team members who can approve production deployments
5. Optional: Add deployment branch rule (only `main` can deploy)
6. Save

### Step 3: Enable GitHub Actions

Go to: **Settings > Actions > General**

1. Ensure "Allow all actions and reusable workflows" is selected
2. Set workflow permissions to "Read and write permissions"
3. Enable "Allow GitHub Actions to create and approve pull requests" (for automated PRs)
4. Save

## Workflow Configuration

### dbt CI (Pull Request Validation)

**Triggers:** Pull requests to `main`

**What it does:**
- Parses dbt project
- Compiles all SQL models
- Validates refs and sources
- Uploads compiled SQL as artifacts

**No secrets required** - runs entirely offline.

### Deploy to QA (Auto-deployment)

**Triggers:** Push to `main` branch

**What it does:**
1. Connects to QA environment
2. Loads seed data
3. Runs all transformations
4. Executes dbt tests
5. Uploads test results

**Environment:** Uses `qa` GitHub Environment

### Blue/Green Production Deploy

**Triggers:**
- Release tags (v*.*.*)
- Manual workflow dispatch

**What it does:**
1. Creates green deployment environment
2. Deploys and tests on green
3. Waits for cluster hydration
4. **Requires manual approval**
5. Atomically promotes green to production
6. Retains blue for rollback (configurable)

**Environment:** Uses `production` GitHub Environment (requires approval)

**Configuration:**
- `retention_hours`: How long to keep old environment (default: 1)
- `skip_tests`: Skip tests (not recommended)

### Cleanup (Scheduled)

**Triggers:**
- Hourly schedule (cron: `0 * * * *`)
- Manual workflow dispatch

**What it does:**
- Checks for `_dbt_deploy` clusters in QA and Production
- Removes deployment environments based on retention policy
- Runs for both QA and Production in parallel

**Configuration:**
- `retention_hours`: Only cleanup older than X hours (default: 1)
- `dry_run`: Preview without deleting

### Generate dbt Docs

**Triggers:** Push to `main` branch

**What it does:**
- Generates dbt documentation
- Creates catalog with lineage DAG
- Uploads as workflow artifacts

**To view:**
1. Download artifacts from workflow run
2. Run: `dbt docs serve`

## Usage Examples

### Deploying to QA

**Automatic:**
```bash
git add .
git commit -m "Add new model"
git push origin main
# QA deployment starts automatically
```

**Manual:**
1. Go to: Actions → "Deploy to QA" → Run workflow
2. Select branch: `main`
3. Run workflow

### Deploying to Production

**Via Release (Recommended):**
```bash
# Create and push tag
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0

# Create GitHub release
gh release create v1.0.0 --generate-notes

# Or via GitHub UI:
# 1. Go to: Releases → Draft a new release
# 2. Choose tag: v1.0.0
# 3. Generate release notes
# 4. Publish release
```

**Manual Deployment:**
1. Go to: Actions → "Blue/Green Production Deployment"
2. Click "Run workflow"
3. Select branch: `main`
4. Set retention_hours: `1` (or custom)
5. Run workflow
6. **Wait for manual approval prompt**
7. Approve to complete deployment

### Manual Cleanup

**Preview what would be cleaned up:**
1. Go to: Actions → "Cleanup Old Deployment Environments"
2. Run workflow with:
   - `retention_hours`: 1
   - `dry_run`: true

**Force cleanup now:**
1. Go to: Actions → "Cleanup Old Deployment Environments"
2. Run workflow with:
   - `retention_hours`: 0
   - `dry_run`: false

## Monitoring Workflows

### View Workflow Status

Go to: **Actions** tab

- Green checkmark: Success
- Red X: Failure
- Yellow dot: In progress
- Gray dash: Skipped/cancelled

### Workflow Notifications

**Enable notifications:**
1. Click your profile → Settings
2. Notifications → Actions
3. Enable "Workflow runs" notifications

**Slack Integration (Optional):**

Add to workflow files:

```yaml
- name: Notify Slack
  if: always()
  uses: slackapi/slack-github-action@v1
  with:
    webhook: ${{ secrets.SLACK_WEBHOOK_URL }}
    payload: |
      {
        "text": "Deployment ${{ job.status }}: ${{ github.ref }}"
      }
```

Add `SLACK_WEBHOOK_URL` secret.

### View Deployment History

**For QA:**
- Go to: Environments → qa → Deployments

**For Production:**
- Go to: Environments → production → Deployments

Shows:
- Deployment timestamp
- Who triggered it
- Commit SHA
- Approval history

## Troubleshooting

### "Repository secret not found"

**Fix:**
1. Verify secret name matches exactly (case-sensitive)
2. Secrets must be at repository level, not environment level
3. Re-add the secret if needed

### "Environment protection rules not met"

**Fix:**
1. Add yourself as a required reviewer for `production` environment
2. Settings → Environments → production → Required reviewers

### Workflow fails on "Test connection"

**Fix:**
1. Verify Materialize credentials in secrets
2. Check host format: `instance-name.aws.materialize.cloud` (or your self-managed host)
3. Ensure clusters exist: `qa_compute`, `production_compute`
4. Verify database exists: `auction_team`

### "dbt deps" fails

**Fix:**
1. Check `packages.yml` syntax
2. Verify network connectivity (GitHub Actions can reach dbt packages)
3. Clear dbt cache: workflows automatically use fresh cache

### Blue/Green deployment stuck on approval

**Fix:**
1. Check if approver has notifications enabled
2. Manually review and approve in Actions tab
3. Or cancel and re-run

## Best Practices

### 1. Branch Protection Rules

Set up branch protection for `main`:

1. Go to: Settings → Branches → Add rule
2. Branch name pattern: `main`
3. Enable:
   - ✅ Require status checks to pass (select "dbt CI")
   - ✅ Require pull request reviews
   - ✅ Do not allow bypassing the above settings
4. Save

### 2. Required Reviewers

- **QA**: No approval needed (auto-deploy)
- **Production**: Require 1-2 reviewers

### 3. Deployment Timing

- **QA deployments**: Immediate on merge
- **Production deployments**: During business hours with team available
- **Emergency rollbacks**: Use `deploy_promote` to swap back

### 4. Retention Policy

- **Development/Testing**: `retention_hours: 0` (cleanup immediately)
- **Normal deployments**: `retention_hours: 1` (1 hour rollback window)
- **Critical changes**: `retention_hours: 24` (24 hour rollback window)

### 5. Monitoring

After deployment:
- Check workflow summary
- Monitor Materialize console
- Verify sink health
- Watch for alerts

## Cost Optimization

### Cluster Sizing for Blue/Green

**Important:** The green cluster becomes production after promotion, so:
- Green cluster should be the same size as blue (it becomes production)
- After swap, old blue cluster is retained for rollback (costs during retention period)
- Use `retention_hours` to control how long old cluster is kept

**Cost during blue/green deployment:**
- Normal operation: 1x production cluster cost
- During deployment: 2x production cluster cost (blue + green, ~15-30 min)
- After promotion: 2x production cluster cost (new production + retained blue, 1 hour by default)
- After cleanup: 1x production cluster cost

### Minimize Deployment Costs

1. **Optimize retention period:**
   - `retention_hours: 1` is usually sufficient (default)
   - Scheduled cleanup removes old clusters hourly
   - Use `retention_hours: 0` for non-critical deployments

2. **Run deployments during off-peak:**
   - Manual workflow dispatch for timing control
   - Avoid simultaneous QA + Production deployments

3. **Monitor cleanup workflow:**
   - Ensure scheduled cleanup is running
   - Manually cleanup if needed: `dbt run-operation deploy_cleanup`

### Workflow Execution Costs

GitHub Actions is free for public repos, but for private repos:

- CI validation: ~2-3 minutes (minimal cost)
- QA deployment: ~5-10 minutes
- Production deployment: ~15-30 minutes
- Cleanup: ~1-2 minutes

**Tip:** Use Ubuntu runners (fastest and cheapest).

## Additional Resources

- [Blue/Green Deployment Guide](./BLUE-GREEN-DEPLOYMENT.md)
- [Deployment Checklist](./DEPLOYMENT-CHECKLIST.md)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Materialize dbt Adapter](https://materialize.com/docs/manage/dbt/)
