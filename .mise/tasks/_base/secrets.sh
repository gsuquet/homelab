# shellcheck shell=bash
# Shared functions of the secrets:* tasks. Source log.sh and instance.sh before this file.
# Only a person runs these tasks, by hand, with no agent session. Refer to
# docs/reference/secrets.md.

# The Terraform CLI configuration of the clean environment: an empty file, so no
# provider_installation, dev_overrides or plugin cache applies.
SECRETS_EMPTY_TFRC=".mise/tasks/secrets/empty.tfrc"

# The variables that tell SOPS where the age key is. The clean environment keeps
# only these, and XDG_CONFIG_HOME, which sets the folder of keys.txt.
SECRETS_KEY_VARS="SOPS_AGE_KEY_FILE SOPS_AGE_KEY SOPS_AGE_KEY_CMD XDG_CONFIG_HOME"

# secrets_load <instance>
# Loads the instance and sets SECRETS_REL (the secrets root module, relative to the
# repository root), SECRETS_DIR and SECRETS_FILE_REL (the SOPS file).
secrets_load() {
    local name="$1"

    # The name goes into paths and into the confirmation text.
    if ! [[ "$name" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ ]]; then
        log_error "Instance name '$name' is not valid. Use the name of a folder in instances/."
        exit 1
    fi
    instance_load "$name"

    SECRETS_REL="instances/$name/secrets"
    SECRETS_DIR="$MISE_PROJECT_ROOT/$SECRETS_REL"
    SECRETS_FILE_REL="$SECRETS_REL/secrets.sops.yaml"
    export SECRETS_REL SECRETS_DIR SECRETS_FILE_REL
}

# secrets_require_dir
# Stops if the secrets root module of the instance does not exist.
secrets_require_dir() {
    if [ ! -d "$SECRETS_DIR" ]; then
        log_error "$SECRETS_REL does not exist. The instance has no secrets root module."
        exit 1
    fi
}

# secrets_require_file
# Stops if the SOPS file of the instance does not exist.
secrets_require_file() {
    if [ ! -f "$MISE_PROJECT_ROOT/$SECRETS_FILE_REL" ]; then
        log_error "$SECRETS_FILE_REL does not exist."
        exit 1
    fi
}

# secrets_check_rules
# Stops if .sops.yaml is missing or still has a placeholder recipient.
secrets_check_rules() {
    local file="$MISE_PROJECT_ROOT/.sops.yaml"

    if [ ! -f "$file" ]; then
        log_error ".sops.yaml does not exist."
        exit 1
    fi
    if grep -q 'PLACEHOLDER' "$file"; then
        log_error ".sops.yaml has a placeholder recipient. Put the public keys of the scope key and the recovery key in it first."
        exit 1
    fi
}

# secrets_require_tty
# Stops when the process has no terminal. This stops a plain tool call, CI and a
# pipe. It does not stop a pseudo-terminal (script, expect) or a direct terraform
# command.
secrets_require_tty() {
    if ! { : < /dev/tty; } 2> /dev/null; then
        log_error "This task needs a terminal (/dev/tty). Run it by hand, with no agent session."
        exit 1
    fi
}

# secrets_confirm <text>
# Asks the person to type <text> on the terminal. Returns 1 for each other answer.
secrets_confirm() {
    local expected="$1" answer=""

    printf 'Type "%s" to continue, or anything else to stop: ' "$expected" > /dev/tty
    IFS= read -r answer < /dev/tty || true
    [ "$answer" = "$expected" ]
}

# secrets_workdir <label>
# Makes a new folder outside the repository, with mode 0700 (umask 077), and prints its
# path. The caller deletes it.
secrets_workdir() {
    umask 077
    local base="${TMPDIR:-/tmp}"
    mktemp -d "${base%/}/secrets-$1.XXXXXX"
}

# secrets_cleanup
# Deletes the folder in SECRETS_CLEANUP_DIR. The EXIT trap calls it.
secrets_cleanup() {
    if [ -n "${SECRETS_CLEANUP_DIR:-}" ] && [ -d "$SECRETS_CLEANUP_DIR" ]; then
        rm -rf "$SECRETS_CLEANUP_DIR"
    fi
}

# secrets_cleanup_on_exit <folder>
# Deletes <folder> on each exit: success, failure, Ctrl-C (INT) and TERM.
secrets_cleanup_on_exit() {
    SECRETS_CLEANUP_DIR="$1"
    trap secrets_cleanup EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
}

# secrets_tool <name>
# Prints the absolute path of the mise tool <name>. The clean environment has no
# mise shims on PATH.
secrets_tool() {
    local path
    if ! path="$(mise which "$1" 2> /dev/null)" || [ ! -x "$path" ]; then
        log_error "Cannot find $1. Run 'mise install' in the repository."
        exit 1
    fi
    echo "$path"
}

