#!/usr/bin/env bash
#MISE description="Show the drift of the secrets root module of an instance as a saved refresh-only plan. By hand only, with no agent session."
#USAGE arg "<instance>" help="Instance name: a folder in instances/"

# Agents never run this task. It needs the age key: it decrypts in memory like
# secrets:apply. It changes nothing in the cluster or the state.
#
# The plan folder is a new folder outside the repository, with mode 0700. It holds
# secrets.tfplan and secrets.tfplan.json. The task keeps it and prints its path:
# delete it after use. The kubeconfig and TF_DATA_DIR go into another folder, which
# the EXIT trap deletes.
#
# Environment: the same as secrets:apply.

set -euo pipefail

# shellcheck source=../_base/log.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/log.sh"
# shellcheck source=../_base/instance.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/instance.sh"
# shellcheck source=../_base/secrets.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/secrets.sh"

secrets_load "${usage_instance:?}"

work="$(secrets_workdir plan-work)"
secrets_cleanup_on_exit "$work"

secrets_preconditions "$work"
secrets_init

plan_dir="$(secrets_workdir plan)"
log_info "Plan folder: $plan_dir"

secrets_tf plan -input=false -refresh-only -out="$plan_dir/secrets.tfplan"
secrets_tf show -json "$plan_dir/secrets.tfplan" > "$plan_dir/secrets.tfplan.json"

log_info "✓ Saved the plan and its JSON in $plan_dir. Delete the folder after use: rm -r $plan_dir"
