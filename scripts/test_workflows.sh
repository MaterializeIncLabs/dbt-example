#!/bin/bash
# Note: Not using 'set -e' to allow tests to continue on failure

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test results tracking
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

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

echo "============================================"
echo "GitHub Actions Workflow Validation Tests"
echo "============================================"
echo ""

# Test 1: Check YAML syntax
print_test "Validating YAML syntax for all workflows..."

# Try to find a YAML parser (prefer ruby, fall back to python if yaml module is available)
if command -v ruby &> /dev/null; then
    YAML_PARSER="ruby"
elif python3 -c "import yaml" 2>/dev/null; then
    YAML_PARSER="python"
else
    print_test "Skipping YAML syntax validation (no YAML parser available)"
    print_test "Install PyYAML: pip install pyyaml"
    YAML_PARSER="none"
fi

if [ "$YAML_PARSER" != "none" ]; then
    for workflow in .github/workflows/*.yml; do
        if [ "$YAML_PARSER" = "ruby" ]; then
            if ruby -ryaml -e "YAML.load_file('$workflow')" 2>/dev/null; then
                print_pass "$(basename $workflow) - YAML syntax valid"
            else
                print_fail "$(basename $workflow) - YAML syntax invalid"
            fi
        else
            if python3 -c "import yaml; yaml.safe_load(open('$workflow'))" 2>/dev/null; then
                print_pass "$(basename $workflow) - YAML syntax valid"
            else
                print_fail "$(basename $workflow) - YAML syntax invalid"
            fi
        fi
    done
fi

# Test 2: Check required workflow structure
print_test "Validating workflow structure..."

check_workflow_field() {
    local workflow=$1
    local field=$2
    local description=$3

    if [ "$YAML_PARSER" = "ruby" ]; then
        # Special handling for 'on' field (YAML parses it as boolean true)
        if [ "$field" = "on" ]; then
            if ruby -ryaml -e "
data = YAML.load_file('$workflow')
raise 'Missing on' unless data.key?(true) || data.key?('on')
" 2>/dev/null; then
                print_pass "$description - $(basename $workflow)"
            else
                print_fail "$description - $(basename $workflow)"
            fi
        else
            if ruby -ryaml -e "
data = YAML.load_file('$workflow')
raise 'Missing $field' unless data.key?('$field')
" 2>/dev/null; then
                print_pass "$description - $(basename $workflow)"
            else
                print_fail "$description - $(basename $workflow)"
            fi
        fi
    elif [ "$YAML_PARSER" = "python" ]; then
        if python3 -c "
import yaml
with open('$workflow') as f:
    data = yaml.safe_load(f)
    assert '$field' in data, 'Missing $field'
" 2>/dev/null; then
            print_pass "$description - $(basename $workflow)"
        else
            print_fail "$description - $(basename $workflow)"
        fi
    else
        print_test "Skipping field check for $(basename $workflow) (no YAML parser)"
    fi
}

for workflow in .github/workflows/dbt-blue-green*.yml; do
    check_workflow_field "$workflow" "name" "Has 'name' field"
    check_workflow_field "$workflow" "on" "Has 'on' triggers"
    check_workflow_field "$workflow" "jobs" "Has 'jobs' defined"
done

# Test 3: Validate blue/green workflow specific requirements
print_test "Validating blue/green deployment workflow requirements..."

# Check single approval workflow
SINGLE_WORKFLOW=".github/workflows/dbt-blue-green.yml"
if [ -f "$SINGLE_WORKFLOW" ]; then
    # Check for release trigger
    if grep -q "release:" "$SINGLE_WORKFLOW"; then
        print_pass "Single approval workflow has release trigger"
    else
        print_fail "Single approval workflow missing release trigger"
    fi

    # Check for environment protection
    if grep -q "environment: production" "$SINGLE_WORKFLOW"; then
        print_pass "Single approval workflow has environment protection"
    else
        print_fail "Single approval workflow missing environment protection"
    fi

    # Check for key deployment steps
    for step in "deploy_init" "deploy_await" "deploy_promote" "deploy_cleanup"; do
        if grep -q "$step" "$SINGLE_WORKFLOW"; then
            print_pass "Single approval workflow includes $step step"
        else
            print_fail "Single approval workflow missing $step step"
        fi
    done
else
    print_fail "Single approval workflow file not found"
fi

# Check two-stage workflow
TWO_STAGE_WORKFLOW=".github/workflows/dbt-blue-green-two-stage.yml"
if [ -f "$TWO_STAGE_WORKFLOW" ]; then
    # Check for two jobs
    job_count=$(grep -c "^  [a-z-]*:" "$TWO_STAGE_WORKFLOW" | head -1)
    if [ "$job_count" -ge 2 ]; then
        print_pass "Two-stage workflow has multiple jobs"
    else
        print_fail "Two-stage workflow should have at least 2 jobs"
    fi

    # Check for both environment protections
    if grep -q "environment: production-deploy" "$TWO_STAGE_WORKFLOW"; then
        print_pass "Two-stage workflow has production-deploy environment"
    else
        print_fail "Two-stage workflow missing production-deploy environment"
    fi

    if grep -q "environment: production-promote" "$TWO_STAGE_WORKFLOW"; then
        print_pass "Two-stage workflow has production-promote environment"
    else
        print_fail "Two-stage workflow missing production-promote environment"
    fi

    # Check for artifact upload/download
    if grep -q "upload-artifact" "$TWO_STAGE_WORKFLOW" && grep -q "download-artifact" "$TWO_STAGE_WORKFLOW"; then
        print_pass "Two-stage workflow has artifact handling"
    else
        print_fail "Two-stage workflow missing artifact handling"
    fi

    # Check for job dependency
    if grep -q "needs: build-and-test-green" "$TWO_STAGE_WORKFLOW"; then
        print_pass "Two-stage workflow has proper job dependencies"
    else
        print_fail "Two-stage workflow missing job dependencies"
    fi
else
    print_fail "Two-stage workflow file not found"
fi

# Test 4: Check for common security issues
print_test "Checking for security best practices..."

for workflow in .github/workflows/dbt-blue-green*.yml; do
    # Check secrets are properly referenced
    if grep -q '\${{ secrets\.' "$workflow"; then
        print_pass "$(basename $workflow) - Uses GitHub secrets properly"
    else
        print_fail "$(basename $workflow) - No secrets usage found (expected for DB credentials)"
    fi

    # Check no hardcoded credentials
    if ! grep -iE '(password|token|key).*[:=].*['\''"][^$]' "$workflow" | grep -v "GITHUB_" > /dev/null; then
        print_pass "$(basename $workflow) - No hardcoded credentials detected"
    else
        print_fail "$(basename $workflow) - Potential hardcoded credentials detected"
    fi
done

# Test 5: Validate concurrency settings
print_test "Validating concurrency controls..."

for workflow in .github/workflows/dbt-blue-green*.yml; do
    if grep -q "concurrency:" "$workflow"; then
        print_pass "$(basename $workflow) - Has concurrency control"
    else
        print_fail "$(basename $workflow) - Missing concurrency control"
    fi

    if grep -q "cancel-in-progress: false" "$workflow"; then
        print_pass "$(basename $workflow) - Prevents concurrent deployments"
    else
        print_fail "$(basename $workflow) - Should prevent concurrent deployments"
    fi
done

# Test 6: Validate error handling
print_test "Checking error handling..."

for workflow in .github/workflows/dbt-blue-green*.yml; do
    if grep -q "if: failure()" "$workflow"; then
        print_pass "$(basename $workflow) - Has failure handling"
    else
        print_fail "$(basename $workflow) - Missing failure handling"
    fi

    if grep -q "if: success()" "$workflow"; then
        print_pass "$(basename $workflow) - Has success handling"
    else
        print_fail "$(basename $workflow) - Missing success handling"
    fi
done

# Summary
echo ""
echo "============================================"
echo "Test Summary"
echo "============================================"
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
