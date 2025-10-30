# Testing Guide

This document describes the test suite for the dbt Materialize auction house project, with a focus on blue/green deployment testing.

## Test Types

### 1. Workflow Validation Tests
**Location:** `scripts/test_workflows.sh`

Validates GitHub Actions workflow files for:
- YAML syntax correctness
- Required workflow structure (name, triggers, jobs)
- Blue/green deployment requirements
- Security best practices (no hardcoded credentials)
- Concurrency controls
- Error handling

**Run:**
```bash
./scripts/test_workflows.sh
# Or using Make
make test-workflows
```

**What it tests:**
- ✅ All workflow files have valid YAML syntax
- ✅ Single approval workflow has release trigger
- ✅ Single approval workflow has environment protection
- ✅ Two-stage workflow has two jobs with proper dependencies
- ✅ Two-stage workflow has both environment protections
- ✅ Artifact upload/download configured in two-stage workflow
- ✅ All workflows include required deployment steps
- ✅ Secrets are properly referenced
- ✅ No hardcoded credentials
- ✅ Concurrency controls prevent simultaneous deployments
- ✅ Failure and success handlers present

### 2. Blue/Green Deployment Integration Tests
**Location:** `scripts/test_blue_green_deployment.sh`

Tests the actual deployment macros against a local Materialize instance.

**Prerequisites:**
- Docker and docker-compose installed
- Materialize running locally (`make docker-up`)
- PostgreSQL client (`psql`) installed

**Run:**
```bash
# Start Docker environment first
make docker-up

# Run tests
./scripts/test_blue_green_deployment.sh
# Or using Make
make test-deployment
```

**What it tests:**

**Test 1: Deploy Init**
- ✅ `deploy_init` creates green cluster (`quickstart_dbt_deploy`)
- ✅ Green schemas are created with `_dbt_deploy` suffix

**Test 2: Deploy to Green**
- ✅ Models deploy successfully to green environment
- ✅ Deployment uses correct cluster and schemas

**Test 3: Cluster Hydration**
- ✅ `deploy_await` checks cluster lag
- ✅ Polling mechanism works correctly

**Test 4: Dry Run Promotion**
- ✅ `deploy_promote --dry_run` shows SQL commands
- ✅ Output contains ALTER/SWAP statements
- ✅ No actual changes made in dry run mode

**Test 5: Actual Promotion**
- ✅ `deploy_promote` executes atomic swap
- ✅ Blue and green clusters exchange roles
- ✅ Both environments exist after swap (rollback ready)

**Test 6: Rollback**
- ✅ Second `deploy_promote` swaps back successfully
- ✅ Rollback mechanism works as expected

**Test 7: Cleanup**
- ✅ `deploy_cleanup` removes old deployment environment
- ✅ Only deployment clusters/schemas are removed
- ✅ Production environment remains intact

**Test 8: Idempotency**
- ✅ `deploy_cleanup` on non-existent environment doesn't error
- ✅ Operations can be safely retried

### 3. dbt Data Quality Tests
**Location:** `models/**/*.yml` (test definitions)

Standard dbt tests for data quality:
- Not null constraints
- Unique values
- Referential integrity
- Accepted values
- Custom business logic tests

**Run:**
```bash
dbt test --profiles-dir . --profile materialize_auction_house --target dev
# Or using Make
make test-dbt
```

## Running Tests

### Quick Start

```bash
# Run all tests (workflows + deployment)
make test

# Run specific test suites
make test-workflows      # Workflow validation only
make test-deployment     # Deployment integration tests only
make test-dbt           # dbt data quality tests only
```

### Manual Test Execution

**Workflow tests (no Docker needed):**
```bash
./scripts/test_workflows.sh
```

**Deployment tests (requires Docker):**
```bash
# 1. Start environment
docker-compose up -d
./scripts/setup.sh

# 2. Run tests
./scripts/test_blue_green_deployment.sh

# 3. Clean up
docker-compose down
```

### CI/CD Integration

Tests run automatically on pull requests:

