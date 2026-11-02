#!/usr/bin/env bash
#MISE description="Make the labels of the repository equal to .github/labels.yml (owner only). Flags: --dry-run, --prune, --yes"
#USAGE flag "--dry-run" help="Print each create, update and delete command. No write call."
#USAGE flag "--prune" help="Delete each repository label that is not in labels.yml"
#USAGE flag "--yes" help="With --prune, delete without the y/N question"

set -euo pipefail

# shellcheck source=../_base/log.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/log.sh"

cd "$MISE_PROJECT_ROOT"

dry_run="${usage_dry_run:-false}"
prune="${usage_prune:-false}"
yes="${usage_yes:-false}"
file=".github/labels.yml"
# Always pass the repository to gh. Never let gh pick it from the git remotes.
repo="gsuquet/homelab"

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

# lower <text>: GitHub label names are not case-sensitive.
lower() {
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

# Refuse to delete without a way to ask. Do this before any write.
if [ "$prune" = "true" ] && [ "$dry_run" != "true" ] && [ "$yes" != "true" ] && [ ! -t 0 ]; then
    log_error "--prune needs a terminal for the y/N question, or the --yes flag."
    exit 1
fi

# Read name, color and description. The fields use the unit separator (0x1f),
# which is not white space, so an empty field cannot shift the others.
sep=$'\x1f'
entries="$(SEP="$sep" yq '.[] | [.name, .color, .description] | join(strenv(SEP))' "$file")"

# Validate the file before any API call.
declare -a names=()
declare -a lower_names=()
while IFS="$sep" read -r name color description extra; do
    [ -n "$name" ] || continue
    if [ -z "$color" ] || [ -z "$description" ] || [ -n "${extra:-}" ]; then
        log_error "$name: name, color and description are all required"
        exit 1
    fi
    if ! [[ "$color" =~ ^[0-9A-Fa-f]{6}$ ]]; then
        log_error "$name: color '$color' must be 6 hex digits with no '#'"
        exit 1
    fi
    if [ "${#description}" -gt 100 ]; then
        log_error "$name: description has ${#description} characters, the limit is 100"
        exit 1
    fi
    lname="$(lower "$name")"
    for seen in ${lower_names[@]+"${lower_names[@]}"}; do
        if [ "$seen" = "$lname" ]; then
            log_error "$name: duplicate label"
            exit 1
        fi
    done
    names+=("$name")
    lower_names+=("$lname")
done <<< "$entries"

[ "${#names[@]}" -gt 0 ] || {
    log_error "$file has no label"
    exit 1
}

# Read the labels of the repository before any write, so that a failure stops early.
# --limit: the default is 30.
existing="$(gh label list --repo "$repo" --json name --limit 1000 --jq '.[].name')" || {
    log_error "Cannot list the labels of $repo."
    exit 1
}

# gh label create --force creates the label, or updates its color and description.
log_info "Applying ${#names[@]} label(s) from $file to $repo..."
while IFS="$sep" read -r name color description; do
    [ -n "$name" ] || continue
    run gh label create "$name" --repo "$repo" --color "$color" --description "$description" --force
done <<< "$entries"

if [ "$prune" = "true" ]; then
    declare -a stale=()
    while IFS= read -r name; do
        [ -n "$name" ] || continue
        found=false
        lname="$(lower "$name")"
        for wanted in "${lower_names[@]}"; do
            if [ "$wanted" = "$lname" ]; then
                found=true
                break
            fi
        done
        [ "$found" = "true" ] || stale+=("$name")
    done <<< "$existing"

    if [ "${#stale[@]}" -eq 0 ]; then
        log_info "No label to delete."
    else
        log_warn "Labels to delete from $repo (not in $file):"
        printf '  %s\n' "${stale[@]}"
        log_warn "Deleting a label removes it from every issue and PR."
        if [ "$dry_run" != "true" ] && [ "$yes" != "true" ]; then
            read -r -p "Delete these ${#stale[@]} label(s)? [y/N] " answer
            if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
                log_info "No label deleted."
                exit 0
            fi
        fi
        for name in "${stale[@]}"; do
            run gh label delete "$name" --repo "$repo" --yes
        done
    fi
fi

log_info "✓ Done."
