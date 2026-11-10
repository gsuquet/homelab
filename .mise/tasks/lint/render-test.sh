#!/usr/bin/env bash
#MISE description="Test that manifests:render adds the sync wave -1 and Prune=false to each CRD"

# The test splits a fixture of helm template output with the function that
# manifests:render uses. A CRD must get the wave "-1", whatever the chart sets.
# A CRD must also get Prune=false in its sync options, merged with the options
# that it already has. Other resources must keep their annotations.

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
# Source: demo/templates/crd.yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: firsts.example.com
spec:
  group: example.com
---
# Source: demo/charts/crds/crds/two.yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: ones.example.com
spec:
  group: example.com
---
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: twos.example.com
  annotations:
    argocd.argoproj.io/sync-wave: -1
spec:
  group: example.com
---
# Source: demo/charts/crds/crds/options.yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: options.example.com
  annotations:
    argocd.argoproj.io/sync-options: ServerSideApply=true
spec:
  group: example.com
---
# Source: demo/charts/crds/crds/has-prune.yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: haspruneds.example.com
  annotations:
    argocd.argoproj.io/sync-options: "Prune=false, ServerSideApply=true"
spec:
  group: example.com
---
# Source: demo/charts/crds/crds/prune-true.yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: pruneyes.example.com
  annotations:
    argocd.argoproj.io/sync-options: "Prune=true,ServerSideApply=true"
spec:
  group: example.com
---
# Source: demo/templates/prune-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: pruned-config
  annotations:
    argocd.argoproj.io/sync-options: Prune=true
data:
  key: value
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
check "first-party CRD gets the wave" customresourcedefinition-firsts.example.com.yaml "$wave" "-1"
check "first CRD of a chunk with two CRDs gets the wave" upstream--customresourcedefinition-ones.example.com.yaml "$wave" "-1"
check "CRD with an unquoted wave -1 gets the string" upstream--customresourcedefinition-twos.example.com.yaml "$wave" "-1"
check "CRD with an unquoted wave -1 gets the string tag" upstream--customresourcedefinition-twos.example.com.yaml "$wave | tag" "!!str"
options='.metadata.annotations["argocd.argoproj.io/sync-options"]'
check "CRD without annotations gets Prune=false" upstream--customresourcedefinition-nones.example.com.yaml "$options" "Prune=false"
check "CRD keeps ServerSideApply=true next to Prune=false" upstream--customresourcedefinition-options.example.com.yaml "$options" "ServerSideApply=true,Prune=false"
check "CRD with Prune=false gets no duplicate" upstream--customresourcedefinition-haspruneds.example.com.yaml "$options" "Prune=false,ServerSideApply=true"
check "CRD with Prune=true gets Prune=false" upstream--customresourcedefinition-pruneyes.example.com.yaml "$options" "ServerSideApply=true,Prune=false"
check "first-party CRD gets Prune=false" customresourcedefinition-firsts.example.com.yaml "$options" "Prune=false"
check "first CRD of a chunk with two CRDs gets Prune=false" upstream--customresourcedefinition-ones.example.com.yaml "$options" "Prune=false"
check "Namespace gets no sync options" namespace-demo.yaml "$options" "null"
check "ConfigMap keeps its sync options" configmap-pruned-config.yaml "$options" "Prune=true"
check "Namespace keeps its wave" namespace-demo.yaml "$wave" "-2"
check "ConfigMap gets no wave" configmap-config.yaml "$wave" "null"
check "ConfigMap keeps its data" configmap-config.yaml ".data.key" "value"

if [ "$failures" -ne 0 ]; then
    exit 1
fi

log_info "✓ manifests:render adds the sync wave -1 and Prune=false to each CRD only."
