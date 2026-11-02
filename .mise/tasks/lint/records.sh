#!/usr/bin/env bash
#MISE description="Refuse references to the old proposal and decision record files"

# The repository has no proposal or decision record files. Their decisions are in
# the Diátaxis pages of docs/. This check fails when a tracked file refers to the
# old files again. It matches only the record patterns, so IETF references such
# as "RFC 1123" in upstream manifests stay legal.
#
# The patterns use character classes, for example "record[s]", so that this file
# does not match itself.

set -euo pipefail

# shellcheck source=../_base/log.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/log.sh"

cd "$MISE_PROJECT_ROOT"

patterns=(
    '\bRFC[ -]?0[0-9]{3}\b'
    '\bAD[R]s?\b'
    'docs/record[s]'
    'rfc[s]/'
    'adr[s]/'
)

args=()
for pattern in "${patterns[@]}"; do
    args+=(-e "$pattern")
done

# CHANGELOG.md is generated from the Git history, which keeps the old commit
# titles. It is the only exclusion.
log_info "Searching the tracked files for references to the old records..."
# git grep exits 0 when it finds a match, 1 when it finds none, and another
# code on an error, for example a git without PCRE support. Only 1 is a pass.
set +e
git grep -n -I -P "${args[@]}" -- . ':(exclude)CHANGELOG.md'
rc=$?
set -e

case "$rc" in
    0)
        log_error "The files above refer to the old records. Point them to the Diátaxis page that holds the decision, or state the rule."
        exit 1
        ;;
    1)
        log_info "✓ No file refers to the old records."
        ;;
    *)
        log_error "git grep failed with exit code $rc."
        exit "$rc"
        ;;
esac
