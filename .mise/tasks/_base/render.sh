# shellcheck shell=bash
# Functions of manifests:render. The task and lint:render-test source this file.
# The file needs yq and log.sh.

# split_manifest_by_resource <manifest file> <output dir>
# Writes one file for each resource: <kind>-<name>.yaml, in lower case. The file
# name does not change when the chart moves a resource to another template.
# Each CustomResourceDefinition gets the annotation
# argocd.argoproj.io/sync-wave: "-1", also when the chart sets another value.
# The umbrella chart cannot annotate the CRDs of a subchart, and many CRD charts
# have no value for it. A CRD in an earlier wave than the rest of the component
# makes Argo CD apply it before the custom resources of the same component.
# A resource from an upstream chart gets the prefix upstream--: the second
# segment of its "# Source:" path is charts, for example
# argocd/charts/argo-cd/templates/argocd-cm.yaml. The Conftest policies read the
# origin from the file name, because Conftest drops comments.
split_manifest_by_resource() {
    local manifest_file="$1"
    local output_dir="$2"
    local documents duplicates chunks chunk source prefix files
    # The file name without the prefix. The duplicate guard uses it: two
    # resources with the same kind and name fail, also when only one of them
    # comes from an upstream chart.
    local name_expression='(.kind | downcase) + "-" + (.metadata.name | downcase | sub("[^a-z0-9.-]", "-")) + ".yaml"'

    local crd_wave_expression='with(select(.kind == "CustomResourceDefinition"); .metadata.annotations["argocd.argoproj.io/sync-wave"] = "-1")'

    mkdir -p "$output_dir"
    documents="$(yq ea '[select(. != null)] | length' "$manifest_file")"
    duplicates="$(yq ea "[select(. != null) | $name_expression] | group_by(.) | map(select(length > 1) | .[0]) | .[]" "$manifest_file")"
    if [ -n "$duplicates" ]; then
        log_error "$output_dir: two resources have the same kind and name: $duplicates"
        return 1
    fi

    # One chunk for each "# Source:" comment of helm template. The chunk keeps
    # the comment, and chunk-<n>.yaml.source holds the source path. The "---"
    # before the next comment makes an empty document, which yq ignores.
    chunks="$(mktemp -d)"
    awk -v dir="$chunks" '
        /^# Source: / {
            if (file != "") close(file)
            n++
            file = sprintf("%s/chunk-%04d.yaml", dir, n)
            print substr($0, 11) > (file ".source")
            close(file ".source")
            print "---" > file
        }
        n > 0 { print > file }
    ' "$manifest_file"

    for chunk in "$chunks"/chunk-*.yaml; do
        [ -f "$chunk" ] || continue
        source="$(cat "$chunk.source")"
        prefix=""
        if [ "$(cut -d/ -f2 <<< "$source")" = "charts" ]; then
            prefix="upstream--"
        fi
        (cd "$output_dir" && PREFIX="$prefix" yq "select(. != null) | $crd_wave_expression" -s "strenv(PREFIX) + $name_expression" "$chunk")
    done
    rm -rf "$chunks"

    # A resource without a "# Source:" comment has no file.
    files="$(find "$output_dir" -maxdepth 1 -type f -name '*.yaml' | wc -l)"
    if [ "$files" -ne "$documents" ]; then
        log_error "$output_dir: $documents resources, but $files files. Each resource must have a # Source: comment."
        return 1
    fi
    log_info "Split $files resources from $manifest_file"
}
