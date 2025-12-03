{{/*
Redis instance name
*/}}
{{- define "redis-instance.name" -}}
{{- .Values.name | default .Release.Name -}}
{{- end -}}

{{/*
Redis full name
*/}}
{{- define "redis-instance.fullname" -}}
{{- include "redis-instance.name" . -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "redis-instance.labels" -}}
app.kubernetes.io/name: {{ include "redis-instance.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Secret name - use existing or auto-generated
*/}}
{{- define "redis-instance.secretName" -}}
{{- if .Values.auth.existingSecret -}}
{{- .Values.auth.existingSecret -}}
{{- else -}}
{{- include "redis-instance.fullname" . -}}
{{- end -}}
{{- end -}}
