#!/usr/bin/env bash
#MISE description="Update the recipients or rotate the data key of the SOPS file of an instance. By hand only, with no agent session."
#USAGE arg "<instance>" help="Instance name: a folder in instances/"
#USAGE flag "--recipients" help="Run sops updatekeys, after a change to the rule of the file in .sops.yaml"
#USAGE flag "--data-key" help="Run sops rotate --in-place: a new data key for the file"

# Agents never run this task. Refer to docs/how-to/rotate-a-secret.md. A value
# rotation is secrets:edit, then secrets:apply. After a recipient leaks, run
# --recipients, then --data-key, in that order.
#
# Environment: HOMELAB_SOPS_AGE_KEY_FILE, if set, gives the age key file. SOPS gets an
# empty HOME and only that key file.
#
# Exit status: 0 on success; else the status of sops.

set -euo pipefail

# shellcheck source=../_base/log.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/log.sh"
# shellcheck source=../_base/instance.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/instance.sh"
# shellcheck source=../_base/secrets.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/secrets.sh"

# The files that the task writes are for this user only.
umask 077

recipients="${usage_recipients:-false}"
data_key="${usage_data_key:-false}"
if [ "$recipients" = "$data_key" ]; then
    log_error "Give exactly one of --recipients and --data-key."
    exit 1
fi

secrets_require_tty
secrets_load "${usage_instance:?}"
secrets_require_file
secrets_check_rules

sops_bin="$(secrets_tool sops)" || exit 1
work="$(secrets_workdir rotate)"
secrets_cleanup_on_exit "$work"
secrets_clean_env "$work" "$(dirname "$sops_bin")"

# sops reads .sops.yaml from the working folder. Refer to edit.sh.
cd "$MISE_PROJECT_ROOT"
status=0
if [ "$recipients" = "true" ]; then
    log_info "Updating the recipients of $SECRETS_FILE_REL from .sops.yaml..."
    # sops updatekeys shows the change and asks for a confirmation on the terminal.
    "${SECRETS_ENV[@]}" "$sops_bin" updatekeys "$SECRETS_FILE_REL" < /dev/tty || status=$?
else
    log_info "Rotating the data key of $SECRETS_FILE_REL..."
    "${SECRETS_ENV[@]}" "$sops_bin" rotate --in-place "$SECRETS_FILE_REL" || status=$?
fi
if [ "$status" -ne 0 ]; then
    log_error "sops failed with status $status."
    exit "$status"
fi

log_info "✓ Done. Next: mise run lint, then commit .sops.yaml and the SOPS file."
