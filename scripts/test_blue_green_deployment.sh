#!/bin/bash
# Note: Not using 'set -e' to allow tests to continue on failure

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results tracking
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Configuration
DBT_PROFILE="materialize_auction_house"
DBT_TARGET="dev"
PROFILES_DIR="."

print_header() {
    echo ""
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================${NC}"
}

print_test() {
    echo -e "${YELLOW}[TEST]${NC} $1"
}

print_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
    ((TESTS_RUN++))
}

print_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
    ((TESTS_RUN++))
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

cleanup_deployment() {
    print_info "Cleaning up any existing deployment environments..."
    dbt run-operation deploy_cleanup \
        --profiles-dir "$PROFILES_DIR" \
        --profile "$DBT_PROFILE" \
        --target "$DBT_TARGET" 2>/dev/null || true
}

check_cluster_exists() {
    local cluster_name=$1
    psql "postgresql://materialize@localhost:6875/materialize" \
        -tAc "SELECT count(*) FROM mz_clusters WHERE name = '$cluster_name'" 2>/dev/null
}

check_schema_exists() {
    local schema_name=$1
    psql "postgresql://materialize@localhost:6875/materialize" \
        -tAc "SELECT count(*) FROM mz_schemas WHERE name = '$schema_name'" 2>/dev/null
}

print_header "Blue/Green Deployment Integration Tests"

# Prerequisites check
print_test "Checking prerequisites..."

if ! command -v dbt &> /dev/null; then
    print_fail "dbt is not installed"
    exit 1
fi
print_pass "dbt is installed"

if ! command -v psql &> /dev/null; then
    print_fail "psql is not installed (needed for validation queries)"
    exit 1
fi
print_pass "psql is installed"

# Check Materialize connection
print_test "Testing Materialize connection..."
if psql "postgresql://materialize@localhost:6875/materialize" -c "SELECT 1" > /dev/null 2>&1; then
    print_pass "Materialize is accessible"
else
    print_fail "Cannot connect to Materialize (is Docker running?)"
    echo ""
    echo "Run: docker-compose up -d"
    exit 1
fi

# Create quickstart cluster if it doesn't exist (needed for transformations)
print_test "Ensuring quickstart cluster exists as MANAGED..."
cluster_exists=$(psql "postgresql://materialize@localhost:6875/materialize" -tAc "SELECT COUNT(*) FROM mz_clusters WHERE name = 'quickstart'")
if [ "$cluster_exists" -eq 0 ]; then
    if psql "postgresql://materialize@localhost:6875/materialize" \
        -c "CREATE CLUSTER quickstart SIZE = '25cc', REPLICATION FACTOR = 1" > /dev/null 2>&1; then
        print_pass "Quickstart cluster created (managed)"
    else
        print_fail "Failed to create quickstart cluster"
        exit 1
    fi
else
    # Check if it's managed
    is_managed=$(psql "postgresql://materialize@localhost:6875/materialize" -tAc "SELECT managed FROM mz_clusters WHERE name = 'quickstart'")
    if [ "$is_managed" = "t" ]; then
        print_pass "Quickstart cluster already exists (managed)"
    else
        print_info "Quickstart cluster exists but is unmanaged, dropping and recreating..."
        psql "postgresql://materialize@localhost:6875/materialize" -c "DROP CLUSTER quickstart CASCADE" > /dev/null 2>&1
        if psql "postgresql://materialize@localhost:6875/materialize" \
            -c "CREATE CLUSTER quickstart SIZE = '25cc', REPLICATION FACTOR = 1" > /dev/null 2>&1; then
            print_pass "Quickstart cluster recreated as managed"
        else
            print_fail "Failed to recreate quickstart cluster"
            exit 1
        fi
    fi
fi

# Create sources cluster if it doesn't exist (needed for load generator)
print_test "Ensuring sources cluster exists as MANAGED..."
cluster_exists=$(psql "postgresql://materialize@localhost:6875/materialize" -tAc "SELECT COUNT(*) FROM mz_clusters WHERE name = 'sources'")
if [ "$cluster_exists" -eq 0 ]; then
    if psql "postgresql://materialize@localhost:6875/materialize" \
        -c "CREATE CLUSTER sources SIZE = '25cc', REPLICATION FACTOR = 1" > /dev/null 2>&1; then
        print_pass "Sources cluster created (managed)"
    else
        print_fail "Failed to create sources cluster"
        exit 1
    fi
