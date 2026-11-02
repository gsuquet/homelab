#!/usr/bin/env bash
#MISE description="Make the labels of the repository equal to .github/labels.yml (owner only). Flags: --dry-run, --prune"
#USAGE flag "--dry-run" help="Print each create, update and delete command. No write call."
#USAGE flag "--prune" help="Delete each repository label that is not in labels.yml"

set -euo pipefail

# shellcheck source=../_base/log.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/log.sh"

cd "$MISE_PROJECT_ROOT"

dry_run="${usage_dry_run:-false}"
prune="${usage_prune:-false}"
file=".github/labels.yml"

# run <command...>: run the command, or only print it in dry-run mode.
run() {
    if [ "$dry_run" = "true" ]; then
        printf '[DRY-RUN]'
        printf ' %q' "$@"
        printf '\n'
    else
        "$@"
    fi
}

# Read name, color and description. The three fields are tab-separated.
entries="$(yq '.[] | [.name, .color, .description] | @tsv' "$file")"

# Validate the file before any API call.
declare -a names=()
while IFS=$'\t' read -r name color description; do
    [ -n "$name" ] || continue
    if ! [[ "$color" =~ ^[0-9A-Fa-f]{6}$ ]]; then
        log_error "$name: color '$color' must be 6 hex digits with no '#'"
        exit 1
    fi
    if [ "${#description}" -gt 100 ]; then
        log_error "$name: description has ${#description} characters, the limit is 100"
        exit 1
    fi
    for seen in ${names[@]+"${names[@]}"}; do
        if [ "$seen" = "$name" ]; then
            log_error "$name: duplicate label"
            exit 1
        fi
    done
    names+=("$name")
done <<< "$entries"

[ "${#names[@]}" -gt 0 ] || {
    log_error "$file has no label"
    exit 1
}

# gh label create --force creates the label, or updates its color and description.
log_info "Applying ${#names[@]} label(s) from $file..."
while IFS=$'\t' read -r name color description; do
    [ -n "$name" ] || continue
    run gh label create "$name" --color "$color" --description "$description" --force
done <<< "$entries"

if [ "$prune" = "true" ]; then
    # --limit: the default is 30.
    existing="$(gh label list --json name --limit 1000 --jq '.[].name')"
    declare -a stale=()
    while IFS= read -r name; do
        [ -n "$name" ] || continue
        found=false
        for wanted in "${names[@]}"; do
            if [ "$wanted" = "$name" ]; then
                found=true
                break
            fi
        done
        [ "$found" = "true" ] || stale+=("$name")
    done <<< "$existing"

    if [ "${#stale[@]}" -eq 0 ]; then
        log_info "No label to delete."
    else
        log_warn "Labels to delete (not in $file):"
        printf '  %s\n' "${stale[@]}"
        for name in "${stale[@]}"; do
            run gh label delete "$name" --yes
        done
    fi
fi

log_info "✓ Done."
