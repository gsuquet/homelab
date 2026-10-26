#!/usr/bin/env bash
#MISE description="Test the Conftest policies, then check the repository against them"

set -euo pipefail

# shellcheck source=../_base/log.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/log.sh"

cd "$MISE_PROJECT_ROOT"

log_info "Testing policies..."
conftest verify --policy policy

# conftest_files <namespace> <conftest args...> -- <git pathspec...>
conftest_files() {
    local namespace="$1"
    shift
    # bash 3.2 (macOS) treats an empty "${args[@]}" as unbound under `set -u`.
    local args=()
    while [ "$1" != "--" ]; do
        args+=("$1")
        shift
    done
    shift

    local files=()
    local file
    while IFS= read -r file; do
        files+=("$file")
    done < <(git ls-files -- "$@")
    if [ "${#files[@]}" -eq 0 ]; then
        log_warn "No files for policy namespace '$namespace'"
        return 0
    fi

    log_info "Checking ${#files[@]} file(s) against policy namespace '$namespace'..."
    conftest test --no-color --policy policy --namespace "$namespace" ${args[@]+"${args[@]}"} "${files[@]}"
}

conftest_files terraform --combine --parser hcl2 -- '*.tf'
conftest_files kubernetes --combine -- 'kubernetes/*.yaml' 'gitops/*.yaml'
conftest_files precommit -- .pre-commit-config.yaml
conftest_files mise -- .mise/config.toml

log_info "✓ The repository complies with every policy."
