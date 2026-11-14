{{/*
thoth chart helpers.
*/}}
{{- define "thoth.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "thoth.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s" (include "thoth.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "thoth.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "thoth.labels" -}}
helm.sh/chart: {{ include "thoth.chart" . }}
{{ include "thoth.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "thoth.selectorLabels" -}}
app.kubernetes.io/name: {{ include "thoth.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "thoth.image" -}}
{{- $tag := .Values.image.tag | default .Chart.AppVersion -}}
{{- printf "%s:%s" .Values.image.repository $tag -}}
{{- end -}}

{{/* LLM secret name: existing or chart-created */}}
{{- define "thoth.llmSecretName" -}}
{{- if .Values.llm.existingSecret -}}
{{- .Values.llm.existingSecret -}}
{{- else -}}
{{- printf "%s-llm" (include "thoth.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* GPG secret name: existing or chart-created */}}
{{- define "thoth.gpgSecretName" -}}
{{- if .Values.gpg.existingSecret -}}
{{- .Values.gpg.existingSecret -}}
{{- else -}}
{{- printf "%s-gpg" (include "thoth.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* Image pull secret name: existing or chart-created */}}
{{- define "thoth.pullSecretName" -}}
{{- if .Values.imagePullSecret.existingSecret -}}
{{- .Values.imagePullSecret.existingSecret -}}
{{- else -}}
{{- printf "%s-pull" (include "thoth.fullname" .) -}}
{{- end -}}
{{- end -}}
