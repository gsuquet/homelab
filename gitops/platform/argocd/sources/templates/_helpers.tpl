{{/* Name of the instance. Each values/<instance>.yaml must set gitops.instance. */}}
{{- define "argocd.instance" -}}
{{- required "gitops.instance is required: set it in values/<instance>.yaml" .Values.gitops.instance -}}
{{- end -}}

{{/*
ApplicationSet for one group of gitops/: platform or apps.
gitops/instances/<instance>.yaml lists the components of the instance. The
ApplicationSet makes one Application for each component in the list of the
group. The Application syncs gitops/<group>/<component>/rendered/<instance>/.
Each component ships its own Namespace, thus there is no CreateNamespace.
*/}}
{{- define "argocd.applicationset" -}}
{{- $instance := include "argocd.instance" .root -}}
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: {{ .group }}
  namespace: argocd
spec:
  goTemplate: true
  goTemplateOptions:
    - missingkey=error
  syncPolicy:
    # Do not delete the resources of an Application when the ApplicationSet deletes the Application.
    preserveResourcesOnDeletion: true
  generators:
    - matrix:
        generators:
          - git:
              repoURL: {{ .root.Values.gitops.repoURL }}
              revision: {{ .root.Values.gitops.targetRevision }}
              files:
                - path: gitops/instances/{{ $instance }}.yaml
          - list:
              elementsYaml: "{{`{{ .`}}{{ .group }}{{` | toJson }}`}}"
  template:
    metadata:
      name: "{{`{{ .name }}`}}"
    spec:
      project: {{ .group }}
      source:
        repoURL: {{ .root.Values.gitops.repoURL }}
        targetRevision: {{ .root.Values.gitops.targetRevision }}
        path: "gitops/{{ .group }}/{{`{{ .name }}`}}/rendered/{{ $instance }}"
      destination:
        server: https://kubernetes.default.svc
        namespace: "{{`{{ .namespace }}`}}"
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - ServerSideApply=true
        # Argo CD does not try a failed sync again for the same revision. Retry
        # covers short failures, for example an image pull timeout in a hook.
        retry:
          limit: 5
          backoff:
            duration: 10s
            factor: 2
            maxDuration: 3m
{{- end -}}
