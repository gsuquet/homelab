#!/usr/bin/env bash
#MISE description="Show the changes that instance:up would make to an instance"
#USAGE arg "<instance>" help="Instance name: a folder in instances/"

set -euo pipefail

# shellcheck source=../_base/log.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/log.sh"
# shellcheck source=../_base/instance.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/instance.sh"

instance_load "${usage_instance:?}"
instance_preflight
instance_init
terraform -chdir="$INSTANCE_DIR" plan -input=false

log_info "✓ Plan complete: $usage_instance"
