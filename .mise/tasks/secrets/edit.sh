#!/usr/bin/env bash
#MISE description="Open the SOPS file of an instance in an editor with no swap, backup or undo files. By hand only, with no agent session."
#USAGE arg "<instance>" help="Instance name: a folder in instances/"

# Agents never run this task. Stop all agent sessions first: the plaintext is in a
# temporary file while the editor is open. Refer to docs/how-to/add-a-secret.md.
#
# The editor is vim with no vimrc and no plugins (-u NONE), no swap file (-n), no
# viminfo (-i NONE, it keeps registers), and no backup, write backup, undo file or
# modeline. SOPS writes its temporary file into a new folder with mode 0700, and the
# EXIT trap deletes the folder.
#
# Environment: the age key variable, if set, and XDG_CONFIG_HOME. SOPS gets no other
# variable, except TERM for the editor.

set -euo pipefail

# shellcheck source=../_base/log.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/log.sh"
# shellcheck source=../_base/instance.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/instance.sh"
# shellcheck source=../_base/secrets.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/secrets.sh"

secrets_require_tty
secrets_load "${usage_instance:?}"
secrets_require_dir
secrets_check_rules

vim_bin="$(command -v vim || true)"
if [ -z "$vim_bin" ]; then
    log_error "The vim command is missing. secrets:edit uses only vim, with its safe settings."
    exit 1
fi
sops_bin="$(secrets_tool sops)"

work="$(secrets_workdir edit)"
secrets_cleanup_on_exit "$work"
mkdir "$work/tmp"

# SOPS starts the editor with the path of its temporary file as the last argument.
cat > "$work/editor" << EDITOR
#!/bin/sh
exec "$vim_bin" -u NONE -N -n -i NONE --cmd 'set nobackup nowritebackup noundofile noswapfile nomodeline' "\$@"
EDITOR
chmod 0700 "$work/editor"

secrets_clean_env "$(dirname "$sops_bin")"
SECRETS_ENV+=(
    "TERM=${TERM:-xterm}"
    "TMPDIR=$work/tmp"
    "SOPS_EDITOR=$work/editor"
    "EDITOR=$work/editor"
)

# sops reads .sops.yaml from the working folder and matches path_regex against the
# path relative to it, so the task runs from the repository root.
cd "$MISE_PROJECT_ROOT"
"${SECRETS_ENV[@]}" "$sops_bin" edit "$SECRETS_FILE_REL" < /dev/tty > /dev/tty

log_info "✓ Saved $SECRETS_FILE_REL. Next: mise run lint:secrets, then commit the SOPS file."
