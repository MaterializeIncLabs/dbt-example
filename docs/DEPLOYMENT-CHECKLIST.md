# Deployment Checklist

Quick reference checklist for dbt + Materialize deployments.

## Pre-Deployment

### Code Quality
- [ ] All tests passing locally: `dbt test --target dev`
- [ ] Models compile successfully: `dbt compile --target dev`
- [ ] No SQL syntax errors
- [ ] Pull request reviewed and approved
- [ ] CI workflow passed (green checkmark)

### Documentation
- [ ] New models documented in schema.yml
- [ ] Complex logic explained in model SQL or docs
- [ ] CHANGELOG updated (if applicable)
- [ ] Migration notes added (if schema changes)

### Testing
- [ ] Unit tests added for new business logic
- [ ] Data quality tests added for new columns
- [ ] Edge cases covered
- [ ] Test locally against dev environment

## QA Deployment

### Pre-Deploy
- [ ] Merged to `main` branch
- [ ] GitHub Actions "Deploy to QA" workflow triggered
- [ ] Workflow shows "in progress" status

### During Deploy
- [ ] Monitor workflow progress in Actions tab
- [ ] Check for any error messages
- [ ] Verify seed data loaded successfully
- [ ] Confirm models deployed without errors

### Post-Deploy Validation
- [ ] All tests passed in QA
- [ ] Query new models manually in QA:
  ```sql
  -- Connect to QA database
  SELECT * FROM qa_marts.fct_auction_flippers LIMIT 10;
  ```
- [ ] Check row counts match expectations
- [ ] Verify data freshness (recent timestamps)
- [ ] Test downstream dependencies

### QA Sign-off
- [ ] Stakeholders notified
- [ ] Business users validated results
- [ ] Performance acceptable
- [ ] Ready for production

## Production Deployment

### Pre-Deploy
- [ ] QA validation complete
- [ ] Change window scheduled (if required)
- [ ] Team notified of deployment
- [ ] Rollback plan documented
- [ ] On-call engineer available

### Release Preparation
- [ ] Version number decided (semver)
- [ ] Release notes drafted
- [ ] Git tag created: `git tag -a v1.0.0 -m "Release v1.0.0"`
- [ ] Tag pushed: `git push origin v1.0.0`

### Initiate Deployment
- [ ] GitHub release created
- [ ] "Blue/Green Production Deployment" workflow triggered
- [ ] `retention_hours` configured (default: 1, critical changes: 24)
- [ ] Workflow waiting for approval

### Review Before Approval
- [ ] Green environment initialized successfully
- [ ] Models deployed to green without errors
- [ ] Cluster hydration complete (lag < 1s)
- [ ] All tests passed on green
- [ ] Dry run validation shows expected changes

### Approval
- [ ] Reviewer assigned and notified
- [ ] Deployment approved in GitHub Actions
- [ ] Promotion completed successfully
- [ ] Old blue environment retained for rollback

### Post-Deploy Validation

#### Immediate (0-5 minutes)
- [ ] Workflow completed successfully
- [ ] Check deployment summary in GitHub
- [ ] Verify active cluster: `production_compute`
- [ ] Query production to confirm changes:
  ```sql
  -- Connect to production database
  SELECT * FROM production_marts.fct_auction_flippers LIMIT 10;
  ```
- [ ] Check sink health (if applicable):
  ```sql
  SELECT name, type, error
  FROM mz_internal.mz_sink_statistics
  WHERE error IS NOT NULL;
  ```

#### Short-term (5-30 minutes)
- [ ] Monitor query performance
- [ ] Check error rates in logs
- [ ] Verify materialized view refresh rates
- [ ] Test critical user workflows
- [ ] Monitor cluster resource usage

#### Medium-term (1-2 hours)
- [ ] No user-reported issues
- [ ] Performance metrics stable
- [ ] Data quality maintained
- [ ] Downstream systems healthy

### Rollback (If Needed)
- [ ] Issues identified and documented
- [ ] Decision to rollback approved
- [ ] Run rollback command:
  ```bash
  dbt run-operation deploy_promote --target production
  ```
