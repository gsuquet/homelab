# shellcheck shell=bash
# Shared functions for the instance:* tasks. Source log.sh before this file.

# instance_load <name>
# Validates instances/<name>/instance.yaml and sets INSTANCE_DIR and INSTANCE_PURPOSE.
instance_load() {
    local name="$1"
    local file

    INSTANCE_DIR="$MISE_PROJECT_ROOT/instances/$name"
    file="$INSTANCE_DIR/instance.yaml"

    if [ ! -f "$file" ]; then
        log_error "No instance '$name': $file does not exist."
        exit 1
    fi

    if ! check-jsonschema --schemafile "$MISE_PROJECT_ROOT/schemas/instance.schema.json" "$file" > /dev/null; then
        log_error "$file does not comply with schemas/instance.schema.json."
        exit 1
    fi

    INSTANCE_PURPOSE="$(yq '.purpose' "$file")"
    export INSTANCE_DIR INSTANCE_PURPOSE
}

# colima_size
# Sets COLIMA_CPU and COLIMA_MEMORY (GiB) for the Colima VM. The defaults are 4 CPUs
# and 8 GiB, and a value that is set in the environment wins. Safety rule: if the
# host memory minus 4 GiB is less than the memory, the memory becomes that value
# and a warning names the override. The task does not refuse to start.
# COLIMA_DISK (GiB) is optional: without it, Colima keeps its own disk size, and it
# cannot shrink an existing disk.
colima_size() {
    local host_bytes host_kib host_gib="" var

    COLIMA_CPU="${COLIMA_CPU:-4}"
    COLIMA_MEMORY="${COLIMA_MEMORY:-8}"

    for var in COLIMA_CPU COLIMA_MEMORY COLIMA_DISK; do
        case "${!var:-1}" in
            *[!0-9]* | 0*)
                log_error "$var='${!var}' is not valid. Use a whole number greater than 0."
                exit 1
                ;;
        esac
    done

    if host_bytes="$(sysctl -n hw.memsize 2> /dev/null)"; then
        host_gib=$((host_bytes / 1024 / 1024 / 1024))
    elif host_kib="$(awk '/^MemTotal:/ { print $2 }' /proc/meminfo 2> /dev/null)" && [ -n "$host_kib" ]; then
        host_gib=$((host_kib / 1024 / 1024))
    fi
    if [ -n "$host_gib" ] && [ $((host_gib - 4)) -ge 1 ] && [ $((host_gib - 4)) -lt "$COLIMA_MEMORY" ]; then
        log_warn "The host has $host_gib GiB of memory. The Colima VM gets $((host_gib - 4)) GiB instead of $COLIMA_MEMORY GiB, to keep 4 GiB for the host. Set COLIMA_MEMORY to use another value."
        COLIMA_MEMORY=$((host_gib - 4))
    fi
    export COLIMA_CPU COLIMA_MEMORY
}

# colima_resize_command
# Prints the command that resizes the Colima VM to the requested size.
colima_resize_command() {
    local cmd
    colima_size
    cmd="colima stop && colima start --cpus $COLIMA_CPU --memory $COLIMA_MEMORY"
    if [ -n "${COLIMA_DISK:-}" ]; then
        cmd="$cmd --disk $COLIMA_DISK"
    fi
    echo "$cmd"
}

# colima_start
# Starts Colima with the size of colima_size.
colima_start() {
    local args=()
    colima_size
    args=(--cpus "$COLIMA_CPU" --memory "$COLIMA_MEMORY")
    if [ -n "${COLIMA_DISK:-}" ]; then
        args+=(--disk "$COLIMA_DISK")
    fi
    colima start "${args[@]}"
}

# colima_check_size
# If the default Colima VM runs with fewer CPUs or less memory than colima_size
# gives, prints a warning with the command that resizes it. It never restarts the
# VM, because a restart stops the running cluster. COLIMA_STRICT=1 makes the
# task fail instead of continue. Does nothing when Colima is not the runtime or
# does not run.
colima_check_size() {
    local info cpus memory

    [ -z "${DOCKER_RUNTIME:-}" ] || [ "$DOCKER_RUNTIME" = "colima" ] || return 0
    command -v colima > /dev/null 2>&1 || return 0

    # colima list prints one JSON object per line. Its warnings go to stderr.
    info="$(colima list --json 2> /dev/null | yq -p=json 'select(.name == "default" and .status == "Running") | [.cpus, .memory] | join(" ")' 2> /dev/null || true)"
    [ -n "$info" ] || return 0
    cpus="${info% *}"
    memory="${info#* }"

    colima_size
    if [ "$cpus" -ge "$COLIMA_CPU" ] && [ "$memory" -ge $((COLIMA_MEMORY * 1024 * 1024 * 1024)) ]; then
        return 0
    fi

    log_warn "The Colima VM has $cpus CPUs and $((memory / 1024 / 1024 / 1024)) GiB of memory. This task asks for $COLIMA_CPU CPUs and $COLIMA_MEMORY GiB (COLIMA_CPU, COLIMA_MEMORY)."
    log_warn "The task does not restart Colima, because a restart stops the running cluster. To resize the VM: $(colima_resize_command)"
    if [ "${COLIMA_STRICT:-0}" = "1" ]; then
        log_error "COLIMA_STRICT=1: stopping because the Colima VM is too small."
        exit 1
    fi
}

