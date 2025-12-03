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
