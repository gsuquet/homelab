#!/usr/bin/env bash
#MISE description="Create or update an instance"
#USAGE arg "<instance>" help="Instance name: a folder in instances/"

set -euo pipefail

# shellcheck source=../_base/log.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/log.sh"
# shellcheck source=../_base/instance.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/instance.sh"

instance_load "${usage_instance:?}"
instance_init
# shellcheck disable=SC2046 # The flag is empty or one word.
terraform -chdir="$INSTANCE_DIR" apply -input=false $(instance_approve_flag)

log_info "✓ Instance is up: $usage_instance"
