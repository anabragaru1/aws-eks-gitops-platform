{{/* Common sync policy for every child Application. */}}
{{- define "root.syncPolicy" -}}
syncPolicy:
  automated:
    prune: true
    selfHeal: true
  syncOptions:
    - CreateNamespace=true
    - ServerSideApply=true
  retry:
    limit: 5
    backoff:
      duration: 10s
      factor: 2
      maxDuration: 3m
{{- end -}}
