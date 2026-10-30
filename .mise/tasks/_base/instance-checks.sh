# shellcheck shell=bash
# Checks of an instance folder. Used by schemas:check and schemas:test.

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
