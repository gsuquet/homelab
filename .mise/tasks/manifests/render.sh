#!/usr/bin/env bash
#MISE description="Render Kubernetes manifests from Helm Charts"

set -euo pipefail

# Script to render umbrella Helm charts from sources to manifests
# Finds all **/sources/Chart.yaml files in the project and renders them using
# the sibling values.yaml into **/manifests/install.yaml

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! PROJECT_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to log messages
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

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
            ((file_count+=1))
        fi
    }

    while IFS= read -r line || [ -n "$line" ]; do
        if [[ "$line" =~ ^#\ Source:\ (.+)$ ]]; then
            flush_current_resource

            current_file="$(source_comment_to_filename "${BASH_REMATCH[1]}")"
            > "$temp_file"
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

# Find all Chart.yaml files in sources directories
chart_files=$(find "$PROJECT_ROOT" -type f -path "*/sources/Chart.yaml")

if [ -z "$chart_files" ]; then
    log_warn "No Chart.yaml files found in **/sources/ directories"
    exit 0
fi

rendered_count=0
error_count=0

# Process each chart file
while IFS= read -r chart_file; do
    log_info "Processing: $chart_file"

    # Get the directory containing the chart file
    source_dir=$(dirname "$chart_file")
    values_file="$source_dir/values.yaml"

    # Get the parent directory (should be the component directory)
    component_dir=$(dirname "$source_dir")
    component_name=$(basename "$component_dir")

    # Create manifests directory if it doesn't exist
    manifest_dir="$component_dir/manifests"
    mkdir -p "$manifest_dir"

    if [ ! -f "$values_file" ]; then
        log_error "Missing required values file: $values_file"
        ((error_count+=1))
        continue
    fi

    # Update dependencies for umbrella chart
    log_info "Updating chart dependencies in: $source_dir"
    if ! helm dependency update "$source_dir" > /dev/null 2>&1; then
        log_error "Failed to update chart dependencies for $component_name"
        ((error_count+=1))
        continue
    fi

    # Render the chart
    output_file="$manifest_dir/install.yaml"
    log_info "Rendering chart to: $output_file"

    helm_extra_args=""
    chart_env_file="$source_dir/chart.env"
    if [ -f "$chart_env_file" ]; then
        log_info "Loading chart.env from: $chart_env_file"
        # shellcheck disable=SC1090
        source "$chart_env_file"
        [ -n "${NAMESPACE:-}" ] && helm_extra_args="$helm_extra_args --namespace $NAMESPACE"
    fi

    # shellcheck disable=SC2086
    if helm template "$component_name" "$source_dir" -f "$values_file" $helm_extra_args > "$output_file"; then
        log_info "✓ Successfully rendered $component_name"
        split_manifest_by_source "$output_file" "$manifest_dir"
        ((rendered_count+=1))
    else
        log_error "✗ Failed to render $component_name"
        ((error_count+=1))
    fi

done <<< "$chart_files"

# Summary
echo ""
log_info "===================================="
log_info "Rendering complete!"
log_info "Successfully rendered: $rendered_count"
[ $error_count -gt 0 ] && log_error "Errors: $error_count"
log_info "===================================="

exit $error_count
