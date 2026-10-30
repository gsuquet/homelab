#!/usr/bin/env bash
#MISE description="Render Kubernetes manifests from Helm Charts"

set -euo pipefail

# Renders the umbrella Helm charts in sources/ folders to plain manifests:
# - kubernetes/**/sources/ renders with the sibling values.yaml to manifests/.
# - gitops/<group>/<component>/sources/ renders once for each
#   values/<instance>.yaml to rendered/<instance>/.

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

# render_chart <release name> <source dir> <output file> <values file...>
render_chart() {
    local release="$1" source_dir="$2" output_file="$3"
    shift 3

    local args=()
    local values_file namespace
    for values_file in "$@"; do
        args+=(-f "$values_file")
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

# New layout: gitops/<group>/<component>/sources/ renders once for each
# values/<instance>.yaml to rendered/<instance>/. The task deletes rendered/
# first, so the folder of a removed instance goes away.
while IFS= read -r chart_file; do
    [ -n "$chart_file" ] || continue
    log_info "Processing: $chart_file"

    source_dir=$(dirname "$chart_file")
    component_dir=$(dirname "$source_dir")
    component_name=$(basename "$component_dir")

    if [ ! -f "$source_dir/values.yaml" ]; then
        log_error "Missing required values file: $source_dir/values.yaml"
        ((error_count += 1))
        continue
    fi

    log_info "Updating chart dependencies in: $source_dir"
    if ! helm dependency update "$source_dir" > /dev/null 2>&1; then
        log_error "Failed to update chart dependencies for $component_name"
        ((error_count += 1))
        continue
    fi

    rm -rf "$component_dir/rendered"
    for instance_values in "$component_dir"/values/*.yaml; do
        [ -f "$instance_values" ] || continue
        instance="$(basename "$instance_values" .yaml)"
        output_dir="$component_dir/rendered/$instance"
        output_file="$(mktemp)"
        mkdir -p "$output_dir"

        log_info "Rendering $component_name for $instance to: $output_dir"
        if render_chart "$component_name" "$source_dir" "$output_file" "$source_dir/values.yaml" "$instance_values"; then
            split_manifest_by_source "$output_file" "$output_dir"
            log_info "✓ Successfully rendered $component_name for $instance"
            ((rendered_count += 1))
        else
            log_error "✗ Failed to render $component_name for $instance"
            ((error_count += 1))
        fi
        rm -f "$output_file"
    done
done < <(find "$PROJECT_ROOT/gitops" -type f -path "*/sources/Chart.yaml" 2> /dev/null | sort)

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
