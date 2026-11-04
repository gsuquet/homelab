#!/usr/bin/env bash
#MISE description="Destroy the secrets root module of an instance, and thus its seeds. By hand only, with no agent session."
#USAGE arg "<instance>" help="Instance name: a folder in instances/"

# Agents never run this task. Refer to docs/how-to/apply-the-secrets.md.
#
# Steps: check the preconditions; make a saved destroy plan in a new folder outside
# the repository; print a summary with no values; ask for a typed confirmation on the
# terminal; apply the saved plan. The EXIT trap deletes the folder.
#
# Environment and exit status: the same as secrets:apply.

set -euo pipefail

# shellcheck source=../_base/log.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/log.sh"
# shellcheck source=../_base/instance.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/instance.sh"
# shellcheck source=../_base/secrets.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/secrets.sh"

# The files that the task writes are for this user only.
umask 077

secrets_require_tty
secrets_load "${usage_instance:?}"

work="$(secrets_workdir destroy)"
secrets_cleanup_on_exit "$work"
plan="$work/secrets.tfplan"

secrets_preconditions "$work"
secrets_init

log_info "Planning the destroy of $SECRETS_REL..."
secrets_tf plan -input=false "$(secrets_plan_vars)" -destroy -out="$plan"

if ! secrets_summary "$plan"; then
    log_info "Nothing to destroy."
    exit 0
fi

if ! secrets_confirm "destroy $usage_instance"; then
    log_warn "Stopped. Nothing destroyed."
    exit 1
fi

log_info "Destroying $SECRETS_REL..."
secrets_tf apply -input=false "$plan"

log_info "✓ Secrets destroyed: $usage_instance"
