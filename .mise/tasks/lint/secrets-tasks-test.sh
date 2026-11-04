#!/usr/bin/env bash
#MISE description="Test the precondition checks of the secrets tasks against fixtures"

# The test sources .mise/tasks/_base/secrets.sh and runs its checks against files in a
# temporary folder: kubeconfig files, seed maps, a Git clone of a local repository, and
# a fake kubectl. It needs no cluster, no network and no age key.

set -euo pipefail

# shellcheck source=../_base/log.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/log.sh"
# shellcheck source=../_base/instance.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/instance.sh"
# shellcheck source=../_base/secrets.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/secrets.sh"

tmp="$(mktemp -d "${TMPDIR:-/tmp}/secrets-test.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
failures=0
cases=0

# expect <pass|fail> <name> <command...>
# Runs the command in a subshell, because the checks exit on a failure.
expect() {
    local want="$1" name="$2" status=0 out
    shift 2
    cases=$((cases + 1))
    out="$( ("$@") 2>&1)" || status=$?
    if { [ "$want" = pass ] && [ "$status" -eq 0 ]; } || { [ "$want" = fail ] && [ "$status" -ne 0 ]; }; then
        log_info "ok ($want): $name"
    else
        log_error "expected $want, got status $status: $name"
        echo "$out" >&2
        failures=$((failures + 1))
    fi
}

# ---- secrets_check_kubeconfig ----
kc="$tmp/kc"
mkdir "$kc"
# kubeconfig <server> [extra cluster line] [extra user line]
kubeconfig() {
    cat << EOF
apiVersion: v1
kind: Config
preferences: {}
current-context: kind-x
clusters:
  - name: kind-x
    cluster:
      server: $1
      certificate-authority-data: AAAA
${2:-}
contexts:
  - name: kind-x
    context:
      cluster: kind-x
      user: kind-x
users:
  - name: kind-x
    user:
      client-certificate-data: AAAA
      client-key-data: AAAA
${3:-}
EOF
}
kubeconfig 'https://127.0.0.1:6443' > "$kc/kind.yaml"
kubeconfig 'https://localhost:6443' > "$kc/localhost.yaml"
kubeconfig 'https://[::1]:6443' > "$kc/ipv6.yaml"
kubeconfig 'https://10.0.0.5:6443' > "$kc/remote.yaml"
kubeconfig 'https://127.0.0.1.nip.io:6443' > "$kc/nip.yaml"
kubeconfig 'http://127.0.0.1:6443' > "$kc/http.yaml"
kubeconfig 'https://127.0.0.1:6443' '      proxy-url: http://proxy:3128' > "$kc/proxy.yaml"
kubeconfig 'https://127.0.0.1:6443' '      insecure-skip-tls-verify: true' > "$kc/insecure.yaml"
kubeconfig 'https://127.0.0.1:6443' '' '      exec: {command: /bin/sh, apiVersion: client.authentication.k8s.io/v1}' > "$kc/exec.yaml"
kubeconfig 'https://127.0.0.1:6443' '' '      auth-provider: {name: oidc}' > "$kc/auth-provider.yaml"
kubeconfig 'https://127.0.0.1:6443' '' '      tokenFile: /tmp/token' > "$kc/token-file.yaml"
yq '.clusters += [.clusters[0] | .name = "two"]' "$kc/kind.yaml" > "$kc/two.yaml"
yq '.preferences.colors = true' "$kc/kind.yaml" > "$kc/preferences.yaml"
yq '.extensions = []' "$kc/kind.yaml" > "$kc/extensions.yaml"

for f in kind localhost ipv6; do
    expect pass "kubeconfig $f" secrets_check_kubeconfig "$kc/$f.yaml"
done
for f in remote nip http proxy insecure exec auth-provider token-file two preferences extensions; do
    expect fail "kubeconfig $f" secrets_check_kubeconfig "$kc/$f.yaml"
done

