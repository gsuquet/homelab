#!/usr/bin/env bash
#MISE description="Render Kubernetes manifests from Helm Charts"

set -euo pipefail

# Renders the umbrella Helm charts in sources/ folders to plain manifests:
# - kubernetes/**/sources/ renders with the sibling values.yaml to manifests/.
# - gitops/<group>/<component>/sources/ renders once for each cluster that
#   lists it, to gitops/clusters/<cluster>/rendered/<component>/.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! PROJECT_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2> /dev/null)"; then
    PROJECT_ROOT="${MISE_PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
fi

# shellcheck source=../_base/log.sh
source "${MISE_PROJECT_ROOT:-$PROJECT_ROOT}/.mise/tasks/_base/log.sh"

source_comment_to_filename() {
    local source_path="$1"

    source_path="${source_path#*/templates/}"
    source_path="${source_path#templates/}"
    source_path="${source_path%.yaml}"
    source_path="${source_path//\//-}"

    echo "${source_path}.yaml"
}

trim_manifest_file() {
    local file="$1"

    if head -1 "$file" | grep -q "^---"; then
        tail -n +2 "$file" > "${file}.tmp"
        mv "${file}.tmp" "$file"
    fi

    awk '{lines[NR]=$0} END{n=NR; while(n>0 && (lines[n] ~ /^---[[:space:]]*$/)) n--; for(i=1;i<=n;i++) print lines[i]}' "$file" > "${file}.trim"
    mv "${file}.trim" "$file"
}

split_manifest_by_source() {
    local manifest_file="$1"
    local manifest_dir="$2"

    if ! grep -q '^# Source:' "$manifest_file"; then
        log_warn "No # Source comments found in $manifest_file; skipping split"
        return 0
    fi

    find "$manifest_dir" -maxdepth 1 -type f -name "*.yaml" ! -name "install.yaml" -delete

    local temp_file
    temp_file="$(mktemp)"
    local current_file=""
    local file_count=0

    flush_current_resource() {
        if [ -n "$current_file" ] && [ -s "$temp_file" ]; then
            trim_manifest_file "$temp_file"

            local output_path="$manifest_dir/$current_file"
            if [ -f "$output_path" ]; then
                local base_name="${current_file%.yaml}"
                local index=2
                while [ -f "$manifest_dir/${base_name}-${index}.yaml" ]; do
                    ((index++))
                done
                output_path="$manifest_dir/${base_name}-${index}.yaml"
            fi

            cat "$temp_file" > "$output_path"
            ((file_count += 1))
        fi
    }

    while IFS= read -r line || [ -n "$line" ]; do
        if [[ "$line" =~ ^#\ Source:\ (.+)$ ]]; then
            flush_current_resource

            current_file="$(source_comment_to_filename "${BASH_REMATCH[1]}")"
            : > "$temp_file"
            echo "$line" >> "$temp_file"
        elif [ -n "$current_file" ]; then
            echo "$line" >> "$temp_file"
        fi
    done < "$manifest_file"

    flush_current_resource

    rm -f "$temp_file" "${temp_file}.tmp" "${temp_file}.trim"
    log_info "Split $file_count manifests from $manifest_file"
}

# split_manifest_by_resource <manifest file> <output dir>
# Writes one file for each resource: <kind>-<name>.yaml, in lower case. The file
# name does not change when the chart moves a resource to another template.
split_manifest_by_resource() {
    local manifest_file="$1"
    local output_dir="$2"
    local documents files

    mkdir -p "$output_dir"
    documents="$(yq ea '[select(. != null)] | length' "$manifest_file")"
    (cd "$output_dir" && yq 'select(. != null)' -s '(.kind | downcase) + "-" + (.metadata.name | downcase | sub("[^a-z0-9.-]", "-")) + ".yaml"' "$manifest_file")
    files="$(find "$output_dir" -maxdepth 1 -type f -name '*.yaml' | wc -l)"
    if [ "$files" -ne "$documents" ]; then
        log_error "$output_dir: $documents resources, but $files files. Two resources have the same kind and name."
        return 1
    fi
    log_info "Split $files resources from $manifest_file"
}

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    log_error "helm is not installed. Please install helm first."
    exit 1
fi

# Update all helm repos upfront so dependency update can resolve versions
log_info "Updating helm repositories..."
if ! helm repo update > /dev/null 2>&1; then
    log_warn "Failed to update helm repositories; dependency resolution may fail"
fi

# chart_namespace <source dir>
# Prints NAMESPACE from <source dir>/chart.env, or nothing. A subshell reads the
# file, so a value does not leak to the next chart.
chart_namespace() {
    local chart_env_file="$1/chart.env"
    [ -f "$chart_env_file" ] || return 0
    # shellcheck disable=SC1090
    (source "$chart_env_file" && echo "${NAMESPACE:-}")
}

# render_chart <release name> <source dir> <output file> <values file or --flag...>
render_chart() {
    local release="$1" source_dir="$2" output_file="$3"
    shift 3

    local args=()
    local arg namespace
    for arg in "$@"; do
        case "$arg" in
            --*) args+=("$arg") ;;
            *) args+=(-f "$arg") ;;
        esac
    done
    namespace="$(chart_namespace "$source_dir")"
    [ -n "$namespace" ] && args+=(--namespace "$namespace")

    helm template "$release" "$source_dir" "${args[@]}" > "$output_file"
}