# docker_check_memory
# Fails if the Docker VM has less memory than KIND_MIN_MEMORY (GiB, default 4).
# Below that, the Kind control plane runs out of memory, and the apply fails with
# a TLS handshake timeout. The kernel keeps some memory, thus the check accepts
# 90% of the value.
docker_check_memory() {
    local min="${KIND_MIN_MEMORY:-4}" total

    case "$min" in
        *[!0-9]* | "" | 0*)
            log_error "KIND_MIN_MEMORY='$min' is not valid. Use a whole number of GiB greater than 0."
            exit 1
            ;;
    esac

    total="$(docker info --format '{{.MemTotal}}' 2> /dev/null || true)"
    case "$total" in
        "" | *[!0-9]*)
            log_warn "Cannot read the memory of the Docker VM. The memory check is skipped."
            return 0
            ;;
    esac

    if [ "$total" -lt $((min * 1024 * 1024 * 1024 * 9 / 10)) ]; then
        log_error "The Docker VM has $((total / 1024 / 1024)) MiB of memory. A Kind cluster needs at least $min GiB (KIND_MIN_MEMORY), else the apply fails with 'TLS handshake timeout'."
        if command -v colima > /dev/null 2>&1 && { [ -z "${DOCKER_RUNTIME:-}" ] || [ "$DOCKER_RUNTIME" = "colima" ]; }; then
            log_error "To resize the Colima VM: $(colima_resize_command)"
        else
            log_error "Increase the memory of the Docker VM in the settings of your Docker runtime."
        fi
        exit 1
    fi
}

# docker_start
# Starts the runtime in DOCKER_RUNTIME (colima, orbstack, rancher-desktop or
# docker-desktop). Without DOCKER_RUNTIME, starts the first runtime that is
# installed, in that order. Colima starts with the size of colima_size. Returns 1 when no runtime is installed.
docker_start() {
    case "${DOCKER_RUNTIME:-}" in
        "") ;;
        colima) log_info "Starting Colima..." && colima_start && return 0 ;;
        orbstack) log_info "Starting OrbStack..." && orb start && return 0 ;;
        rancher-desktop) log_info "Starting Rancher Desktop..." && rdctl start && return 0 ;;
        docker-desktop) log_info "Starting Docker Desktop..." && open -a Docker && return 0 ;;
        *)
            log_error "DOCKER_RUNTIME='$DOCKER_RUNTIME' is not valid. Use colima, orbstack, rancher-desktop or docker-desktop."
            exit 1
            ;;
    esac
    [ -z "${DOCKER_RUNTIME:-}" ] || return 1

    if command -v colima > /dev/null 2>&1; then
        log_info "Starting Colima..."
        colima_start
    elif command -v orb > /dev/null 2>&1; then
        log_info "Starting OrbStack..."
        orb start
    elif command -v rdctl > /dev/null 2>&1; then
        log_info "Starting Rancher Desktop..."
        rdctl start
    elif [ "$(uname -s)" = "Darwin" ] && [ -d "/Applications/Docker.app" ]; then
        log_info "Starting Docker Desktop..."
        open -a Docker
    else
        return 1
    fi
}

# docker_ensure
# Makes sure that Docker runs. Set DOCKER_NO_START=1 to only check.
docker_ensure() {
    local i

    if ! command -v docker > /dev/null 2>&1; then
        log_error "The docker command is missing. Kind needs it. Install it (for example: brew install docker), or open Docker Desktop once."
        exit 1
    fi

    docker info > /dev/null 2>&1 && return 0

    if [ "${DOCKER_NO_START:-0}" = "1" ] || ! docker_start; then
        log_error "Docker is not running. Kind needs it. Start Docker and try again."
        exit 1
    fi

    # Docker Desktop and Rancher Desktop return before the engine is ready.
    for i in $(seq 1 60); do
        docker info > /dev/null 2>&1 && return 0
        [ "$i" -eq 1 ] && log_info "Waiting for Docker..."
        sleep 2
    done

    log_error "Docker did not start in 120 seconds."
    exit 1
}

