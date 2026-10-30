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

# check_instance_modules <instance.yaml>
# Each module in layers.<layer>.modules must exist in modules/ and declare the same layer.
check_instance_modules() {
    local file="$1"
    local layer module module_file module_layer
    # shellcheck disable=SC2016 # $layer is a yq variable, not a shell variable.
    local query='.layers | to_entries | .[] | .key as $layer | .value.modules[] | $layer + " " + .'

    while IFS=' ' read -r layer module; do
        [ -n "$module" ] || continue
        module_file="modules/$module/module.yaml"
        if [ ! -f "$module_file" ]; then
            log_error "$file: module '$module' does not exist ($module_file is missing)"
            failures=$((failures + 1))
            continue
        fi
        module_layer="$(yq '.layer' "$module_file")"
        if [ "$module_layer" != "$layer" ]; then
            log_error "$file: module '$module' is in layer '$module_layer', not '$layer'"
            failures=$((failures + 1))
        fi
    done < <(yq "$query" "$file")
}

# check_instance_terraform <instance.yaml>
# The Terraform files of the instance must use exactly the modules that
# instance.yaml lists, and must have a backend block exactly when the backend is
# not local.
check_instance_terraform() {
    local file="$1"
    local dir listed used backend has_backend
    dir="$(dirname "$file")"

    listed="$(yq '.layers[].modules[]' "$file" | sort -u)"
    used="$(cat "$dir"/*.tf 2> /dev/null |
        sed -n 's|^[[:space:]]*source[[:space:]]*=[[:space:]]*"\.\./\.\./modules/\([^"/]*\)".*|\1|p' | sort -u)"
    if [ "$listed" != "$used" ]; then
        log_error "$file: the modules in instance.yaml are not the modules that $dir/*.tf uses"
        diff <(echo "$listed") <(echo "$used") | sed -n 's/^</  only in instance.yaml:/p; s/^>/  only in the Terraform files:/p' >&2
        failures=$((failures + 1))
    fi

    backend="$(yq '.state.backend' "$file")"
    has_backend=no
    if grep -Eq '^[[:space:]]*backend[[:space:]]+"' "$dir"/*.tf 2> /dev/null; then
        has_backend=yes
    fi
    if [ "$backend" = "local" ] && [ "$has_backend" = "yes" ]; then
        log_error "$file: state.backend is local, but $dir/*.tf has a backend block"
        failures=$((failures + 1))
    elif [ "$backend" != "local" ] && [ "$has_backend" = "no" ]; then
        log_error "$file: state.backend is $backend, but $dir/*.tf has no backend block"
        failures=$((failures + 1))
    fi
}

check_kind schemas/module.schema.json modules module.yaml
check_kind schemas/instance.schema.json instances instance.yaml

for file in instances/*/instance.yaml; do
    [ -f "$file" ] || continue
    check_instance_modules "$file"
    check_instance_terraform "$file"
done

if [ "$failures" -ne 0 ]; then
    log_error "$failures file(s) do not comply with their schema."
    exit 1
fi

log_info "✓ All module.yaml and instance.yaml files comply with their schema."
