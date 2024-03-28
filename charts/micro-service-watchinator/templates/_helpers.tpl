{{/* vim: set filetype=mustache: */}}

{{- define "watchinator.resources" -}}
limits:
  memory: {{ .Values.resourceLimits.memory }}
  cpu: {{ .Values.resourceLimits.cpu }}
requests:
  memory: {{ .Values.resourceLimits.memory }}
  cpu: {{ .Values.resourceLimits.cpu }}
{{- end -}}
