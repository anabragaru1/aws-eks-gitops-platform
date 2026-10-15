{{- define "api.name" -}}
{{ .Chart.Name }}
{{- end -}}

{{- define "api.labels" -}}
app.kubernetes.io/name: {{ include "api.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Values.image.tag | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: gitops-platform
environment: {{ .Values.environment }}
{{- end -}}

{{- define "api.selectorLabels" -}}
app.kubernetes.io/name: {{ include "api.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "api.image" -}}
{{ .Values.image.repository }}:{{ .Values.image.tag }}
{{- end -}}

{{- define "api.dbEnv" -}}
- name: DB_HOST
  value: {{ .Values.database.host | quote }}
- name: DB_PORT
  value: {{ .Values.database.port | quote }}
- name: DB_NAME
  value: {{ .Values.database.name | quote }}
- name: DB_SSLMODE
  value: {{ .Values.database.sslMode | quote }}
- name: DB_USER
  valueFrom:
    secretKeyRef:
      name: {{ include "api.name" . }}-db
      key: username
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "api.name" . }}-db
      key: password
{{- end -}}
