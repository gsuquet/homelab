#!/usr/bin/env bash
#MISE description="Create or update an instance"
#USAGE arg "<instance>" help="Instance name: a folder in instances/"

set -euo pipefail

# shellcheck source=../_base/log.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/log.sh"
# shellcheck source=../_base/instance.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/instance.sh"

instance_load "${usage_instance:?}"
instance_preflight
instance_init

# The cluster layer goes first. The providers of the next layers use the cluster
# outputs. If a change replaces the cluster, those outputs are unknown in a full
# plan, and the providers then fail to read the resources that are in the state.
cluster_targets="$(instance_layer_targets cluster)"
if [ -n "$cluster_targets" ]; then
    log_info "Applying the cluster layer..."
    # shellcheck disable=SC2046,SC2086 # Each value is a list of one-word flags.
    terraform -chdir="$INSTANCE_DIR" apply -input=false $(instance_approve_flag) $cluster_targets
fi

log_info "Applying all layers..."
# shellcheck disable=SC2046 # The flag is empty or one word.
terraform -chdir="$INSTANCE_DIR" apply -input=false $(instance_approve_flag)

if instance_uses_kind; then
    kind_context_export
fi

log_info "✓ Instance is up: $usage_instance"
