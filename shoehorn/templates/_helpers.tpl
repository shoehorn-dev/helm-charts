{{/*
Expand the name of the chart.
*/}}
{{- define "shoehorn.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "shoehorn.fullname" -}}
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
{{- define "shoehorn.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "shoehorn.labels" -}}
helm.sh/chart: {{ include "shoehorn.chart" . }}
{{ include "shoehorn.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "shoehorn.selectorLabels" -}}
app.kubernetes.io/name: {{ include "shoehorn.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Shoehorn-specific annotations for service catalog integration
Takes a service's annotations map and prefixes all keys with "shoehorn.dev/"
Usage: {{ include "shoehorn.serviceAnnotations" .Values.api.annotations }}
Returns annotations in the format:
  shoehorn.dev/<key>: <value>
*/}}
{{- define "shoehorn.serviceAnnotations" -}}
{{- if . -}}
{{- range $key, $value := . }}
shoehorn.dev/{{ $key }}: {{ $value | quote }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "shoehorn.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "shoehorn.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Component labels
*/}}
{{- define "shoehorn.componentLabels" -}}
{{- $component := . -}}
app.kubernetes.io/component: {{ $component }}
{{- end }}

{{/*
API labels
*/}}
{{- define "shoehorn.api.labels" -}}
{{ include "shoehorn.labels" . }}
{{ include "shoehorn.componentLabels" "api" }}
{{- end }}

{{/*
API selector labels
*/}}
{{- define "shoehorn.api.selectorLabels" -}}
{{ include "shoehorn.selectorLabels" . }}
{{ include "shoehorn.componentLabels" "api" }}
{{- end }}

{{/*
Web labels
*/}}
{{- define "shoehorn.web.labels" -}}
{{ include "shoehorn.labels" . }}
{{ include "shoehorn.componentLabels" "web" }}
{{- end }}

{{/*
Web selector labels
*/}}
{{- define "shoehorn.web.selectorLabels" -}}
{{ include "shoehorn.selectorLabels" . }}
{{ include "shoehorn.componentLabels" "web" }}
{{- end }}

{{/*
EventBus labels
*/}}
{{- define "shoehorn.eventbus.labels" -}}
{{ include "shoehorn.labels" . }}
{{ include "shoehorn.componentLabels" "eventbus" }}
{{- end }}

{{/*
EventBus selector labels
*/}}
{{- define "shoehorn.eventbus.selectorLabels" -}}
{{ include "shoehorn.selectorLabels" . }}
{{ include "shoehorn.componentLabels" "eventbus" }}
{{- end }}

{{/*
Worker labels
*/}}
{{- define "shoehorn.worker.labels" -}}
{{ include "shoehorn.labels" . }}
{{ include "shoehorn.componentLabels" "worker" }}
{{- end }}

{{/*
Worker selector labels
*/}}
{{- define "shoehorn.worker.selectorLabels" -}}
{{ include "shoehorn.selectorLabels" . }}
{{ include "shoehorn.componentLabels" "worker" }}
{{- end }}

{{/*
Crawler labels
*/}}
{{- define "shoehorn.crawler.labels" -}}
{{ include "shoehorn.labels" . }}
{{ include "shoehorn.componentLabels" "crawler" }}
{{- end }}

{{/*
Crawler selector labels
*/}}
{{- define "shoehorn.crawler.selectorLabels" -}}
{{ include "shoehorn.selectorLabels" . }}
{{ include "shoehorn.componentLabels" "crawler" }}
{{- end }}

{{/*
Forge labels
*/}}
{{- define "shoehorn.forge.labels" -}}
{{ include "shoehorn.labels" . }}
{{ include "shoehorn.componentLabels" "forge" }}
{{- end }}

{{/*
Forge selector labels
*/}}
{{- define "shoehorn.forge.selectorLabels" -}}
{{ include "shoehorn.selectorLabels" . }}
{{ include "shoehorn.componentLabels" "forge" }}
{{- end }}

{{/*
Cerbos labels
*/}}
{{- define "shoehorn.cerbos.labels" -}}
{{ include "shoehorn.labels" . }}
{{ include "shoehorn.componentLabels" "cerbos" }}
{{- end }}

{{/*
Cerbos selector labels
*/}}
{{- define "shoehorn.cerbos.selectorLabels" -}}
{{ include "shoehorn.selectorLabels" . }}
{{ include "shoehorn.componentLabels" "cerbos" }}
{{- end }}

{{/*
Traefik labels
*/}}
{{- define "shoehorn.traefik.labels" -}}
{{ include "shoehorn.labels" . }}
{{ include "shoehorn.componentLabels" "traefik" }}
{{- end }}

{{/*
Traefik selector labels
*/}}
{{- define "shoehorn.traefik.selectorLabels" -}}
{{ include "shoehorn.selectorLabels" . }}
{{ include "shoehorn.componentLabels" "traefik" }}
{{- end }}

{{/*
Image pull secrets - combines global.imagePullSecrets and generated registry credentials
*/}}
{{- define "shoehorn.imagePullSecrets" -}}
{{- $secrets := list }}
{{- /* Add global imagePullSecrets */ -}}
{{- range .Values.global.imagePullSecrets }}
  {{- $secrets = append $secrets .name }}
{{- end }}
{{- /* Add generated registry credential secrets */ -}}
{{- if .Values.registryCredentials.enabled }}
  {{- range .Values.registryCredentials.registries }}
    {{- $secrets = append $secrets (printf "%s-registry-%s" (include "shoehorn.fullname" $) .name) }}
  {{- end }}
{{- end }}
{{- /* Add dockerconfigjson secret if provided */ -}}
{{- if .Values.registryCredentials.existingDockerConfigJson }}
  {{- $secrets = append $secrets (printf "%s-dockerconfig" (include "shoehorn.fullname" $)) }}
{{- end }}
{{- /* Output imagePullSecrets if any exist */ -}}
{{- if $secrets }}
imagePullSecrets:
{{- range $secrets }}
  - name: {{ . }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Return the proper image name
*/}}
{{- define "shoehorn.image" -}}
{{- $registry := .Values.image.registry -}}
{{- $repository := .Values.image.repository -}}
{{- $tag := .Values.image.tag | default .Chart.AppVersion -}}
{{- printf "%s/%s:%s" $registry $repository $tag -}}
{{- end }}

{{/*
Return the proper component image name
Tag precedence: component.image.tag > global image.tag > "latest"
*/}}
{{- define "shoehorn.componentImage" -}}
{{- $registry := .Values.image.registry -}}
{{- $globalRepo := .Values.image.repository -}}
{{- $componentRepo := .component.image.repository -}}
{{- $tag := .component.image.tag | default .Values.image.tag | default "latest" -}}
{{- printf "%s/%s/%s:%s" $registry $globalRepo $componentRepo $tag -}}
{{- end }}

{{/*
PostgreSQL host - returns external host or internal service name
*/}}
{{- define "shoehorn.postgresql.host" -}}
{{- if .Values.postgresql.external.enabled -}}
{{- .Values.postgresql.external.host -}}
{{- else -}}
{{- include "shoehorn.fullname" . }}-postgresql.{{ .Release.Namespace }}.svc.cluster.local
{{- end -}}
{{- end }}

{{/*
PostgreSQL port
*/}}
{{- define "shoehorn.postgresql.port" -}}
{{- if .Values.postgresql.external.enabled -}}
{{- .Values.postgresql.external.port -}}
{{- else -}}
5432
{{- end -}}
{{- end }}

{{/*
Valkey host - returns external host or internal service name
*/}}
{{- define "shoehorn.valkey.host" -}}
{{- if .Values.valkey.external.enabled -}}
{{- .Values.valkey.external.host -}}
{{- else -}}
{{- include "shoehorn.fullname" . }}-valkey.{{ .Release.Namespace }}.svc.cluster.local
{{- end -}}
{{- end }}

{{/*
Valkey port
*/}}
{{- define "shoehorn.valkey.port" -}}
{{- if .Values.valkey.external.enabled -}}
{{- .Values.valkey.external.port -}}
{{- else -}}
6379
{{- end -}}
{{- end }}

{{/*
Meilisearch host - returns external host or internal service name
*/}}
{{- define "shoehorn.meilisearch.host" -}}
{{- if .Values.meilisearch.external.enabled -}}
{{- .Values.meilisearch.external.host -}}
{{- else -}}
{{- include "shoehorn.fullname" . }}-meilisearch.{{ .Release.Namespace }}.svc.cluster.local
{{- end -}}
{{- end }}

{{/*
Meilisearch port
*/}}
{{- define "shoehorn.meilisearch.port" -}}
{{- if .Values.meilisearch.external.enabled -}}
{{- .Values.meilisearch.external.port -}}
{{- else -}}
7700
{{- end -}}
{{- end }}

{{/*
Meilisearch protocol
*/}}
{{- define "shoehorn.meilisearch.protocol" -}}
{{- if .Values.meilisearch.external.enabled -}}
{{- .Values.meilisearch.external.protocol -}}
{{- else -}}
http
{{- end -}}
{{- end }}

{{/*
Redpanda brokers - returns external brokers or internal service name
*/}}
{{- define "shoehorn.redpanda.brokers" -}}
{{- if .Values.redpanda.external.enabled -}}
{{- .Values.redpanda.external.brokers -}}
{{- else -}}
{{- if .Values.redpanda.tls.enabled -}}
{{- include "shoehorn.fullname" . }}-redpanda.{{ .Release.Namespace }}.svc.cluster.local:9093
{{- else -}}
{{- include "shoehorn.fullname" . }}-redpanda.{{ .Release.Namespace }}.svc.cluster.local:9092
{{- end -}}
{{- end -}}
{{- end }}

{{/*
Redpanda broker host (without port) - for init-container connectivity checks
*/}}
{{- define "shoehorn.redpanda.host" -}}
{{- include "shoehorn.redpanda.brokers" . | splitList ":" | first -}}
{{- end }}

{{/*
Redpanda broker port - for init-container connectivity checks
*/}}
{{- define "shoehorn.redpanda.port" -}}
{{- include "shoehorn.redpanda.brokers" . | splitList ":" | last -}}
{{- end }}

{{/*
EventBus GRPC address
*/}}
{{- define "shoehorn.eventbus.grpc" -}}
{{- include "shoehorn.fullname" . }}-eventbus.{{ .Release.Namespace }}.svc.cluster.local:9083
{{- end }}

{{/*
Worker GRPC address
*/}}
{{- define "shoehorn.worker.grpc" -}}
{{- include "shoehorn.fullname" . }}-worker.{{ .Release.Namespace }}.svc.cluster.local:9085
{{- end }}

{{/*
Crawler GRPC address
*/}}
{{- define "shoehorn.crawler.grpc" -}}
{{- include "shoehorn.fullname" . }}-crawler.{{ .Release.Namespace }}.svc.cluster.local:9086
{{- end }}

{{/*
Forge GRPC address
*/}}
{{- define "shoehorn.forge.grpc" -}}
{{- include "shoehorn.fullname" . }}-forge.{{ .Release.Namespace }}.svc.cluster.local:9087
{{- end }}

{{/*
Namespace helpers - all components deploy to Release.Namespace
*/}}
{{- define "shoehorn.namespace.frontend" -}}
{{- .Release.Namespace -}}
{{- end }}

{{- define "shoehorn.namespace.backend" -}}
{{- .Release.Namespace -}}
{{- end }}

{{- define "shoehorn.namespace.data" -}}
{{- .Release.Namespace -}}
{{- end }}

{{/*
Validate required values at template render time.
Fails helm install/template with a clear error message.
*/}}
{{- define "shoehorn.validateValues" -}}
{{- if not .Values.secret.existingSecret -}}
  {{- fail "\n\nsecret.existingSecret is required.\n\nCreate a Kubernetes Secret and set:\n  secret:\n    existingSecret: <your-secret-name>\n\nSee README.md for details." -}}
{{- end -}}
{{- if eq .Values.auth.provider "zitadel" -}}
  {{- if and (not .Values.auth.zitadel.projectId) (not (hasKey .Values.secret.mappings "ZITADEL_PROJECT_ID")) -}}
    {{- fail "\n\nauth.zitadel.projectId is required when auth.provider is 'zitadel'.\nSet it in values or add ZITADEL_PROJECT_ID to secret.mappings." -}}
  {{- end -}}
  {{- if and (not .Values.auth.zitadel.clientId) (not (hasKey .Values.secret.mappings "ZITADEL_CLIENT_ID")) -}}
    {{- fail "\n\nauth.zitadel.clientId is required when auth.provider is 'zitadel'.\nSet it in values or add ZITADEL_CLIENT_ID to secret.mappings." -}}
  {{- end -}}
  {{- if not .Values.auth.zitadel.externalUrl -}}
    {{- fail "\n\nauth.zitadel.externalUrl is required when auth.provider is 'zitadel'." -}}
  {{- end -}}
{{- end -}}
{{- if eq .Values.auth.provider "okta" -}}
  {{- if not .Values.auth.okta.domain -}}
    {{- fail "\n\nauth.okta.domain is required when auth.provider is 'okta'." -}}
  {{- end -}}
  {{- if not .Values.auth.okta.clientId -}}
    {{- fail "\n\nauth.okta.clientId is required when auth.provider is 'okta'." -}}
  {{- end -}}
{{- end -}}
{{- if eq .Values.auth.provider "entra-id" -}}
  {{- if not .Values.auth.entraId.tenantId -}}
    {{- fail "\n\nauth.entraId.tenantId is required when auth.provider is 'entra-id'." -}}
  {{- end -}}
  {{- if not .Values.auth.entraId.clientId -}}
    {{- fail "\n\nauth.entraId.clientId is required when auth.provider is 'entra-id'." -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{/*
Secret environment variable from secret.existingSecret + secret.mappings.
Usage: {{ include "shoehorn.secretRef" (dict "env" "DB_PASSWORD" "root" .) }}
Optional: {{ include "shoehorn.secretRef" (dict "env" "ARGOCD_TOKEN" "root" . "optional" true) }}
*/}}
{{- define "shoehorn.secretRef" -}}
{{- if hasKey .root.Values.secret.mappings .env }}
- name: {{ .env }}
  valueFrom:
    secretKeyRef:
      name: {{ .root.Values.secret.existingSecret }}
      key: {{ index .root.Values.secret.mappings .env }}
      {{- if .optional }}
      optional: true
      {{- end }}
{{- end }}
{{- end -}}

{{/*
Extra volumes — renders user-provided extraVolumes list.
Usage: {{- include "shoehorn.extraVolumes" . | nindent 6 }}
*/}}
{{- define "shoehorn.extraVolumes" -}}
{{- range .Values.extraVolumes }}
- {{- mustToYaml . | nindent 2 }}
{{- end }}
{{- end -}}

{{/*
Extra volume mounts — renders user-provided extraVolumeMounts list.
Usage: {{- include "shoehorn.extraVolumeMounts" . | nindent 8 }}
*/}}
{{- define "shoehorn.extraVolumeMounts" -}}
{{- range .Values.extraVolumeMounts }}
- {{- mustToYaml . | nindent 2 }}
{{- end }}
{{- end -}}
