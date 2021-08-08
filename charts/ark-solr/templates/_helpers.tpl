{{/*
Expand the name of the chart.
*/}}
{{- define "solr-helm-charts.name" -}}
{{- default .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "solr-helm-charts.fullname" -}}
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
{{- define "solr-helm-charts.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "solr-helm-charts.labels" -}}
{{ include "solr-helm-charts.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "solr-helm-charts.selectorLabels" -}}
app-name: ark-solr
app-version: 7.7.2
{{- end }}

{{/*
Define the name of the client service for solr
*/}}
{{- define "solr.service-name" -}}
{{- printf "%s-%s" (include "solr.fullname" .) "svc" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "solr.configmap-name" -}}
{{- printf "%s-%s" (include "solr.fullname" .) "configmap" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "solr.fullname" -}}
{{- .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end -}}

{{- define "solr.statefulset-name" -}}
{{- printf "%s-%s" (include "solr.fullname" .) "statefulset" | trunc 63 | trimSuffix "-" }}
{{- end }}