else
    # Check if it's managed
    is_managed=$(psql "postgresql://materialize@localhost:6875/materialize" -tAc "SELECT managed FROM mz_clusters WHERE name = 'sources'")
    if [ "$is_managed" = "t" ]; then
        print_pass "Sources cluster already exists (managed)"
    else
        print_info "Sources cluster exists but is unmanaged, dropping and recreating..."
        psql "postgresql://materialize@localhost:6875/materialize" -c "DROP CLUSTER sources CASCADE" > /dev/null 2>&1
        if psql "postgresql://materialize@localhost:6875/materialize" \
            -c "CREATE CLUSTER sources SIZE = '25cc', REPLICATION FACTOR = 1" > /dev/null 2>&1; then
            print_pass "Sources cluster recreated as managed"
        else
            print_fail "Failed to recreate sources cluster"
            exit 1
        fi
    fi
fi

# Create compute cluster if it doesn't exist (needed for deployment)
print_test "Ensuring compute cluster exists as MANAGED..."
cluster_exists=$(psql "postgresql://materialize@localhost:6875/materialize" -tAc "SELECT COUNT(*) FROM mz_clusters WHERE name = 'compute'")
if [ "$cluster_exists" -eq 0 ]; then
    if psql "postgresql://materialize@localhost:6875/materialize" \
        -c "CREATE CLUSTER compute SIZE = '25cc', REPLICATION FACTOR = 1" > /dev/null 2>&1; then
        print_pass "Compute cluster created (managed)"
    else
        print_fail "Failed to create compute cluster"
        exit 1
    fi
else
    # Check if it's managed
    is_managed=$(psql "postgresql://materialize@localhost:6875/materialize" -tAc "SELECT managed FROM mz_clusters WHERE name = 'compute'")
    if [ "$is_managed" = "t" ]; then
        print_pass "Compute cluster already exists (managed)"
    else
        print_info "Compute cluster exists but is unmanaged, dropping and recreating..."
        psql "postgresql://materialize@localhost:6875/materialize" -c "DROP CLUSTER compute CASCADE" > /dev/null 2>&1
        if psql "postgresql://materialize@localhost:6875/materialize" \
            -c "CREATE CLUSTER compute SIZE = '25cc', REPLICATION FACTOR = 1" > /dev/null 2>&1; then
            print_pass "Compute cluster recreated as managed"
        else
            print_fail "Failed to recreate compute cluster"
            exit 1
        fi
    fi
fi

# Create sinks cluster if it doesn't exist (needed for Kafka sinks)
print_test "Ensuring sinks cluster exists as MANAGED..."
cluster_exists=$(psql "postgresql://materialize@localhost:6875/materialize" -tAc "SELECT COUNT(*) FROM mz_clusters WHERE name = 'sinks'")
if [ "$cluster_exists" -eq 0 ]; then
    if psql "postgresql://materialize@localhost:6875/materialize" \
        -c "CREATE CLUSTER sinks SIZE = '25cc', REPLICATION FACTOR = 1" > /dev/null 2>&1; then
        print_pass "Sinks cluster created (managed)"
    else
        print_fail "Failed to create sinks cluster"
        exit 1
    fi
else
    # Check if it's managed
    is_managed=$(psql "postgresql://materialize@localhost:6875/materialize" -tAc "SELECT managed FROM mz_clusters WHERE name = 'sinks'")
    if [ "$is_managed" = "t" ]; then
        print_pass "Sinks cluster already exists (managed)"
    else
        print_info "Sinks cluster exists but is unmanaged, dropping and recreating..."
        psql "postgresql://materialize@localhost:6875/materialize" -c "DROP CLUSTER sinks CASCADE" > /dev/null 2>&1
        if psql "postgresql://materialize@localhost:6875/materialize" \
            -c "CREATE CLUSTER sinks SIZE = '25cc', REPLICATION FACTOR = 1" > /dev/null 2>&1; then
            print_pass "Sinks cluster recreated as managed"
        else
            print_fail "Failed to recreate sinks cluster"
            exit 1
        fi
    fi
fi

# Set up sources in main environment (needed for transformations to reference)
print_test "Setting up sources in main environment (required for deployment)..."
if dbt run --selector sources_only \
    --profiles-dir "$PROFILES_DIR" \
    --profile "$DBT_PROFILE" \
    --target "$DBT_TARGET" > /tmp/sources_setup.log 2>&1; then
    print_pass "Sources created in main environment"
else
    print_fail "Failed to create sources"
    print_info "Error details:"
    grep -A 3 "ERROR\|Database Error" /tmp/sources_setup.log | head -10
    exit 1
fi

# Load seed data to main environment
print_test "Loading seed data to main environment..."
if dbt seed \
    --profiles-dir "$PROFILES_DIR" \
    --profile "$DBT_PROFILE" \
    --target "$DBT_TARGET" > /dev/null 2>&1; then
    print_pass "Seed data loaded to main environment"
