#!/usr/bin/env bash
#MISE description="Update the recipients or rotate the data key of the SOPS file of an instance. By hand only, with no agent session."
#USAGE arg "<instance>" help="Instance name: a folder in instances/"
#USAGE flag "--recipients" help="Run sops updatekeys, after a change to the rule of the file in .sops.yaml"
#USAGE flag "--data-key" help="Run sops rotate --in-place: a new data key for the file"

# Agents never run this task. Refer to docs/how-to/rotate-a-secret.md. A value
# rotation is secrets:edit, then secrets:apply. After a recipient leaks, run
# --recipients, then --data-key, in that order.
#
# Environment: the age key variable, if set, and XDG_CONFIG_HOME. SOPS gets no other
# variable.

set -euo pipefail

# shellcheck source=../_base/log.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/log.sh"
# shellcheck source=../_base/instance.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/instance.sh"
# shellcheck source=../_base/secrets.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/secrets.sh"

recipients="${usage_recipients:-false}"
data_key="${usage_data_key:-false}"
if [ "$recipients" = "$data_key" ]; then
    log_error "Give exactly one of --recipients and --data-key."
    exit 1
fi

secrets_load "${usage_instance:?}"
secrets_require_file
secrets_check_rules

sops_bin="$(secrets_tool sops)"
secrets_clean_env "$(dirname "$sops_bin")"

# sops reads .sops.yaml from the working folder. Refer to edit.sh.
cd "$MISE_PROJECT_ROOT"
if [ "$recipients" = "true" ]; then
    log_info "Updating the recipients of $SECRETS_FILE_REL from .sops.yaml..."
    # sops updatekeys shows the change and asks for a confirmation.
    "${SECRETS_ENV[@]}" "$sops_bin" updatekeys "$SECRETS_FILE_REL"
else
    log_info "Rotating the data key of $SECRETS_FILE_REL..."
    "${SECRETS_ENV[@]}" "$sops_bin" rotate --in-place "$SECRETS_FILE_REL"
fi

log_info "✓ Done. Next: mise run lint, then commit .sops.yaml and the SOPS file."
