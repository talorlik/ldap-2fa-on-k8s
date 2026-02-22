{{/* vim: set filetype=mustache: */}}

{{- define "ltb-passwd.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "ltb-passwd.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "ltb-passwd.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "ltb-passwd.labels" -}}
app.kubernetes.io/name: {{ include "ltb-passwd.name" . }}
helm.sh/chart: {{ include "ltb-passwd.chart" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "ltb-passwd.image" -}}
{{- if .Values.image.registry -}}
{{- printf "%s/%s:%s" .Values.image.registry .Values.image.repository (.Values.image.tag | toString) -}}
{{- else -}}
{{- printf "%s:%s" .Values.image.repository (.Values.image.tag | toString) -}}
{{- end -}}
{{- end -}}

{{- define "ltb-passwd.imagePullSecrets" -}}
{{- if .Values.image.pullSecrets }}
imagePullSecrets:
{{- range .Values.image.pullSecrets }}
  - name: {{ . }}
{{- end }}
{{- end -}}
{{- end -}}

{{/*
Generate the secret name for LTB-passwd.
Uses existingSecret from parent chart if set, otherwise release-name-ltb-passwd.
*/}}
{{- define "ltb-passwd.secretName" -}}
{{- if .Values.global.existingSecret -}}
{{- .Values.global.existingSecret -}}
{{- else -}}
{{- printf "%s-ltb-passwd" .Release.Name -}}
{{- end -}}
{{- end -}}

{{/*
Return the LDAP server address from parent chart.
*/}}
{{- define "ltb-passwd.ldapServer" -}}
{{- printf "%s.%s" .Release.Name .Release.Namespace -}}
{{- end -}}

{{/*
Return the admin bind DN from parent chart's ldapDomain.
*/}}
{{- define "ltb-passwd.bindDN" -}}
{{- $parts := split "." .Values.global.ldapDomain -}}
{{- $result := list -}}
{{- range $index, $part := $parts -}}
  {{- $result = append $result (printf "dc=%s" $part) -}}
{{- end -}}
{{- printf "cn=admin,%s" (join "," $result) -}}
{{- end -}}

{{/*
Return the base domain from parent chart's ldapDomain.
*/}}
{{- define "ltb-passwd.baseDomain" -}}
{{- $parts := split "." .Values.global.ldapDomain -}}
{{- $result := list -}}
{{- range $index, $part := $parts -}}
  {{- $result = append $result (printf "dc=%s" $part) -}}
{{- end -}}
{{- join "," $result -}}
{{- end -}}
