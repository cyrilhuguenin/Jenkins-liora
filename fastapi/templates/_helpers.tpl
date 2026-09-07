{{/* Nom des objets : fullnameOverride, sinon le nom de la release. */}}
{{- define "fastapi.fullname" -}}
{{- default .Release.Name .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Labels de sélection : doivent rester stables entre deux upgrades. */}}
{{- define "fastapi.selectorLabels" -}}
app.kubernetes.io/name: {{ include "fastapi.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/* Labels complets, posés sur les objets. */}}
{{- define "fastapi.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{ include "fastapi.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}
