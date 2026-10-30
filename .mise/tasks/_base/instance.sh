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

# docker_start
# Starts the runtime in DOCKER_RUNTIME (colima, orbstack, rancher-desktop or
# docker-desktop). Without DOCKER_RUNTIME, starts the first runtime that is
# installed, in that order. Returns 1 when no runtime is installed.
docker_start() {
    case "${DOCKER_RUNTIME:-}" in
        "") ;;
        colima) log_info "Starting Colima..." && colima start && return 0 ;;
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
        colima start
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
instance_preflight() {
    local modules
    modules="$(yq '.layers.cluster.modules[]' "$INSTANCE_DIR/instance.yaml")"

    if grep -qx 'cluster-kind' <<< "$modules"; then
        docker_ensure
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
    modules="$(yq ".layers.${layer}.modules[]" "$INSTANCE_DIR/instance.yaml" 2> /dev/null || true)"
    [ -n "$modules" ] || return 0

    cat "$INSTANCE_DIR"/*.tf | awk -v modules="$modules" '
        BEGIN { n = split(modules, list, "\n"); for (i = 1; i <= n; i++) wanted[list[i]] = 1 }
        /^[[:space:]]*(#|\/\/)/ { next }
        /^[[:space:]]*module[[:space:]]+"/ { name = $0; sub(/^[[:space:]]*module[[:space:]]+"/, "", name); sub(/".*/, "", name) }
        /source[[:space:]]*=[[:space:]]*"\.\.\/\.\.\/modules\// {
            src = $0; sub(/.*\.\.\/\.\.\/modules\//, "", src); sub(/["\/].*/, "", src)
            if (name != "" && (src in wanted)) print "-target=module." name
            name = ""
        }
    '
}

# instance_approve_flag
# Prints -auto-approve for test and demo instances. A production instance needs
# an interactive approval.
instance_approve_flag() {
    if [ "$INSTANCE_PURPOSE" != "production" ]; then
        echo "-auto-approve"
    fi
}
