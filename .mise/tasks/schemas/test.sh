#!/usr/bin/env bash
#MISE description="Test the JSON Schemas against valid and invalid fixtures"

set -euo pipefail

# shellcheck source=../_base/log.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/log.sh"
# shellcheck source=../_base/instance-checks.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/instance-checks.sh"

cd "$MISE_PROJECT_ROOT"

failures=0

for schema in schemas/*.schema.json; do
    name="$(basename "$schema" .schema.json)"
    fixtures="schemas/tests/$name"

    if [ ! -d "$fixtures/valid" ] || [ ! -d "$fixtures/invalid" ]; then
        log_error "$schema has no fixtures. Add $fixtures/valid and $fixtures/invalid."
        failures=$((failures + 1))
        continue
    fi

    for file in "$fixtures"/valid/*.yaml; do
        if check-jsonschema --schemafile "$schema" "$file" > /dev/null 2>&1; then
            log_info "pass (accepted as expected): $file"
        else
            log_error "fail (rejected, expected accepted): $file"
            check-jsonschema --schemafile "$schema" "$file" || true
            failures=$((failures + 1))
        fi
    done

    for file in "$fixtures"/invalid/*.yaml; do
        if check-jsonschema --schemafile "$schema" "$file" > /dev/null 2>&1; then
            log_error "fail (accepted, expected rejected): $file"
            failures=$((failures + 1))
        else
            log_info "pass (rejected as expected): $file"
        fi
    done
done

# run_instance_terraform_case <folder>
# Sets case_errors to the number of errors that check_instance_terraform finds in
# a copy of the folder.
run_instance_terraform_case() {
    local case_dir="$1" work tf saved="$failures"
    work="$(mktemp -d)"
    cp "$case_dir"/* "$work"/
    for tf in "$work"/*.tf.txt; do
        [ -f "$tf" ] && mv "$tf" "${tf%.txt}"
    done
    failures=0
    check_instance_terraform "$work/instance.yaml" > /dev/null 2>&1
    case_errors="$failures"
    failures="$saved"
    rm -rf "$work"
}

terraform_cases="schemas/tests/instance-terraform"
for case_dir in "$terraform_cases"/valid/*/; do
    case_dir="${case_dir%/}"
    run_instance_terraform_case "$case_dir"
    if [ "$case_errors" -eq 0 ]; then
        log_info "pass (accepted as expected): $case_dir"
    else
        log_error "fail (rejected, expected accepted): $case_dir"
        failures=$((failures + 1))
    fi
done
for case_dir in "$terraform_cases"/invalid/*/; do
    case_dir="${case_dir%/}"
    run_instance_terraform_case "$case_dir"
    if [ "$case_errors" -eq 1 ]; then
        log_info "pass (rejected as expected): $case_dir"
    else
        log_error "fail (expected exactly 1 error, got $case_errors): $case_dir"
        failures=$((failures + 1))
    fi
done

if [ "$failures" -ne 0 ]; then
    log_error "$failures schema test(s) failed."
    exit 1
fi

log_info "✓ All schema tests passed."