rendered_count=0
error_count=0

# Old layout: kubernetes/**/sources/ renders to the sibling manifests/ folder.
while IFS= read -r chart_file; do
    [ -n "$chart_file" ] || continue
    log_info "Processing: $chart_file"

    source_dir=$(dirname "$chart_file")
    values_file="$source_dir/values.yaml"
    component_dir=$(dirname "$source_dir")
    component_name=$(basename "$component_dir")
    manifest_dir="$component_dir/manifests"
    mkdir -p "$manifest_dir"

    if [ ! -f "$values_file" ]; then
        log_error "Missing required values file: $values_file"
        ((error_count += 1))
        continue
    fi

    log_info "Updating chart dependencies in: $source_dir"
    if ! helm dependency update "$source_dir" > /dev/null 2>&1; then
        log_error "Failed to update chart dependencies for $component_name"
        ((error_count += 1))
        continue
    fi

    output_file="$manifest_dir/install.yaml"
    log_info "Rendering chart to: $output_file"
    if render_chart "$component_name" "$source_dir" "$output_file" "$values_file"; then
        log_info "✓ Successfully rendered $component_name"
        split_manifest_by_source "$output_file" "$manifest_dir"
        ((rendered_count += 1))
    else
        log_error "✗ Failed to render $component_name"
        ((error_count += 1))
    fi
done < <(find "$PROJECT_ROOT/kubernetes" -type f -path "*/sources/Chart.yaml" 2> /dev/null | sort)

# New layout: gitops/clusters/<cluster>/cluster.yaml lists the components of
# the cluster. Each component in gitops/<group>/<component>/sources/ renders
# with:
# - sources/values.yaml, the values for all clusters,
# - gitops.cluster, the content of cluster.yaml,
# - gitops/clusters/<cluster>/values/<component>.yaml, if the file exists,
# - the namespace of the component in cluster.yaml.
# The output goes to gitops/clusters/<cluster>/rendered/<component>/. The task
# deletes rendered/ first, so the folder of a removed component goes away.
# Charts with updated dependencies, one per line. No associative array: macOS has Bash 3.
updated_charts=""
while IFS= read -r cluster_file; do
    [ -n "$cluster_file" ] || continue
    cluster_dir=$(dirname "$cluster_file")
    cluster=$(basename "$cluster_dir")
    log_info "Processing cluster: $cluster"

    rm -rf "$cluster_dir/rendered"
    cluster_values="$(mktemp)"
    yq '{"gitops": {"cluster": .}}' "$cluster_file" > "$cluster_values"

    while IFS=' ' read -r group component_name namespace; do
        [ -n "$component_name" ] || continue
        source_dir="$PROJECT_ROOT/gitops/$group/$component_name/sources"
        output_dir="$cluster_dir/rendered/$component_name"

        if [ ! -f "$source_dir/Chart.yaml" ]; then
            log_error "$cluster_file: $source_dir/Chart.yaml is missing"
            ((error_count += 1))
            continue
        fi

        if ! grep -qxF -- "$source_dir" <<< "$updated_charts"; then
            log_info "Updating chart dependencies in: $source_dir"
            if ! helm dependency update "$source_dir" > /dev/null 2>&1; then
                log_error "Failed to update chart dependencies for $component_name"
                ((error_count += 1))
                continue
            fi
            updated_charts+="$source_dir"$'\n'
        fi

        values=("$cluster_values")
        [ -f "$cluster_dir/values/$component_name.yaml" ] && values+=("$cluster_dir/values/$component_name.yaml")

        output_file="$(mktemp)"
        log_info "Rendering $component_name for $cluster to: $output_dir"
        # --include-crds: the CRDs in the crds/ folder of a chart go to rendered/ too.
        if render_chart "$component_name" "$source_dir" "$output_file" "${values[@]}" --include-crds "--namespace=$namespace" &&
            split_manifest_by_resource "$output_file" "$output_dir"; then
            log_info "✓ Successfully rendered $component_name for $cluster"
            ((rendered_count += 1))
        else
            log_error "✗ Failed to render $component_name for $cluster"
            ((error_count += 1))
        fi
        rm -f "$output_file"
    done < <(yq '(.infrastructure[] | "infrastructure " + .name + " " + .namespace), (.apps[] | "apps " + .name + " " + .namespace)' "$cluster_file")
    rm -f "$cluster_values"
done < <(find "$PROJECT_ROOT/gitops/clusters" -mindepth 2 -maxdepth 2 -type f -name cluster.yaml 2> /dev/null | sort)

if [ $((rendered_count + error_count)) -eq 0 ]; then
    log_warn "No Chart.yaml files found in **/sources/ directories"
    exit 0
fi

# Summary
echo ""
log_info "===================================="
log_info "Rendering complete!"
log_info "Successfully rendered: $rendered_count"
[ $error_count -gt 0 ] && log_error "Errors: $error_count"
log_info "===================================="

exit $error_count