**`.github/workflows/test-deployments.yml`**
- Triggers on changes to workflow files or deployment scripts
- Runs workflow validation
- Runs blue/green deployment tests using GitHub Actions services
- Uses `actionlint` for additional workflow linting

**When tests run:**
- On PR to main affecting:
  - `.github/workflows/dbt-blue-green*.yml`
  - `scripts/test_*.sh`
  - `macros/deploy/**`
- Manual trigger via Actions UI

## Test Output

### Success
```
============================================
Test Summary
============================================
Tests run: 24
Passed: 24
Failed: 0

✅ All tests passed
```

### Failure
```
============================================
Test Summary
============================================
Tests run: 24
Passed: 22
Failed: 2

❌ Some tests failed
```

Tests will exit with code 1 on failure, failing CI checks.

## Adding New Tests

### Adding Workflow Validation Tests

Edit `scripts/test_workflows.sh`:

```bash
# Add new test
print_test "Testing new requirement..."
if grep -q "expected_pattern" "$workflow"; then
    print_pass "New requirement met"
else
    print_fail "New requirement missing"
fi
```

### Adding Deployment Integration Tests

Edit `scripts/test_blue_green_deployment.sh`:

```bash
print_header "Test 9: My New Test"
print_test "Testing new deployment behavior..."

# Your test logic here
if [test condition]; then
    print_pass "New behavior works"
else
    print_fail "New behavior failed"
fi
```

### Adding dbt Data Tests

Create test in model YAML file:

```yaml
# models/marts/_marts.yml
version: 2

models:
  - name: fct_auction_flippers
    tests:
      - dbt_utils.expression_is_true:
          expression: "total_flips > 0"
```

## Troubleshooting

### Workflow Tests Fail

**Issue:** YAML syntax errors
```bash
# Fix YAML syntax in workflow files
# Use YAML linter or IDE with YAML support
```

**Issue:** Missing required fields
```bash
# Check that workflows have:
# - name
# - on (triggers)
# - jobs
# - environment protection
```

### Deployment Tests Fail

**Issue:** Cannot connect to Materialize
```bash
# Ensure Docker is running
docker ps | grep materialize

# Start if not running
make docker-up
```

**Issue:** `deploy_await` times out
```bash
# This is acceptable in local testing
# Adjust timeout in test script or use lower lag threshold
```

**Issue:** Cluster already exists
```bash
# Clean up before testing
dbt run-operation deploy_cleanup --profiles-dir . --target dev
```

### Test Environment Issues

**Clean slate:**
```bash
make clean          # Remove all artifacts
make docker-down    # Stop containers
make docker-up      # Fresh start
make test          # Re-run tests
```

## Best Practices

1. **Run tests before committing**
   ```bash
   make test
   ```

2. **Test workflow changes locally**
   ```bash
   make test-workflows
   ```

3. **Validate deployment logic changes**
   ```bash
   make test-deployment
   ```

4. **Keep Docker environment fresh**
   ```bash
   make docker-down && make docker-up
   ```

5. **Review test output carefully**
   - All tests should pass
   - Pay attention to failure details
   - Fix issues before pushing

## Continuous Integration

### GitHub Actions

**Workflow:** `.github/workflows/test-deployments.yml`

**Jobs:**
1. **validate-workflows** - Validates workflow file structure
2. **test-deployment-integration** - Tests deployment macros
3. **actionlint** - Lints workflow files for best practices

**Artifacts:** None (tests don't produce artifacts)

**Notifications:** PR checks show pass/fail status

### Local Development

Before pushing:
```bash
# 1. Test workflows
make test-workflows

# 2. Test deployments (if changed deployment logic)
make docker-up
make test-deployment

# 3. Commit if all pass
git add .
git commit -m "Your changes"
git push
```

## Additional Resources

- [Blue/Green Deployment Guide](./BLUE-GREEN-DEPLOYMENT.md)
- [Deployment Checklist](./DEPLOYMENT-CHECKLIST.md)
- [CI/CD Setup](./CI-CD-SETUP.md)
- [dbt Testing](https://docs.getdbt.com/docs/build/tests)
- [Materialize Testing](https://materialize.com/docs/manage/dbt/)
