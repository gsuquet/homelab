{{/* Name of the instance. Each values/<instance>.yaml must set gitops.instance. */}}
{{- define "argocd.instance" -}}
{{- required "gitops.instance is required: set it in values/<instance>.yaml" .Values.gitops.instance -}}
{{- end -}}
