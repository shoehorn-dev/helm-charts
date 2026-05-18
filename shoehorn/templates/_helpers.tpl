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
Return the proper component image name.
Each component specifies its full image repository (e.g., shoehorned/shoehorn-api).
Tag precedence: component.image.tag > .Values.image.tag.
Shoehorn does not publish a `:latest` tag. Render fails if no tag is set.
*/}}
{{- define "shoehorn.componentImage" -}}
{{- $componentRepo := .component.image.repository -}}
{{- $tag := .component.image.tag | default .Values.image.tag -}}
{{- if not $tag -}}
{{- fail (printf "shoehorn.componentImage: no tag set for %s. Set component.image.tag or .Values.image.tag (Shoehorn does not publish :latest)." $componentRepo) -}}
{{- end -}}
{{- printf "%s:%s" $componentRepo $tag -}}
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
Validate required plain values at template render time.
Each *SecretRef is validated by the shoehorn.secretRef helper itself when called.
*/}}
{{- define "shoehorn.validateValues" -}}
{{- if or (not .Values.global.domain) (eq .Values.global.domain "idp.example.com") (eq .Values.global.domain "shoehorn.example.com") -}}
  {{- fail "\n\nglobal.domain is required. Set it to the hostname customers will use to reach Shoehorn on your infra (e.g. idp.acme.internal). Pass --set global.domain=YOUR_DOMAIN or override it in your values file." -}}
{{- end -}}
{{- if .Values.ingressRoute.enabled -}}
  {{/* The kube-system lookup tells us whether `lookup` has live cluster access.
       During `helm template` (offline), every lookup returns nil and we must
       skip the CRD check or we'd block CI dry-runs. During `helm install`,
       kube-system exists so we run the real Traefik CRD check. */}}
  {{- $kubeSystem := lookup "v1" "Namespace" "" "kube-system" -}}
  {{- if $kubeSystem -}}
    {{- $crd := lookup "apiextensions.k8s.io/v1" "CustomResourceDefinition" "" "ingressroutes.traefik.io" -}}
    {{- if not $crd -}}
      {{- fail "\n\ningressRoute.enabled is true but the Traefik CRD ingressroutes.traefik.io is not installed in this cluster. Either install Traefik (see chart README Prerequisites) or switch to standard Ingress: --set ingressRoute.enabled=false --set ingress.enabled=true." -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- if eq .Values.auth.provider "zitadel" -}}
  {{- if not .Values.auth.zitadel.projectId -}}
    {{- fail "\n\nauth.zitadel.projectId is required when auth.provider is 'zitadel'." -}}
  {{- end -}}
  {{- if not .Values.auth.zitadel.clientId -}}
    {{- fail "\n\nauth.zitadel.clientId is required when auth.provider is 'zitadel'." -}}
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
Typed-ref secret environment variable.

Each credential lives under its owner block as a `*SecretRef` shaped like
Kubernetes' native valueFrom.secretKeyRef:

  database:
    passwordSecretRef:
      name: shoehorn-db          # optional if secret.defaultName is set
      key:  db_password           # required if the env var is required

The helper resolves `name` to `ref.name` first, then falls back to
`secret.defaultName`.

Usage (required ref):
  {{- include "shoehorn.secretRef" (dict
       "env"  "DB_PASSWORD"
       "ref"  .Values.database.passwordSecretRef
       "root" .) | nindent 8 }}

Usage (optional ref, omits the env var if `ref.key` is unset):
  {{- include "shoehorn.secretRef" (dict
       "env"  "ARGOCD_TOKEN"
       "ref"  .Values.auth.argocd.tokenSecretRef
       "root" .
       "optional" true) | nindent 8 }}

Behavior:
  1. If ref.key is non-empty: emit valueFrom.secretKeyRef (resolved name + key).
  2. Else if optional: emit nothing.
  3. Else: fail with a clear error pointing at the env var.
*/}}
{{- define "shoehorn.secretRef" -}}
{{- $env := required "shoehorn.secretRef: env is required" .env -}}
{{- $optional := .optional | default false -}}
{{- $key := "" -}}
{{- $refName := "" -}}
{{- if .ref -}}
{{- $key = (get .ref "key") | default "" -}}
{{- $refName = (get .ref "name") | default "" -}}
{{- end -}}
{{- $defaultName := (get (.root.Values.secret | default dict) "defaultName") | default "" -}}
{{- $name := $refName | default $defaultName -}}
{{- if $key -}}
{{- if not $name -}}
{{- fail (printf "\n\nCannot resolve secret name for env %s.\nSet the *SecretRef.name field or set secret.defaultName at the top level.\n" $env) -}}
{{- end }}
- name: {{ $env }}
  valueFrom:
    secretKeyRef:
      name: {{ $name }}
      key: {{ $key }}
{{- else if not $optional -}}
{{- fail (printf "\n\nMissing required SecretRef for env %s.\nSet the corresponding *SecretRef.key in values, or set secret.defaultName and provide a key.\nSee the chart README 'Secret configuration' section for the full list of *SecretRef paths.\n" $env) -}}
{{- end -}}
{{- end -}}

{{/*
Extra volumes. Renders user-provided extraVolumes list.
Usage: {{- include "shoehorn.extraVolumes" . | nindent 6 }}
*/}}
{{- define "shoehorn.extraVolumes" -}}
{{- range .Values.extraVolumes }}
- {{- toYaml . | nindent 2 }}
{{- end }}
{{- end -}}

{{/*
Extra volume mounts. Renders user-provided extraVolumeMounts list.
Usage: {{- include "shoehorn.extraVolumeMounts" . | nindent 8 }}
*/}}
{{- define "shoehorn.extraVolumeMounts" -}}
{{- range .Values.extraVolumeMounts }}
- {{- toYaml . | nindent 2 }}
{{- end }}
{{- end -}}
