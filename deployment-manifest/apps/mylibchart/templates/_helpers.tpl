{{/*
Expand the name of the chart.
*/}}
{{- define "deploy.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "deploy.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "deploy.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}


{{/* Common labels */}}
{{- define "deploy.commonLabels" -}}
helm.sh/chart: {{ include "deploy.chart" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{ include "deploy.selectorLabels" . }}
{{- end }}

{{/* Selector labels */}}
{{- define "deploy.selectorLabels" -}}
app.kubernetes.io/name: {{ include "deploy.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app: {{ include "deploy.name" . }}
release: external-kube-prometheus-stack
{{- end }}