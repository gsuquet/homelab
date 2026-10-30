{{/* Name of the cluster. manifests:render sets gitops.cluster from clusters/<cluster>/cluster.yaml. */}}
{{- define "argocd.cluster" -}}
{{- required "gitops.cluster.name is required: run 'mise run manifests:render'" .Values.gitops.cluster.name -}}
{{- end -}}

{{/*
Sync wave of each component, as JSON: {"<name>": <wave>}.
A component without dependsOn has the wave 1. Another component has the wave
of its deepest dependency plus 1. The resources of Argo CD itself use the waves
-2 to 0. The loop runs once for each component: after it, a depth equal to the
number of components is only possible in a cycle.
*/}}
{{- define "argocd.waves" -}}
{{- $cluster := .Values.gitops.cluster -}}
{{- $components := concat ($cluster.infrastructure | default list) ($cluster.apps | default list) -}}
{{- $depth := dict -}}
{{- range $components -}}
{{- $_ := set $depth .name 0 -}}
{{- end -}}
{{- range $component := $components -}}
{{- if and (eq $component.name "argocd") $component.dependsOn -}}
{{- fail "argocd: remove dependsOn. Argo CD syncs before all the other components" -}}
{{- end -}}
{{- range ($component.dependsOn | default list) -}}
{{- if not (hasKey $depth .) -}}
{{- fail (printf "%s: dependsOn %s, but %s is not in the cluster" $component.name . .) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- range until (len $components) -}}
{{- range $component := $components -}}
{{- range ($component.dependsOn | default list) -}}
{{- $next := add1 (get $depth .) -}}
{{- if gt (int $next) (int (get $depth $component.name)) -}}
{{- $_ := set $depth $component.name $next -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- $waves := dict -}}
{{- range $name, $value := $depth -}}
{{- if ge (int $value) (len $components) -}}
{{- fail (printf "%s: dependsOn makes a cycle" $name) -}}
{{- end -}}
{{- $_ := set $waves $name (add1 $value) -}}
{{- end -}}
{{- toJson $waves -}}
{{- end -}}
