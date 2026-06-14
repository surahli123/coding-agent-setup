#!/bin/bash
# Fix #3: Pre-commit test gate
# Runs targeted tests for changed files before allowing commit.
# Catches path errors, exception swallowing, and broken imports
# that keep slipping through.
#
# Behavior:
#   - Detects project type (Python/Node) from config files
#   - Finds test files matching staged source files
#   - Runs only those tests (not the full suite)
#   - 60-second timeout to avoid blocking on slow suites
#   - Skips gracefully if no test runner or no code files changed
#
# Exit codes:
#   0 = allow commit (tests passed or skipped)
#   2 = block commit (tests failed)

# --- Python projects ---
if [ -f "pytest.ini" ] || [ -f "pyproject.toml" ] || [ -f "setup.py" ] || [ -f "setup.cfg" ]; then
  if ! command -v pytest &>/dev/null; then
    exit 0  # no pytest installed, skip
  fi

  # Get staged Python source files (not test files themselves)
  STAGED_PY=$(git diff --cached --name-only --diff-filter=ACM -- '*.py' | grep -v '^tests/' | grep -v 'test_' || true)

  if [ -z "$STAGED_PY" ]; then
    exit 0  # no source .py files changed, skip
  fi

  # Find matching test files
  TEST_FILES=""
  for src in $STAGED_PY; do
    module=$(basename "$src" .py)
    # Search common test locations
    for test_dir in tests test; do
      found=$(find "$test_dir" -maxdepth 2 -name "test_${module}.py" -o -name "test_${module}_*.py" 2>/dev/null | head -3)
      if [ -n "$found" ]; then
        TEST_FILES="$TEST_FILES $found"
      fi
    done
  done

  # Deduplicate
  TEST_FILES=$(echo "$TEST_FILES" | tr ' ' '\n' | sort -u | tr '\n' ' ')

  if [ -z "$TEST_FILES" ]; then
    echo "No matching test files for changed modules. Skipping test gate."
    exit 0
  fi

  echo "Running targeted tests: $TEST_FILES"

  # Run with 60-second timeout
  timeout 60 pytest $TEST_FILES --tb=short -q 2>&1
  TEST_EXIT=$?

  if [ $TEST_EXIT -eq 124 ]; then
    echo "Tests timed out (60s). Allowing commit, but check tests manually." >&2
    exit 0  # timeout = warn, don't block
  elif [ $TEST_EXIT -ne 0 ]; then
    echo "" >&2
    echo "BLOCKED: Tests failed. Fix before committing." >&2
    echo "Failed tests: $TEST_FILES" >&2
    exit 2
  fi

  echo "Tests passed."
  exit 0
fi

# --- Node projects ---
if [ -f "package.json" ]; then
  # Only run if there are staged JS/TS files
  STAGED_JS=$(git diff --cached --name-only --diff-filter=ACM -- '*.js' '*.ts' '*.jsx' '*.tsx' | grep -v 'node_modules' || true)

  if [ -z "$STAGED_JS" ]; then
    exit 0
  fi

  if ! command -v npm &>/dev/null; then
    exit 0
  fi

  # Check if test script exists in package.json
  if ! grep -q '"test"' package.json 2>/dev/null; then
    exit 0
  fi

  echo "Running npm test..."
  timeout 60 npm test --silent 2>&1
  TEST_EXIT=$?

  if [ $TEST_EXIT -eq 124 ]; then
    echo "Tests timed out (60s). Allowing commit, but check tests manually." >&2
    exit 0
  elif [ $TEST_EXIT -ne 0 ]; then
    echo "" >&2
    echo "BLOCKED: npm test failed. Fix before committing." >&2
    exit 2
  fi

  echo "Tests passed."
  exit 0
fi

# No recognized project type — skip silently
exit 0
