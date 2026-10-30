#!/usr/bin/env bash
#MISE description="Validate every module.yaml, instance.yaml and GitOps instance file against its schema"

set -euo pipefail

# shellcheck source=../_base/log.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/log.sh"
# shellcheck source=../_base/instance-checks.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/instance-checks.sh"

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

# check_gitops_instance <gitops/instances/<instance>.yaml>
# The file validates against its schema, instance is equal to the file name,
# each component has a rendered folder for the instance, and no two components
# have the same name: the name is also the name of the Argo CD Application.
check_gitops_instance() {
    local file="$1"
    local instance group name duplicates

    if ! check-jsonschema --schemafile schemas/gitops-instance.schema.json "$file"; then
        failures=$((failures + 1))
        return
    fi

    instance="$(yq '.instance' "$file")"
    if [ "$instance" != "$(basename "$file" .yaml)" ]; then
        log_error "$file: instance '$instance' must be equal to the file name '$(basename "$file" .yaml)'"
        failures=$((failures + 1))
    fi

    for group in platform apps; do
        while IFS= read -r name; do
            [ -n "$name" ] || continue
            if [ ! -d "gitops/$group/$name/rendered/$instance" ]; then
                log_error "$file: gitops/$group/$name/rendered/$instance/ is missing. Add gitops/$group/$name/values/$instance.yaml and run 'mise run manifests:render'."
                failures=$((failures + 1))
            fi
        done < <(yq ".${group}[].name" "$file")
    done

    duplicates="$(yq '(.platform + .apps)[].name' "$file" | sort | uniq -d)"
    if [ -n "$duplicates" ]; then
        log_error "$file: more than one component has the name: $duplicates"
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

for file in gitops/instances/*.yaml; do
    [ -f "$file" ] || continue
    check_gitops_instance "$file"
done

if [ "$failures" -ne 0 ]; then
    log_error "$failures file(s) do not comply with their schema."
    exit 1
fi

log_info "✓ All module.yaml, instance.yaml and GitOps instance files comply with their schema."