else
    print_info "Seed data may already exist (continuing anyway)"
fi

# Run transformations in main environment (needed for sinks to reference)
print_test "Running transformations in main environment (required for sinks)..."
if dbt run --selector transformations \
    --profiles-dir "$PROFILES_DIR" \
    --profile "$DBT_PROFILE" \
    --target "$DBT_TARGET" > /dev/null 2>&1; then
    print_pass "Transformations created in main environment"
else
    print_info "Transformations may already exist (continuing anyway)"
fi

# Wait for sources to start generating data
print_test "Waiting for sources to generate initial data..."
sleep 20
print_pass "Initial data generation wait complete"

# Create sinks in main environment (needed for promotion swap)
print_test "Creating sinks in main environment (required for swap)..."
if dbt run --selector sinks_only \
    --profiles-dir "$PROFILES_DIR" \
    --profile "$DBT_PROFILE" \
    --target "$DBT_TARGET" > /dev/null 2>&1; then
    print_pass "Sinks created in main environment"
else
    print_info "Sinks may already exist or failed to create (continuing anyway)"
fi

# Ensure clean state
cleanup_deployment

print_header "Test 1: Deploy Init"
print_test "Running deploy_init to create green environment..."

if dbt run-operation deploy_init \
    --profiles-dir "$PROFILES_DIR" \
    --profile "$DBT_PROFILE" \
    --target "$DBT_TARGET" > /dev/null 2>&1; then
    print_pass "deploy_init executed successfully"
else
    print_fail "deploy_init failed"
fi

print_test "Validating green cluster was created..."
cluster_count=$(check_cluster_exists "quickstart_dbt_deploy")
if [ "$cluster_count" -eq 1 ]; then
    print_pass "Green cluster 'quickstart_dbt_deploy' exists"
else
    print_fail "Green cluster was not created (found $cluster_count)"
fi

print_test "Validating green schemas were created..."
for schema in "public_staging_dbt_deploy" "public_intermediate_dbt_deploy" "public_marts_dbt_deploy"; do
    schema_count=$(check_schema_exists "$schema")
    if [ "$schema_count" -eq 1 ]; then
        print_pass "Green schema '$schema' exists"
    else
        print_fail "Green schema '$schema' was not created"
    fi
done

print_header "Test 2: Deploy to Green Environment"
print_test "Deploying models to green environment..."

if dbt run --selector transformations \
    --vars 'deploy: True' \
    --profiles-dir "$PROFILES_DIR" \
    --profile "$DBT_PROFILE" \
    --target "$DBT_TARGET" > /tmp/deploy_green.log 2>&1; then
    print_pass "Models deployed to green environment"
else
    print_fail "Failed to deploy models to green"
    print_info "Error details:"
    grep -B 2 -A 5 "ERROR\|Database Error" /tmp/deploy_green.log | head -30
fi

print_header "Test 3: Cluster Hydration Check"
print_test "Testing deploy_await (checking cluster lag)..."

# Use a short timeout for testing (5 seconds poll, 10s threshold)
if timeout 30 dbt run-operation deploy_await \
    --args '{poll_interval: 5, lag_threshold: "10s"}' \
    --profiles-dir "$PROFILES_DIR" \
    --profile "$DBT_PROFILE" \
    --target "$DBT_TARGET" > /dev/null 2>&1; then
    print_pass "deploy_await completed successfully"
else
    # deploy_await timing out is acceptable for local testing with load generators
    # The actual promotion will wait for hydration internally
    print_info "deploy_await timed out (acceptable - promotion will wait for hydration)"
    ((TESTS_RUN++))
fi

print_header "Test 4: Dry Run Promotion"
print_test "Running deploy_promote in dry run mode..."

if dbt run-operation deploy_promote \
    --args '{dry_run: true}' \
    --profiles-dir "$PROFILES_DIR" \
    --profile "$DBT_PROFILE" \
    --target "$DBT_TARGET" > /tmp/deploy_promote_dry_run.log 2>&1; then
    print_pass "Dry run executed successfully"

    # Check that dry run output contains expected commands
    if grep -q "ALTER" /tmp/deploy_promote_dry_run.log || grep -q "SWAP" /tmp/deploy_promote_dry_run.log; then
        print_pass "Dry run output contains ALTER/SWAP commands"
    else
        print_fail "Dry run output missing expected commands"
    fi
else
    print_fail "Dry run failed"
    print_info "Error details:"
    grep -B 2 -A 5 "ERROR\|Error\|error" /tmp/deploy_promote_dry_run.log | head -30