- [ ] Verify old version restored
- [ ] Confirm issues resolved
- [ ] Post-mortem scheduled

### Cleanup
- [ ] Old blue environment retained for configured duration
- [ ] Scheduled cleanup will run after retention period
- [ ] Or manual cleanup if retention_hours was 0:
  ```bash
  dbt run-operation deploy_cleanup --target production
  ```

## Post-Deployment

### Communication
- [ ] Deployment notification sent to team
- [ ] Stakeholders informed of changes
- [ ] Documentation updated (if needed)
- [ ] Release notes published

### Monitoring
- [ ] Set up alerts for new models (if applicable)
- [ ] Monitor for first 24 hours
- [ ] Review query performance trends
- [ ] Check for data quality issues

### Documentation
- [ ] Deployment logged in tracking system
- [ ] Any issues documented
- [ ] Lessons learned captured
- [ ] Update runbooks if needed

## Emergency Rollback Checklist

### If Issues Discovered Post-Deployment

- [ ] Severity assessment (critical/high/medium/low)
- [ ] Impact analysis (users affected, data accuracy)
- [ ] Decision: Fix forward vs. rollback

### Rollback Procedure
- [ ] Verify old environment still exists: `production_compute_dbt_deploy`
- [ ] Run rollback:
  ```bash
  dbt run-operation deploy_promote \
    --profiles-dir . \
    --profile materialize_auction_house \
    --target production
  ```
- [ ] Verify rollback successful
- [ ] Test critical workflows
- [ ] Notify team of rollback
- [ ] Schedule fix and redeployment

## Troubleshooting

### Deployment Fails at Hydration
**Symptoms:** `deploy_await` times out or lag remains high

**Actions:**
- [ ] Check cluster size (may need larger for faster hydration)
- [ ] Verify source data is flowing
- [ ] Check for resource constraints
- [ ] Review model complexity

### Tests Fail on Green
**Symptoms:** dbt tests fail during green validation

**Actions:**
- [ ] Review test failure details in workflow logs
- [ ] Query failed test in Materialize:
  ```sql
  SELECT * FROM production_staging_dbt_deploy.dbt_test__<test_name>;
  ```
- [ ] Fix issues and redeploy
- [ ] Run cleanup: `dbt run-operation deploy_cleanup --target production`

### Promotion Fails
**Symptoms:** `deploy_promote` returns error

**Actions:**
- [ ] Check error message in workflow logs
- [ ] Verify no concurrent modifications
- [ ] Retry promotion (safe to retry, operation is atomic)
- [ ] If still failing, run cleanup and restart deployment

### Cleanup Doesn't Run
**Symptoms:** Old `_dbt_deploy` clusters remain

**Actions:**
- [ ] Check scheduled cleanup workflow status
- [ ] Manually trigger cleanup workflow
- [ ] Or run manually:
  ```bash
  dbt run-operation deploy_cleanup --target production
  ```

## Quick Reference Commands

```bash
# Test locally
dbt test --profiles-dir . --profile materialize_auction_house --target dev

# Deploy to QA manually
dbt run --selector transformations --profiles-dir . --target qa
dbt test --profiles-dir . --target qa

# Blue/Green Production Deploy
dbt run-operation deploy_init --profiles-dir . --target production
dbt run --selector transformations --vars 'deploy: True' --profiles-dir . --target production
dbt run-operation deploy_await --args '{poll_interval: 15, lag_threshold: "1s"}' --profiles-dir . --target production
dbt test --vars 'deploy: True' --profiles-dir . --target production
dbt run-operation deploy_promote --args '{dry_run: true}' --profiles-dir . --target production
dbt run-operation deploy_promote --args '{wait: true}' --profiles-dir . --target production

# Rollback
dbt run-operation deploy_promote --profiles-dir . --target production

# Cleanup
dbt run-operation deploy_cleanup --profiles-dir . --target production
```

## Additional Resources

- [Blue/Green Deployment Guide](./BLUE-GREEN-DEPLOYMENT.md)
- [CI/CD Setup Instructions](./CI-CD-SETUP.md)
- [Project README](../README.md)
