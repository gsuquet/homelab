#!/usr/bin/env bash
#MISE description="Apply the secrets root module of an instance. By hand only, with no agent session."
#USAGE arg "<instance>" help="Instance name: a folder in instances/"

# Agents never run this task. Refer to docs/how-to/apply-the-secrets.md.
#
# Steps: check the preconditions; make a saved plan that replaces each seed in a new
# folder outside the repository; print a summary with no values; ask for a typed
# confirmation on the terminal; apply the saved plan. The EXIT trap deletes the folder.
#
# Environment: the age key variable, if set (SOPS_AGE_KEY_FILE, SOPS_AGE_KEY or
# SOPS_AGE_KEY_CMD), and XDG_CONFIG_HOME. Terraform gets no other variable.

set -euo pipefail

# shellcheck source=../_base/log.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/log.sh"
# shellcheck source=../_base/instance.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/instance.sh"
# shellcheck source=../_base/secrets.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/secrets.sh"

secrets_require_tty
secrets_load "${usage_instance:?}"

work="$(secrets_workdir apply)"
secrets_cleanup_on_exit "$work"
plan="$work/secrets.tfplan"

secrets_preconditions "$work"
secrets_init

# -replace writes each seed again, so a hand edit in the cluster goes away. A seed
# that is not in the state yet gets a create.
addresses="$(secrets_seed_addresses)" || exit 1
replace=()
while IFS= read -r address; do
    [ -n "$address" ] && replace+=("-replace=$address")
done <<< "$addresses"

log_info "Planning $SECRETS_REL..."
secrets_tf plan -input=false ${replace[@]+"${replace[@]}"} -out="$plan"

if ! secrets_summary "$plan"; then
    log_info "Nothing to apply."
    exit 0
fi

if ! secrets_confirm "apply $usage_instance"; then
    log_warn "Stopped. Nothing applied."
    exit 0
fi

# A saved plan applies with no prompt: the plan file is the approval.
log_info "Applying $SECRETS_REL..."
secrets_tf apply -input=false "$plan"

log_info "✓ Secrets applied: $usage_instance at $(git -C "$MISE_PROJECT_ROOT" rev-parse HEAD)"