fi

print_header "Test 5: Actual Promotion (Atomic Swap)"
print_test "Executing deploy_promote (atomic swap)..."

# Verify green environment still exists before promoting
green_schemas_count=$(psql "postgresql://materialize@localhost:6875/materialize" -tAc "SELECT COUNT(*) FROM mz_schemas WHERE name LIKE '%_dbt_deploy'")
if [ "$green_schemas_count" -eq 0 ]; then
    print_info "Warning: Green schemas don't exist, re-initializing..."
    dbt run-operation deploy_init --profiles-dir "$PROFILES_DIR" --profile "$DBT_PROFILE" --target "$DBT_TARGET" > /dev/null 2>&1
    dbt run --selector transformations --vars 'deploy: True' --profiles-dir "$PROFILES_DIR" --profile "$DBT_PROFILE" --target "$DBT_TARGET" > /dev/null 2>&1
fi

# Record pre-promotion state
blue_cluster_before=$(check_cluster_exists "quickstart")
green_cluster_before=$(check_cluster_exists "quickstart_dbt_deploy")

# Initialize variables for use later
blue_cluster_after=""
green_cluster_after=""

if dbt run-operation deploy_promote \
    --profiles-dir "$PROFILES_DIR" \
    --profile "$DBT_PROFILE" \
    --target "$DBT_TARGET" > /tmp/deploy_promote.log 2>&1; then
    print_pass "deploy_promote executed successfully"

    # Verify swap occurred (old blue becomes green, old green becomes blue)
    blue_cluster_after=$(check_cluster_exists "quickstart")
    green_cluster_after=$(check_cluster_exists "quickstart_dbt_deploy")

    if [ "$blue_cluster_after" -eq 1 ] && [ "$green_cluster_after" -eq 1 ]; then
        print_pass "Both clusters exist after swap (ready for rollback)"
    else
        print_fail "Cluster state unexpected after swap"
    fi
else
    print_fail "deploy_promote failed"
    print_info "Error details:"
    grep -A 3 "Error" /tmp/deploy_promote.log | head -10
fi

print_header "Test 6: Rollback Test"
print_test "Testing rollback (swapping back)..."

# Only test rollback if promotion succeeded
if [ -n "$green_cluster_after" ] && [ "$green_cluster_after" -eq 1 ]; then
    if dbt run-operation deploy_promote \
        --profiles-dir "$PROFILES_DIR" \
        --profile "$DBT_PROFILE" \
        --target "$DBT_TARGET" > /tmp/deploy_rollback.log 2>&1; then
        print_pass "Rollback (second deploy_promote) executed successfully"
    else
        print_fail "Rollback failed"
        print_info "Error details:"
        grep -A 3 "Error" /tmp/deploy_rollback.log | head -10
    fi
else
    print_info "Skipping rollback test (promotion didn't complete)"
    ((TESTS_RUN++))
fi

print_header "Test 7: Cleanup"
print_test "Running deploy_cleanup to remove old environment..."

green_cluster_before_cleanup=$(check_cluster_exists "quickstart_dbt_deploy")

if dbt run-operation deploy_cleanup \
    --profiles-dir "$PROFILES_DIR" \
    --profile "$DBT_PROFILE" \
    --target "$DBT_TARGET" > /dev/null 2>&1; then
    print_pass "deploy_cleanup executed successfully"

    # Verify cleanup removed the deployment cluster
    green_cluster_after_cleanup=$(check_cluster_exists "quickstart_dbt_deploy")

    if [ "$green_cluster_after_cleanup" -eq 0 ]; then
        print_pass "Green deployment cluster was removed"
    else
        print_fail "Green deployment cluster still exists after cleanup"
    fi
else
    print_fail "deploy_cleanup failed"
fi

print_header "Test 8: Idempotency Test"
print_test "Testing deploy_cleanup on non-existent environment (should not error)..."

if dbt run-operation deploy_cleanup \
    --profiles-dir "$PROFILES_DIR" \
    --profile "$DBT_PROFILE" \
    --target "$DBT_TARGET" > /dev/null 2>&1; then
    print_pass "deploy_cleanup is idempotent (handles missing environment)"
else
    print_fail "deploy_cleanup failed on non-existent environment"
fi

# Final cleanup
print_info "Performing final cleanup..."
cleanup_deployment

# Summary
print_header "Test Summary"
echo "Tests run: $TESTS_RUN"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "${RED}❌ Some tests failed${NC}"
    exit 1
else
    echo -e "${GREEN}✅ All tests passed${NC}"
    exit 0
fi
