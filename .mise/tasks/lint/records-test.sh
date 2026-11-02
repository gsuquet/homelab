#!/usr/bin/env bash
#MISE description="Test that lint:records fails on a match and on a git grep error"

# The test puts a fake git first in PATH. The fake git exits with a fixed code.
# lint:records must pass only when git grep exits 1 (no match).

set -euo pipefail

# shellcheck source=../_base/log.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/log.sh"

task="$MISE_PROJECT_ROOT/.mise/tasks/lint/records.sh"
shim_dir="$(mktemp -d)"
trap 'rm -rf "$shim_dir"' EXIT

failures=0

# run_case <fake exit code> <expected result: pass or fail>
run_case() {
    local code="$1" expected="$2" result
    printf '#!/usr/bin/env bash\nexit %s\n' "$code" > "$shim_dir/git"
    chmod +x "$shim_dir/git"
    if PATH="$shim_dir:$PATH" "$task" > /dev/null 2>&1; then
        result=pass
    else
        result=fail
    fi
    if [ "$result" = "$expected" ]; then
        log_info "ok: git grep exit $code gives $result"
    else
        log_error "git grep exit $code gives $result, expected $expected"
        failures=$((failures + 1))
    fi
}

run_case 1 pass
run_case 0 fail
run_case 2 fail
run_case 128 fail

if [ "$failures" -ne 0 ]; then
    exit 1
fi

log_info "✓ lint:records passes only when git grep finds no match."
