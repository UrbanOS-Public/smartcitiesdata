{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "kdp.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a fully qualified presto name.
*/}}
{{- define "kdp.presto.fullname" -}}
{{- printf "%s-%s" .Chart.Name "presto" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a fully qualified metastore name.
*/}}
{{- define "kdp.metastore.fullname" -}}
{{- printf "%s-%s" .Chart.Name "metastore" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a fully qualified hive name.
*/}}
{{- define "kdp.hive.fullname" -}}
{{- printf "%s-%s" .Chart.Name "hive" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a fully qualified postgres name.
*/}}
{{- define "kdp.postgres.fullname" -}}
{{- printf "%s-%s" .Chart.Name "postgres" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a fully qualified minio name.
*/}}
{{- define "kdp.minio.fullname" -}}
{{- printf "%s-%s" .Chart.Name "minio" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a common label block
*/}}
{{- define "kdp.labels" -}}
environment: {{ .Values.global.environment }}
release: {{ .Release.Name }}
source: helm
{{- end -}}
