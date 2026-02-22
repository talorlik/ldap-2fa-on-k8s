{{/* vim: set filetype=mustache: */}}

{{- define "phpldapadmin.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "phpldapadmin.fullname" -}}
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

{{- define "phpldapadmin.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "phpldapadmin.image" -}}
{{- if .Values.image.registry -}}
{{- printf "%s/%s:%s" .Values.image.registry .Values.image.repository (.Values.image.tag | toString) -}}
{{- else -}}
{{- printf "%s:%s" .Values.image.repository (.Values.image.tag | toString) -}}
{{- end -}}
{{- end -}}

{{- define "phpldapadmin.imagePullSecrets" -}}
{{- if .Values.image.pullSecrets }}
imagePullSecrets:
{{- range .Values.image.pullSecrets }}
  - name: {{ . }}
{{- end }}
{{- end -}}
{{- end -}}

{{/*
Return the LDAP server address from parent chart.
*/}}
{{- define "phpldapadmin.ldapServer" -}}
{{- printf "%s.%s" .Release.Name .Release.Namespace -}}
{{- end -}}

{{/*
Return the admin bind DN from parent chart's ldapDomain.
*/}}
{{- define "phpldapadmin.bindDN" -}}
{{- $parts := split "." .Values.global.ldapDomain -}}
{{- $result := list -}}
{{- range $index, $part := $parts -}}
  {{- $result = append $result (printf "dc=%s" $part) -}}
{{- end -}}
{{- printf "cn=admin,%s" (join "," $result) -}}
{{- end -}}
