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
# Environment: HOMELAB_SOPS_AGE_KEY_FILE, if set, gives the age key file. SOPS gets an
# empty HOME and only that key file, plus TERM and LANG for the editor.
#
# Exit status: 0 after a change or with no change (sops status 200); else the status
# of sops.

set -euo pipefail

# shellcheck source=../_base/log.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/log.sh"
# shellcheck source=../_base/instance.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/instance.sh"
# shellcheck source=../_base/secrets.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/secrets.sh"

# The files that the task writes are for this user only.
umask 077

secrets_require_tty
secrets_load "${usage_instance:?}"
secrets_require_dir
secrets_check_rules

vim_bin="$(command -v vim || true)"
if [ -z "$vim_bin" ]; then
    log_error "The vim command is missing. secrets:edit uses only vim, with its safe settings."
    exit 1
fi
sops_bin="$(secrets_tool sops)" || exit 1

work="$(secrets_workdir edit)"
secrets_cleanup_on_exit "$work"
mkdir "$work/tmp"

# SOPS starts the editor with the path of its temporary file as the last argument.
{
    echo '#!/bin/sh'
    printf 'exec %q -u NONE -N -n -i NONE --cmd %q "$@"\n' "$vim_bin" \
        'set nobackup nowritebackup noundofile noswapfile nomodeline'
} > "$work/editor"
chmod 0700 "$work/editor"

secrets_clean_env "$work" "$(dirname "$sops_bin")"
SECRETS_ENV+=(
    "TERM=${TERM:-xterm}"
    "LANG=${LANG:-en_US.UTF-8}"
    "TMPDIR=$work/tmp"
    "SOPS_EDITOR=$work/editor"
    "EDITOR=$work/editor"
)

# sops reads .sops.yaml from the working folder and matches path_regex against the
# path relative to it, so the task runs from the repository root.
cd "$MISE_PROJECT_ROOT"
status=0
"${SECRETS_ENV[@]}" "$sops_bin" edit "$SECRETS_FILE_REL" < /dev/tty > /dev/tty || status=$?

case "$status" in
    0)
        log_info "✓ Saved $SECRETS_FILE_REL. Next: mise run lint:secrets, then commit the SOPS file."
        ;;
    200)
        # codes.FileHasNotBeenModified of sops.
        log_info "No change to $SECRETS_FILE_REL."
        ;;
    *)
        log_error "sops edit failed with status $status. $SECRETS_FILE_REL did not change."
        exit "$status"
        ;;
esac
