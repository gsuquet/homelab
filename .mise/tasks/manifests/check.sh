#!/usr/bin/env bash
#MISE description="Check if manifests are up-to-date"

set -euo pipefail

# Store current state
git diff --exit-code kubernetes/**/manifests/ > /dev/null 2>&1
initial_clean=$?

# Render manifests
mise run manifests:render

# Check if anything changed
git diff --exit-code kubernetes/**/manifests/ > /dev/null 2>&1
changed=$?

if [ $changed -ne 0 ]; then
    echo "❌ Manifests are out of date. Run 'mise manifests:render' to update them."
    git diff kubernetes/**/manifests/
    exit 1
else
    echo "✅ All manifests are up to date."
    exit 0
fi
