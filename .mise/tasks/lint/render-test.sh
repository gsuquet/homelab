#!/usr/bin/env bash
#MISE description="Test that manifests:render adds the sync wave -1 to each CRD"

# The test splits a fixture of helm template output with the function that
# manifests:render uses. A CRD must get the wave "-1", whatever the chart sets.
# Other resources must keep their annotations.

set -euo pipefail

# shellcheck source=../_base/log.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/log.sh"
# shellcheck source=../_base/render.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/render.sh"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

cat > "$work/input.yaml" << 'YAML'
---
# Source: demo/templates/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: demo
  annotations:
    argocd.argoproj.io/sync-wave: "-2"
---
# Source: demo/charts/crds/templates/no-annotations.yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: nones.example.com
spec:
  group: example.com
---
# Source: demo/charts/crds/templates/other-annotation.yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: others.example.com
  annotations:
    helm.sh/resource-policy: keep
spec:
  group: example.com
---
# Source: demo/charts/crds/templates/other-wave.yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: waves.example.com
  annotations:
    argocd.argoproj.io/sync-wave: "5"
spec:
  group: example.com
---
# Source: demo/templates/config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: config
data:
  key: value
YAML

split_manifest_by_resource "$work/input.yaml" "$work/out" > /dev/null

failures=0

# check <description> <file> <yq expression> <expected>
check() {
    local description="$1" file="$2" expression="$3" expected="$4" actual
    actual="$(yq "$expression" "$work/out/$file")"
    if [ "$actual" = "$expected" ]; then
        log_info "ok: $description"
    else
        log_error "$description: got '$actual', expected '$expected'"
        failures=$((failures + 1))
    fi
}

wave='.metadata.annotations["argocd.argoproj.io/sync-wave"]'
check "CRD without annotations gets the wave" upstream--customresourcedefinition-nones.example.com.yaml "$wave" "-1"
check "CRD with another annotation gets the wave" upstream--customresourcedefinition-others.example.com.yaml "$wave" "-1"
check "CRD keeps its other annotation" upstream--customresourcedefinition-others.example.com.yaml '.metadata.annotations["helm.sh/resource-policy"]' "keep"
check "CRD with another wave gets the wave -1" upstream--customresourcedefinition-waves.example.com.yaml "$wave" "-1"
check "Namespace keeps its wave" namespace-demo.yaml "$wave" "-2"
check "ConfigMap gets no wave" configmap-config.yaml "$wave" "null"
check "ConfigMap keeps its data" configmap-config.yaml ".data.key" "value"

if [ "$failures" -ne 0 ]; then
    exit 1
fi

log_info "✓ manifests:render adds the sync wave -1 to each CRD only."
