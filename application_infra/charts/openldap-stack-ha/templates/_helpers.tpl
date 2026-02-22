{{/* vim: set filetype=mustache: */}}

{{/*
Expand the name of the chart.
*/}}
{{- define "openldap.name" -}}
{{- default .Release.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "openldap.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Release.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "openldap.chart" -}}
{{- printf "%s-%s" .Release.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "openldap.labels" -}}
app.kubernetes.io/name: {{ include "openldap.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: {{ include "openldap.fullname" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ include "openldap.chart" . }}
{{- end -}}

{{/*
Selector labels
*/}}
{{- define "openldap.selectorLabels" -}}
app.kubernetes.io/name: {{ include "openldap.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: {{ include "openldap.fullname" . }}
{{- end -}}

{{/*
Return the proper OpenLDAP image name.
Supports image.registry, image.repository, image.tag.
*/}}
{{- define "openldap.image" -}}
{{- if .Values.image.registry -}}
{{- printf "%s/%s:%s" .Values.image.registry .Values.image.repository (.Values.image.tag | toString) -}}
{{- else -}}
{{- printf "%s:%s" .Values.image.repository (.Values.image.tag | toString) -}}
{{- end -}}
{{- end -}}

{{/*
Return image pull secrets
*/}}
{{- define "openldap.imagePullSecrets" -}}
{{- $pullSecrets := list -}}
{{- range .Values.image.pullSecrets -}}
  {{- $pullSecrets = append $pullSecrets . -}}
{{- end -}}
{{- if (not (empty $pullSecrets)) }}
imagePullSecrets:
{{- range $pullSecrets }}
  - name: {{ . }}
{{- end }}
{{- end -}}
{{- end -}}

{{/*
Generate the secret name to use.
If existingSecret is set, use that. Otherwise use the release fullname.
*/}}
{{- define "openldap.secretName" -}}
{{- default (include "openldap.fullname" .) .Values.existingSecret -}}
{{- end -}}

{{/*
Return the base domain from ldapDomain.
e.g., "ldap.example.com" -> "dc=ldap,dc=example,dc=com"
*/}}
{{- define "openldap.baseDomain" -}}
{{- $parts := split "." .Values.ldapDomain -}}
{{- $result := list -}}
{{- range $index, $part := $parts -}}
  {{- $result = append $result (printf "dc=%s" $part) -}}
{{- end -}}
{{- join "," $result -}}
{{- end -}}

{{/*
Return the admin bind DN.
*/}}
{{- define "openldap.bindDN" -}}
{{- printf "cn=admin,%s" (include "openldap.baseDomain" .) -}}
{{- end -}}

{{/*
Return the LDAP server address (for subcharts).
*/}}
{{- define "openldap.server" -}}
{{- printf "%s.%s" .Release.Name .Release.Namespace -}}
{{- end -}}

{{/*
Generate LDAP_REPLICATION_HOSTS value for osixia multi-master replication.
Produces: #DIFFUSION2BASH:[ldap://pod-0.headless.ns.svc.cluster.local ldap://pod-1.headless.ns.svc.cluster.local ...]
*/}}
{{- define "openldap.replicationHosts" -}}
{{- $name := include "openldap.fullname" . -}}
{{- $namespace := .Release.Namespace -}}
{{- $cluster := .Values.replication.clusterName -}}
{{- $nodeCount := .Values.replicaCount | int -}}
{{- $hosts := list -}}
{{- range $i := until $nodeCount -}}
  {{- $hosts = append $hosts (printf "'ldap://%s-%d.%s-headless.%s.svc.%s'" $name $i $name $namespace $cluster) -}}
{{- end -}}
#PYTHON2BASH:[{{ join ", " $hosts }}]
{{- end -}}

{{/*
Render a value that contains template.
*/}}
{{- define "openldap.tplValue" -}}
{{- if typeIs "string" .value -}}
  {{- tpl .value .context -}}
{{- else -}}
  {{- tpl (.value | toYaml) .context -}}
{{- end -}}
{{- end -}}
