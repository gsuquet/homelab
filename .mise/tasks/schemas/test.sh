#!/usr/bin/env bash
#MISE description="Test the JSON Schemas against valid and invalid fixtures"

set -euo pipefail

# shellcheck source=../_base/log.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/log.sh"

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

if [ "$failures" -ne 0 ]; then
    log_error "$failures schema test(s) failed."
    exit 1
fi

log_info "✓ All schema tests passed."