# instance_preflight
# Checks what the cluster module needs on this machine before Terraform runs.
# With --no-resources (used by instance:down), it only makes sure that Docker
# runs: a destroy must work on a VM that is too small.
instance_preflight() {
    if instance_uses_kind; then
        [ "${1:-}" = "--no-resources" ] || colima_check_size
        docker_ensure
        [ "${1:-}" = "--no-resources" ] || docker_check_memory
    fi
}

# instance_init
# Runs terraform init in the instance root module.
instance_init() {
    log_info "Initializing $INSTANCE_DIR..."
    terraform -chdir="$INSTANCE_DIR" init -input=false
}

# instance_layer_targets <layer>
# Prints one -target=module.<block> flag for each module block of the instance
# whose source is a module of <layer> in instance.yaml.
instance_layer_targets() {
    local layer="$1" modules
    modules="$(yq "(.layers.${layer}.modules // [])[]" "$INSTANCE_DIR/instance.yaml")"
    [ -n "$modules" ] || return 0

    # The list goes in the environment: the macOS awk rejects a newline in -v.
    cat "$INSTANCE_DIR"/*.tf | MODULES="$modules" awk '
        BEGIN { n = split(ENVIRON["MODULES"], list, "\n"); for (i = 1; i <= n; i++) wanted[list[i]] = 1 }
        /^[[:space:]]*(#|\/\/)/ { next }
        /^[[:space:]]*module[[:space:]]+"/ { name = $0; sub(/^[[:space:]]*module[[:space:]]+"/, "", name); sub(/".*/, "", name) }
        /source[[:space:]]*=[[:space:]]*"\.\.\/\.\.\/modules\// {
            src = $0; sub(/.*\.\.\/\.\.\/modules\//, "", src); sub(/["\/].*/, "", src)
            if (name != "" && (src in wanted)) print "-target=module." name
            name = ""
        }
    '
}

# instance_uses_kind
# Returns 0 when the cluster layer of the instance uses cluster-kind.
instance_uses_kind() {
    # grep reads a string, not a pipe: with pipefail, grep -q can stop the writer
    # with SIGPIPE and make the test fail.
    grep -qx 'cluster-kind' <<< "$(yq '(.layers.cluster.modules // [])[]' "$INSTANCE_DIR/instance.yaml")"
}

# kind_context_export
# Merges the kubeconfig entries of the Kind cluster (cluster, user and context
# kind-<name>) into ~/.kube/config, or into the first existing file of KUBECONFIG, and
# makes that context the current one. kind changes no other entry.
kind_context_export() {
    local name
    name="$(terraform -chdir="$INSTANCE_DIR" output -raw cluster_name)"
    log_info "Adding the kubeconfig context kind-$name..."
    kind export kubeconfig --name "$name"
}

# kind_context_remove <name>
# Removes the cluster, user and context kind-<name> from the kubeconfig, like
# kind delete cluster does. It removes only the entries that exist, and no other
# entry. If kind-<name> is the current context, no context is current after it.
kind_context_remove() {
    local entry="kind-$1" removed=0
    if ! command -v kubectl > /dev/null 2>&1; then
        log_warn "kubectl is missing: remove the kubeconfig context $entry yourself."
        return 0
    fi
    if [ "$(kubectl config current-context 2> /dev/null || true)" = "$entry" ]; then
        kubectl config unset current-context > /dev/null
    fi
    if grep -qx "$entry" <<< "$(kubectl config get-contexts -o name 2> /dev/null || true)"; then
        kubectl config delete-context "$entry" > /dev/null
        removed=1
    fi
    if grep -qx "$entry" <<< "$(kubectl config get-clusters 2> /dev/null || true)"; then
        kubectl config delete-cluster "$entry" > /dev/null
        removed=1
    fi
    if grep -qx "$entry" <<< "$(kubectl config get-users 2> /dev/null || true)"; then
        kubectl config delete-user "$entry" > /dev/null
        removed=1
    fi
    if [ "$removed" -eq 1 ]; then
        log_info "Removed the kubeconfig entries $entry."
    fi
}

# instance_approve_flag
# Prints -auto-approve for test and demo instances. A production instance needs
# an interactive approval.
instance_approve_flag() {
    if [ "$INSTANCE_PURPOSE" != "production" ]; then
        echo "-auto-approve"
    fi
}
