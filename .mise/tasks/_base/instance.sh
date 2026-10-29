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
# Starts the first Docker runtime that is installed: Colima, OrbStack,
# Rancher Desktop or Docker Desktop. Returns 1 when no runtime is installed.
docker_start() {
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

# instance_approve_flag
# Prints -auto-approve for test and demo instances. A production instance needs
# an interactive approval.
instance_approve_flag() {
    if [ "$INSTANCE_PURPOSE" != "production" ]; then
        echo "-auto-approve"
    fi
}
