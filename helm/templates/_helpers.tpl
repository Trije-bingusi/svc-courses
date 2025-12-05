{{/*
Create a default fully qualified app name.
*/}}
{{- define "helm.fullname" -}}
{{ .Release.Name }}-{{ .Chart.Name }}
{{- end }}


{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "helm.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "helm.labels" -}}
{{ include "helm.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- if .Values.application.partOf }}
app.kubernetes.io/part-of: {{ .Values.application.partOf }}
{{- end }}
{{- if .Values.application.component }}
app.kubernetes.io/component: {{ .Values.application.component }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "helm.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
