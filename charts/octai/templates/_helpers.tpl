{{/*
Expand the name of the chart.
*/}}
{{- define "octai.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "octai.fullname" -}}
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
{{- define "octai.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "octai.labels" -}}
helm.sh/chart: {{ include "octai.chart" . }}
{{ include "octai.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "octai.selectorLabels" -}}
app.kubernetes.io/name: {{ include "octai.name" . }}
app.kubernetes.io/instance:  {{ include "octai.name" . }}
{{- end }}

{{/*
{{- end }}

{{/*
Custom Datadog labels
*/}}
{{- define "octai.customDatadogLabels" -}}
tags.datadoghq.com/data-service.env: customer
tags.datadoghq.com/data-service.service: data-service
tags.datadoghq.com/data-service.version: latest
tags.datadoghq.com/compute-engine.env: customer
tags.datadoghq.com/compute-engine.service: compute-engine
tags.datadoghq.com/compute-engine.version: latest
{{- end }}

{{/*
Custom annotations
*/}}
{{- define "octai.customAnnotations" -}}
reloader.stakater.com/auto: "true"
{{- end }}

