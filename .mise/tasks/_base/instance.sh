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
