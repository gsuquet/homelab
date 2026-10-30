#!/usr/bin/env bash
#MISE description="Destroy an instance"
#USAGE arg "<instance>" help="Instance name: a folder in instances/"

set -euo pipefail

# shellcheck source=../_base/log.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/log.sh"
# shellcheck source=../_base/instance.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/instance.sh"

instance_load "${usage_instance:?}"
instance_preflight
instance_init

# Read the cluster name before the destroy removes it from the state.
kind_name=""
if instance_uses_kind; then
    kind_name="$(terraform -chdir="$INSTANCE_DIR" output -raw cluster_name 2> /dev/null || true)"
fi

# shellcheck disable=SC2046 # The flag is empty or one word.
terraform -chdir="$INSTANCE_DIR" destroy -input=false $(instance_approve_flag)

if [ -n "$kind_name" ]; then
    kind_context_remove "$kind_name"
fi

log_info "✓ Instance is down: $usage_instance"