# ---- secrets_seed_consumers and secrets_check_seed_namespaces ----
SECRETS_REL="instances/test/secrets"
SECRETS_DIR="$tmp/seeds"
mkdir -p "$SECRETS_DIR" "$tmp/bin"
# A fake kubectl: only secret-seeds-thunder and secret-seeds-oc-sandbox exist.
cat > "$tmp/bin/kubectl" << 'EOF'
#!/bin/sh
case "$*" in
    *" namespace secret-seeds-thunder" | *" namespace secret-seeds-oc-sandbox") exit 0 ;;
    *) echo 'Error from server (NotFound)' >&2; exit 1 ;;
esac
EOF
chmod +x "$tmp/bin/kubectl"
PATH="$tmp/bin:$PATH"

# seeds <seeds argument>
seeds() {
    printf 'module "secret_seeds" {\n  source = "../../../modules/bootstrap-secret-seeds"\n  seeds  = %s\n}\n' "$1" > "$SECRETS_DIR/main.tf"
}
consumers_are() {
    [ "$(secrets_seed_consumers | tr '\n' ' ')" = "$1" ]
}

seeds '{
    thunder      = ["oauth-client-secret"]
    "oc-sandbox" = ["test"]
  }'
expect pass "seed map keys" consumers_are "oc-sandbox thunder "
expect pass "seed namespaces exist" secrets_check_seed_namespaces "$kc/kind.yaml"
seeds '{}'
expect pass "empty seed map" secrets_check_seed_namespaces "$kc/kind.yaml"
seeds '{
    thunder                    = ["a"]
    "openchoreo-control-plane" = ["b"]
  }'
expect fail "missing seed namespace" secrets_check_seed_namespaces "$kc/kind.yaml"
seeds '{
    "Bad_Key" = ["a"]
  }'
expect fail "invalid seed map key" secrets_check_seed_namespaces "$kc/kind.yaml"
seeds 'merge(local.a, local.b)'
expect fail "seed map is an expression" secrets_check_seed_namespaces "$kc/kind.yaml"
seeds 'local.seeds'
expect fail "seed map is a local" secrets_check_seed_namespaces "$kc/kind.yaml"
printf 'module "other" {\n  source = "x"\n}\n' > "$SECRETS_DIR/main.tf"
expect fail "no module secret_seeds" secrets_check_seed_namespaces "$kc/kind.yaml"

# ---- secrets_check_tree ----
git_t() {
    git -c user.name=test -c user.email=test@example.com -c commit.gpgsign=false \
        -c init.defaultBranch=main "$@"
}
git_t init --quiet --bare "$tmp/origin.git"
git_t clone --quiet "$tmp/origin.git" "$tmp/repo" 2> /dev/null
mkdir -p "$tmp/repo/instances/test/secrets" "$tmp/repo/modules/bootstrap-secret-seeds"
cp "$MISE_PROJECT_ROOT/.gitignore" "$tmp/repo/.gitignore"
echo '# test' > "$tmp/repo/instances/test/secrets/main.tf"
echo '# test' > "$tmp/repo/modules/bootstrap-secret-seeds/main.tf"
git_t -C "$tmp/repo" add -A
git_t -C "$tmp/repo" commit --quiet -m base
git_t -C "$tmp/repo" push --quiet origin main 2> /dev/null

tree_check() {
    MISE_PROJECT_ROOT="$tmp/repo" secrets_check_tree
}
in_repo() {
    (cd "$tmp/repo" && "$@")
}

expect pass "tree at the tip of main" tree_check
echo state > "$tmp/repo/instances/test/secrets/terraform.tfstate"
echo state > "$tmp/repo/instances/test/secrets/terraform.tfstate.backup"
expect pass "tree with the local state" tree_check
echo change >> "$tmp/repo/instances/test/secrets/main.tf"
expect fail "tree with a change" tree_check
in_repo git checkout --quiet -- instances/test/secrets/main.tf
touch "$tmp/repo/untracked.txt"
expect fail "tree with an untracked file" tree_check
rm "$tmp/repo/untracked.txt"
for f in instances/test/secrets/terraform.tfvars instances/test/secrets/x.auto.tfvars \
    instances/test/secrets/override.tf instances/test/secrets/provider_override.tf \
    modules/bootstrap-secret-seeds/main_override.tf; do
    touch "$tmp/repo/$f"
    expect fail "tree with the ignored file $f" tree_check
    rm "$tmp/repo/$f"