# secrets_clean_env <PATH folder>
# Sets SECRETS_ENV: an env -i command prefix with PATH (<PATH folder>, /usr/bin and
# /bin), HOME, and each variable of SECRETS_KEY_VARS that is set.
secrets_clean_env() {
    local var
    SECRETS_ENV=(env -i "PATH=$1:/usr/bin:/bin" "HOME=$HOME")
    for var in $SECRETS_KEY_VARS; do
        if [ -n "${!var+set}" ]; then
            SECRETS_ENV+=("$var=${!var}")
        fi
    done
}

# secrets_terraform_env <work folder> <kubeconfig>
# Sets TF_BIN and SECRETS_ENV for Terraform: the clean environment, plus TF_INPUT=0,
# the empty CLI configuration, a new TF_DATA_DIR in <work folder>, and the kubeconfig
# for the provider (variable kubeconfig_path of the secrets root module).
secrets_terraform_env() {
    local tfrc="$MISE_PROJECT_ROOT/$SECRETS_EMPTY_TFRC"

    if [ ! -f "$tfrc" ] || [ -s "$tfrc" ]; then
        log_error "$SECRETS_EMPTY_TFRC must exist and be empty."
        exit 1
    fi

    TF_BIN="$(secrets_tool terraform)"
    secrets_clean_env "$(dirname "$TF_BIN")"
    SECRETS_ENV+=(
        "TF_INPUT=0"
        "TF_CLI_CONFIG_FILE=$tfrc"
        "TF_DATA_DIR=$1/tf-data"
        "TF_VAR_kubeconfig_path=$2"
    )
}

# secrets_tf <terraform args...>
# Runs Terraform in the secrets root module, in the clean environment, with standard
# input from /dev/null.
secrets_tf() {
    "${SECRETS_ENV[@]}" "$TF_BIN" -chdir="$SECRETS_DIR" "$@" < /dev/null
}

# secrets_check_tree
# Stops if the working tree has a change or an untracked file, or if the checked-out
# commit is not on origin/main. The tasks run only after the merge.
secrets_check_tree() {
    local changes

    changes="$(git -C "$MISE_PROJECT_ROOT" status --porcelain --untracked-files=all)"
    if [ -n "$changes" ]; then
        log_error "The working tree is not clean. Commit, stash or remove these files first:"
        echo "$changes" >&2
        exit 1
    fi
    if ! git -C "$MISE_PROJECT_ROOT" merge-base --is-ancestor HEAD origin/main 2> /dev/null; then
        log_error "The commit $(git -C "$MISE_PROJECT_ROOT" rev-parse --short HEAD) is not on origin/main. Run the task from main after the merge: git switch main && git pull --ff-only"
        exit 1
    fi
}

