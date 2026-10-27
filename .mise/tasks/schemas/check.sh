#!/usr/bin/env bash
#MISE description="Validate every module.yaml and instance.yaml against its schema"

set -euo pipefail

# shellcheck source=../_base/log.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/log.sh"

cd "$MISE_PROJECT_ROOT"

failures=0

# check_kind <schema> <glob dir> <file name>
check_kind() {
    local schema="$1" root="$2" file_name="$3"
    local dir file name

    [ -d "$root" ] || return 0

    for dir in "$root"/*/; do
        dir="${dir%/}"
        file="$dir/$file_name"

        if [ ! -f "$file" ]; then
            log_error "missing $file"
            failures=$((failures + 1))
            continue
        fi

        if ! check-jsonschema --schemafile "$schema" "$file"; then
            failures=$((failures + 1))
            continue
        fi

        # The template folder has a placeholder name.
        [ "$(basename "$dir")" = "_template" ] && continue

        name="$(yq '.name' "$file")"
        if [ "$name" != "$(basename "$dir")" ]; then
            log_error "$file: name '$name' must be equal to the folder name '$(basename "$dir")'"
            failures=$((failures + 1))
        fi
    done
}

check_kind schemas/module.schema.json modules module.yaml
check_kind schemas/instance.schema.json instances instance.yaml

if [ "$failures" -ne 0 ]; then
    log_error "$failures file(s) do not comply with their schema."
    exit 1
fi

log_info "✓ All module.yaml and instance.yaml files comply with their schema."
