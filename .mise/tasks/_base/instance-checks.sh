# shellcheck shell=bash
# Checks of an instance folder and of the gitops/ tree. Used by schemas:check and schemas:test.

# check_instance_terraform <instance.yaml>
# The Terraform files of the instance must use exactly the modules that
# instance.yaml lists, and must have a backend or cloud block exactly when the
# backend is not local. Increments the global failures counter on each error.
# schemas:test runs the cases in schemas/tests/instance-terraform/.
check_instance_terraform() {
    local file="$1"
    local dir listed used backend has_backend
    dir="$(dirname "$file")"

    listed="$(yq '.layers[].modules[]' "$file" | sort -u)"
    # Comment lines are skipped. A source can be on one line with its module block,
    # and can name a subfolder (../../modules/<m>//<path>).
    used="$(cat "$dir"/*.tf 2> /dev/null |
        grep -Ev '^[[:space:]]*(#|//)' |
        { grep -Eo 'source[[:space:]]*=[[:space:]]*"\.\./\.\./modules/[^"/]+' || true; } |
        sed 's|.*/modules/||' | sort -u)"
    if [ "$listed" != "$used" ]; then
        log_error "$file: the modules in instance.yaml are not the modules that $dir/*.tf uses"
        { diff <(echo "$listed") <(echo "$used") || true; } | sed -n 's/^</  only in instance.yaml:/p; s/^>/  only in the Terraform files:/p' >&2
        failures=$((failures + 1))
    fi

    # instance:up reads the cluster_name output to export the kind context.
    if grep -qx 'cluster-kind' <<< "$listed" &&
        ! grep -Eq '^[[:space:]]*output[[:space:]]+"cluster_name"' "$dir"/*.tf 2> /dev/null; then
        log_error "$file: the instance uses cluster-kind, but $dir/*.tf has no output \"cluster_name\""
        failures=$((failures + 1))
    fi

    backend="$(yq '.state.backend' "$file")"
    has_backend=no
    if grep -Eq '^[[:space:]]*(backend[[:space:]]+"|cloud[[:space:]]*\{)' "$dir"/*.tf 2> /dev/null; then
        has_backend=yes
    fi
    if [ "$backend" = "local" ] && [ "$has_backend" = "yes" ]; then
        log_error "$file: state.backend is local, but $dir/*.tf has a backend or cloud block"
        failures=$((failures + 1))
    elif [ "$backend" != "local" ] && [ "$has_backend" = "no" ]; then
        log_error "$file: state.backend is $backend, but $dir/*.tf has no backend or cloud block"
        failures=$((failures + 1))
    fi
}

# check_gitops_tree <root>
# Checks gitops/ in <root>. Increments the global failures counter on each error.
# - Each gitops/instances/<instance>.yaml validates against its schema, and
#   instance is equal to the file name.
# - Each component in the file has gitops/<group>/<name>/rendered/<instance>/.
# - No two components have the same name: it is also the Application name.
# - Argo CD manages itself: each instance in gitops/platform/argocd/values/
#   has an entry point, and the entry point lists argocd in platform. Without
#   this, the ApplicationSet deletes the argocd Application and Argo CD stops
#   managing itself.
# schemas:test runs the cases in schemas/tests/gitops-tree/.
check_gitops_tree() {
    local root="$1"
    local schema="$MISE_PROJECT_ROOT/schemas/gitops-instance.schema.json"
    local file instance group name duplicates values

    for file in "$root"/gitops/instances/*.yaml; do
        [ -f "$file" ] || continue

        if ! check-jsonschema --schemafile "$schema" "$file"; then
            failures=$((failures + 1))
            continue
        fi

        instance="$(yq '.instance' "$file")"
        if [ "$instance" != "$(basename "$file" .yaml)" ]; then
            log_error "$file: instance '$instance' must be equal to the file name '$(basename "$file" .yaml)'"
            failures=$((failures + 1))
        fi

        for group in platform apps; do
            while IFS= read -r name; do
                [ -n "$name" ] || continue
                if [ ! -d "$root/gitops/$group/$name/rendered/$instance" ]; then
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
    done

    for values in "$root"/gitops/platform/argocd/values/*.yaml; do
        [ -f "$values" ] || continue
        instance="$(basename "$values" .yaml)"
        file="$root/gitops/instances/$instance.yaml"
        if [ ! -f "$file" ]; then
            log_error "$values: Argo CD runs on $instance, but $file is missing. Argo CD would stop managing itself."
            failures=$((failures + 1))
        elif [ "$(yq '[.platform[] | select(.name == "argocd")] | length' "$file")" = "0" ]; then
            log_error "$file: platform must list argocd. Argo CD would stop managing itself."
            failures=$((failures + 1))
        fi
    done
}
