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
# - Each folder in gitops/clusters/ has a cluster.yaml that validates against
#   its schema, and name is equal to the folder name.
# - The cluster lists argocd in infrastructure: Argo CD manages itself. Without
#   it, the cluster has no Application for Argo CD.
# - No two components have the same name: it is also the Application name.
# - Each dependsOn names a component of the cluster.
# - Each component has gitops/<group>/<name>/sources/, and
#   gitops/clusters/<cluster>/rendered/<name>/ contains its Namespace.
# - Each file in gitops/clusters/<cluster>/values/ is for a component of the
#   cluster. Else manifests:render ignores the file.
# - Each folder in gitops/infrastructure/ and gitops/apps/ has
#   sources/Chart.yaml and sources/templates/namespace.yaml: all components use
#   the rendered manifests pattern and ship their own Namespace.
# - A Terraform instance that bootstraps Argo CD uses the cluster with its own
#   name: instances/<name>/ uses gitops/clusters/<name>/rendered/argocd.
# schemas:test runs the cases in schemas/tests/gitops-tree/.
check_gitops_tree() {
    local root="$1"
    local schema="$MISE_PROJECT_ROOT/schemas/gitops-cluster.schema.json"
    local cluster_dir cluster file name group namespace rendered names duplicates dependency values

    for cluster_dir in "$root"/gitops/clusters/*/; do
        [ -d "$cluster_dir" ] || continue
        cluster="$(basename "$cluster_dir")"
        file="${cluster_dir}cluster.yaml"

        if [ ! -f "$file" ]; then
            log_error "${cluster_dir}: cluster.yaml is missing"
            failures=$((failures + 1))
            continue
        fi
        if ! check-jsonschema --schemafile "$schema" "$file"; then
            failures=$((failures + 1))
            continue
        fi

        name="$(yq '.name' "$file")"
        if [ "$name" != "$cluster" ]; then
            log_error "$file: name '$name' must be equal to the folder name '$cluster'"
            failures=$((failures + 1))
        fi

        if [ "$(yq '[.infrastructure[] | select(.name == "argocd")] | length' "$file")" = "0" ]; then
            log_error "$file: infrastructure must list argocd. Else Argo CD does not manage itself."
            failures=$((failures + 1))
        fi

        names="$(yq '(.infrastructure + .apps)[].name' "$file")"
        duplicates="$(sort <<< "$names" | uniq -d)"
        if [ -n "$duplicates" ]; then
            log_error "$file: more than one component has the name: $duplicates"
            failures=$((failures + 1))
        fi

        while IFS= read -r dependency; do
            [ -n "$dependency" ] || continue
            if ! grep -qxF -- "$dependency" <<< "$names"; then
                log_error "$file: dependsOn names '$dependency', but the cluster has no component '$dependency'"
                failures=$((failures + 1))
            fi
        done < <(yq '(.infrastructure + .apps)[].dependsOn[]' "$file" | sort -u)

        for group in infrastructure apps; do
            while IFS=' ' read -r name namespace; do
                [ -n "$name" ] || continue
                rendered="${cluster_dir}rendered/$name"
                if [ ! -f "$root/gitops/$group/$name/sources/Chart.yaml" ]; then
                    log_error "$file: gitops/$group/$name/sources/Chart.yaml is missing"
                    failures=$((failures + 1))
                elif [ ! -d "$rendered" ]; then
                    log_error "$file: gitops/clusters/$cluster/rendered/$name/ is missing. Run 'mise run manifests:render'."
                    failures=$((failures + 1))
                elif ! grep -qxF -- "$namespace" <<< "$(yq ea 'select(.kind == "Namespace") | .metadata.name' "$rendered"/*.yaml 2> /dev/null || true)"; then
                    log_error "$file: gitops/clusters/$cluster/rendered/$name/ has no Namespace '$namespace'. Each component ships its own Namespace."
                    failures=$((failures + 1))
                fi
            done < <(yq ".${group}[] | .name + \" \" + .namespace" "$file")
        done

        for values in "${cluster_dir}"values/*.yaml; do
            [ -f "$values" ] || continue
            if ! grep -qxF -- "$(basename "$values" .yaml)" <<< "$names"; then
                log_error "$values: the cluster has no component '$(basename "$values" .yaml)'. manifests:render ignores this file."
                failures=$((failures + 1))
            fi
        done
    done

    # Each component uses the rendered manifests pattern: an umbrella chart in
    # sources/, rendered by manifests:render. There is no hand-written folder.
    local component required
    for component in "$root"/gitops/infrastructure/*/ "$root"/gitops/apps/*/; do
        [ -d "$component" ] || continue
        for required in sources/Chart.yaml sources/templates/namespace.yaml; do
            if [ ! -f "${component}${required}" ]; then
                log_error "${component}: ${required} is missing. Each component uses the rendered manifests pattern and ships its own Namespace."
                failures=$((failures + 1))
            fi
        done
    done

    # A Terraform instance and its GitOps cluster have the same name.
    local tf_file instance
    for tf_file in "$root"/instances/*/*.tf; do
        [ -f "$tf_file" ] || continue
        instance="$(basename "$(dirname "$tf_file")")"
        while IFS= read -r cluster; do
            [ -n "$cluster" ] || continue
            if [ "$cluster" != "$instance" ]; then
                log_error "$tf_file: the instance '$instance' bootstraps Argo CD from gitops/clusters/$cluster/. Use gitops/clusters/$instance/."
                failures=$((failures + 1))
            fi
        done < <({ grep -Eo 'gitops/clusters/[^/"]+/rendered/argocd' "$tf_file" || true; } | sed 's|gitops/clusters/||; s|/rendered/argocd||' | sort -u)
    done
}