# secrets_check_kubeconfig <file>
# Stops if the kubeconfig has more or less than one cluster, a server that is not a
# loopback address, or an exec or proxy-url key.
secrets_check_kubeconfig() {
    local file="$1" count server found

    count="$(yq '.clusters | length' "$file")"
    if [ "$count" != "1" ]; then
        log_error "The kubeconfig has $count clusters. It must have exactly one."
        exit 1
    fi
    server="$(yq '.clusters[0].cluster.server' "$file")"
    if ! [[ "$server" =~ ^https://(127\.0\.0\.1|localhost|\[::1\]):[0-9]+/?$ ]]; then
        log_error "The kubeconfig server '$server' is not a loopback address."
        exit 1
    fi
    # exec runs a command, and proxy-url sends the API traffic to another host.
    found="$(yq '[.. | select(tag == "!!map") | select(has("exec") or has("proxy-url"))] | length' "$file")"
    if [ "$found" != "0" ]; then
        log_error "The kubeconfig has an exec or a proxy-url key."
        exit 1
    fi
}

# secrets_kubeconfig <file>
# Writes the kubeconfig of the Kind cluster of the instance to <file>, and checks it.
# Stops if the cluster is not up.
secrets_kubeconfig() {
    local file="$1" name

    if ! instance_uses_kind; then
        log_error "The secrets tasks support only an instance that uses cluster-kind."
        exit 1
    fi
    if ! command -v kind > /dev/null 2>&1 || ! command -v kubectl > /dev/null 2>&1; then
        log_error "The secrets tasks need kind and kubectl."
        exit 1
    fi

    # The output of the instance root module. No init is necessary for a local state.
    name="$(TF_CLI_CONFIG_FILE="$MISE_PROJECT_ROOT/$SECRETS_EMPTY_TFRC" TF_INPUT=0 \
        terraform -chdir="$INSTANCE_DIR" output -raw cluster_name 2> /dev/null < /dev/null || true)"
    if [ -z "$name" ]; then
        log_error "Cannot read the cluster_name output of $INSTANCE_DIR. Run 'mise run instance:up $(basename "$INSTANCE_DIR")' first."
        exit 1
    fi
    if ! kind get kubeconfig --name "$name" > "$file" 2> /dev/null; then
        log_error "The cluster $name is not up: kind cannot get its kubeconfig."
        exit 1
    fi
    secrets_check_kubeconfig "$file"
    if ! kubectl --kubeconfig "$file" get --raw /readyz > /dev/null 2>&1; then
        log_error "The cluster $name is not ready: /readyz failed."
        exit 1
    fi
}

# secrets_seed_consumers
# Prints the keys of the seed map: the seeds argument of module "secret_seeds" in
# main.tf of the secrets root module. Stops if the map is not a literal map. The
# errors go to stderr, because the caller reads stdout.
secrets_seed_consumers() {
    local parsed count kind

    if ! parsed="$(conftest parse --parser hcl2 "$SECRETS_DIR/main.tf")"; then
        log_error "Cannot parse $SECRETS_REL/main.tf." >&2
        exit 1
    fi
    count="$(yq -p=json '.module.secret_seeds | length' <<< "$parsed")"
    if [ "$count" != "1" ]; then
        log_error "$SECRETS_REL/main.tf must have exactly one module \"secret_seeds\"." >&2
        exit 1
    fi
    kind="$(yq -p=json '.module.secret_seeds[0].seeds | type' <<< "$parsed")"
    if [ "$kind" != "!!map" ]; then
        log_error "The seeds argument of module \"secret_seeds\" must be a literal map in $SECRETS_REL/main.tf." >&2
        exit 1
    fi
    yq -p=json '.module.secret_seeds[0].seeds | keys | .[]' <<< "$parsed"
}

# secrets_check_seed_namespaces <kubeconfig>
# Stops if the seed namespace secret-seeds-<consumer> of a consumer in the seed map is
# not in the cluster.
secrets_check_seed_namespaces() {
    local file="$1" consumers consumer missing=0

    consumers="$(secrets_seed_consumers)" || exit 1
    while IFS= read -r consumer; do
        [ -n "$consumer" ] || continue
        if ! [[ "$consumer" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ ]]; then
            log_error "The seed map key '$consumer' is not a valid namespace name."
            exit 1
        fi
        if ! kubectl --kubeconfig "$file" get namespace "secret-seeds-$consumer" > /dev/null 2>&1; then
            log_error "The seed namespace secret-seeds-$consumer is not in the cluster. Wait for Argo CD to sync external-secrets."
            missing=1
        fi
    done <<< "$consumers"
    if [ "$missing" -ne 0 ]; then
        exit 1
    fi
}

# secrets_preconditions <work folder>
# Checks the preconditions of secrets:plan, secrets:apply and secrets:destroy, in this
# order, and sets up the Terraform environment. Stops at the first failure.
secrets_preconditions() {
    local work="$1" kubeconfig="$1/kubeconfig"

    secrets_require_dir
    if [ ! -f "$SECRETS_DIR/.terraform.lock.hcl" ]; then
        log_error "$SECRETS_REL/.terraform.lock.hcl does not exist."
        exit 1
    fi
    secrets_check_tree
    secrets_kubeconfig "$kubeconfig"
    secrets_check_seed_namespaces "$kubeconfig"
    secrets_terraform_env "$work" "$kubeconfig"
}

# secrets_init
# Runs terraform init in the new TF_DATA_DIR, against the lock file.
secrets_init() {
    log_info "Initializing $SECRETS_REL in a new TF_DATA_DIR..."
    secrets_tf init -input=false -lockfile=readonly > /dev/null
}

# secrets_seed_addresses
# Prints the address of each seed in the state of the secrets root module.
secrets_seed_addresses() {
    [ -f "$SECRETS_DIR/terraform.tfstate" ] || return 0
    secrets_tf state list | { grep -E '^module\.secret_seeds\.kubernetes_secret_v1\.' || true; }
}

# secrets_summary <plan file>
# Prints the address and the actions of each resource change of the plan, and no
# value. Returns 1 when the plan has no change.
secrets_summary() {
    local summary

    # The caller tests the status, so errexit is off here: each failure is explicit.
    if ! summary="$(secrets_tf show -json "$1" |
        yq -p=json '.resource_changes // [] | .[] | select((.change.actions | join(",")) != "no-op") | .address + "  " + (.change.actions | join(","))')"; then
        log_error "Cannot read the plan for the summary."
        exit 1
    fi
    if [ -z "$summary" ]; then
        log_info "The plan has no change."
        return 1
    fi
    log_info "Summary of the plan (address and actions only):"
    echo "$summary"
}