done
mkdir -p "$tmp/repo/instances/test/secrets/.terraform"
touch "$tmp/repo/instances/test/secrets/.terraform/x"
expect fail "tree with a .terraform folder" tree_check
rm -r "$tmp/repo/instances/test/secrets/.terraform"
expect pass "tree after the clean-up" tree_check

# A commit that is not on origin, and a ref that moves only in the clone.
git_t -C "$tmp/repo" switch --quiet -c local
git_t -C "$tmp/repo" commit --quiet --allow-empty -m local
git_t -C "$tmp/repo" update-ref refs/remotes/origin/main HEAD
expect fail "tree with a local commit and a moved origin/main" tree_check
git_t -C "$tmp/repo" switch --quiet main
# An old commit of main.
git_t clone --quiet "$tmp/origin.git" "$tmp/other" 2> /dev/null
git_t -C "$tmp/other" commit --quiet --allow-empty -m newer
git_t -C "$tmp/other" push --quiet origin main 2> /dev/null
expect fail "tree behind the tip of main" tree_check
git_t -C "$tmp/repo" pull --quiet --ff-only 2> /dev/null
expect pass "tree after the pull" tree_check
git_t -C "$tmp/repo" remote set-url origin "$tmp/missing.git"
expect fail "tree when the fetch fails" tree_check

# ---- secrets_key_file and secrets_clean_env ----
mkdir -p "$tmp/home/.config/sops/age" "$tmp/home/Library/Application Support/sops/age" "$tmp/xdg/sops/age"
key_is() {
    [ "$(secrets_key_file)" = "$1" ]
}
key_default() {
    unset XDG_CONFIG_HOME HOMELAB_SOPS_AGE_KEY_FILE
    HOME="$tmp/home"
    key_is "$default"
}
key_xdg() {
    unset HOMELAB_SOPS_AGE_KEY_FILE
    HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/xdg"
    key_is "$tmp/xdg/sops/age/keys.txt"
}
key_homelab() {
    HOME="$tmp/home" HOMELAB_SOPS_AGE_KEY_FILE="$tmp/other-key.txt"
    export SOPS_AGE_KEY_FILE=/nowhere
    key_is "$tmp/other-key.txt"
}
key_missing() {
    unset XDG_CONFIG_HOME HOMELAB_SOPS_AGE_KEY_FILE
    HOME="$tmp/empty-home"
    secrets_key_file
}
if [ "$(uname -s)" = "Darwin" ]; then
    default="$tmp/home/Library/Application Support/sops/age/keys.txt"
else
    default="$tmp/home/.config/sops/age/keys.txt"
fi
expect fail "no key file" key_missing
touch "$tmp/home/.config/sops/age/keys.txt" "$tmp/home/Library/Application Support/sops/age/keys.txt" "$tmp/xdg/sops/age/keys.txt" "$tmp/other-key.txt"
expect pass "default key file" key_default
expect pass "key file in XDG_CONFIG_HOME" key_xdg
expect pass "HOMELAB_SOPS_AGE_KEY_FILE wins, SOPS_AGE_KEY_FILE does not count" key_homelab

clean_env_is_minimal() {
    local work="$tmp/work" entry
    mkdir -p "$work"
    export SOPS_AGE_KEY=not-a-key SOPS_AGE_KEY_CMD=false SOPS_AGE_SSH_PRIVATE_KEY_FILE=/nowhere
    HOMELAB_SOPS_AGE_KEY_FILE="$tmp/other-key.txt" secrets_clean_env "$work" /opt/bin
    [ "${SECRETS_ENV[*]}" = "env -i PATH=/opt/bin:/usr/bin:/bin HOME=$work/home SOPS_AGE_KEY_FILE=$tmp/other-key.txt" ] || return 1
    [ -d "$work/home" ] || return 1
    for entry in "${SECRETS_ENV[@]}"; do
        case "$entry" in SOPS_AGE_KEY=* | SOPS_AGE_KEY_CMD=* | SOPS_AGE_SSH_*) return 1 ;; esac
    done
}
expect pass "clean environment" clean_env_is_minimal

if [ "$failures" -ne 0 ]; then
    log_error "$failures of $cases secrets task checks failed."
    exit 1
fi
log_info "✓ All $cases secrets task checks give the expected result."
