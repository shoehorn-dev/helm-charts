{{/*
Expand the name of the chart.
*/}}
{{- define "shoehorn-agent.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "shoehorn-agent.fullname" -}}
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
{{- define "shoehorn-agent.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "shoehorn-agent.labels" -}}
helm.sh/chart: {{ include "shoehorn-agent.chart" . }}
{{ include "shoehorn-agent.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Shoehorn ownership annotations
*/}}
{{- define "shoehorn-agent.annotations" -}}
{{- if .Values.annotations.shoehorn.team }}
shoehorn.dev/team: {{ .Values.annotations.shoehorn.team | quote }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "shoehorn-agent.selectorLabels" -}}
app.kubernetes.io/name: {{ include "shoehorn-agent.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "shoehorn-agent.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "shoehorn-agent.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Image name - constructs full image path from registry/repository:tag
*/}}
{{- define "shoehorn-agent.image" -}}
{{- $tag := .Values.image.tag | default .Chart.AppVersion }}
{{- printf "%s/%s:%s" .Values.image.registry .Values.image.repository $tag }}
{{- end }}

{{/*
Netobserver image - constructs full image path from registry/repository:tag
*/}}
{{- define "shoehorn-agent.netobserverImage" -}}
{{- $tag := .Values.netobserver.image.tag | default .Chart.AppVersion }}
{{- printf "%s/%s:%s" .Values.netobserver.image.registry .Values.netobserver.image.repository $tag }}
{{- end }}

{{/*
ConfigMap data for checksum calculation.
Must mirror configmap.yaml exactly so pod restarts on any config change.
*/}}
{{- define "shoehorn-agent.configmap" -}}
SHOEHORN_API_ENDPOINT: {{ .Values.shoehorn.apiURL | required "shoehorn.apiURL is required" | quote }}
SHOEHORN_CLUSTER_ID: {{ .Values.shoehorn.cluster.id | required "shoehorn.cluster.id is required" | quote }}
SHOEHORN_CLUSTER_NAME: {{ .Values.shoehorn.cluster.name | default .Values.shoehorn.cluster.id | quote }}
SHOEHORN_DASHBOARD_URL: {{ .Values.shoehorn.cluster.dashboardURL | quote }}
SHOEHORN_LOG_LEVEL: {{ .Values.agent.logLevel | quote }}
SHOEHORN_LOG_FORMAT: {{ .Values.agent.logFormat | quote }}
SHOEHORN_BATCH_INTERVAL: {{ .Values.agent.batchInterval | quote }}
SHOEHORN_BATCH_SIZE: {{ .Values.agent.batchSize | quote }}
SHOEHORN_PUSH_RETRIES: {{ .Values.agent.pushRetries | quote }}
SHOEHORN_PUSH_TIMEOUT: {{ .Values.agent.pushTimeout | quote }}
SHOEHORN_HEARTBEAT_INTERVAL: {{ .Values.agent.heartbeatInterval | quote }}
SHOEHORN_HEALTH_PORT: {{ .Values.agent.healthPort | quote }}
SHOEHORN_IN_CLUSTER: "true"
{{- if .Values.agent.kubernetes.namespaces }}
SHOEHORN_NAMESPACES: {{ .Values.agent.kubernetes.namespaces | join "," | quote }}
{{- end }}
{{- if .Values.agent.kubernetes.excludeNamespaces }}
SHOEHORN_EXCLUDE_NAMESPACES: {{ .Values.agent.kubernetes.excludeNamespaces | join "," | quote }}
{{- end }}
{{- if .Values.agent.kubernetes.labelSelector }}
SHOEHORN_LABEL_SELECTOR: {{ .Values.agent.kubernetes.labelSelector | quote }}
{{- end }}
{{- if .Values.agent.kubernetes.watchedKinds }}
SHOEHORN_WATCHED_KINDS: {{ .Values.agent.kubernetes.watchedKinds | join "," | quote }}
{{- end }}
{{- if .Values.agent.annotations }}
SHOEHORN_ANNOTATION_DEFAULT_BEHAVIOR: {{ .Values.agent.annotations.defaultBehavior | default "monitor-all" | quote }}
SHOEHORN_ANNOTATION_DEFAULT_LEVEL: {{ .Values.agent.annotations.defaultLevel | default "basic" | quote }}
{{- end }}
{{- if .Values.agent.metrics }}
SHOEHORN_METRICS_SAMPLE_INTERVAL: {{ .Values.agent.metrics.sampleInterval | default "5m" | quote }}
SHOEHORN_METRICS_WINDOW_HOURS: {{ .Values.agent.metrics.windowHours | default 168 | quote }}
{{- end }}
{{- if .Values.agent.gitops.tool }}
SHOEHORN_GITOPS_TOOL: {{ .Values.agent.gitops.tool | quote }}
SHOEHORN_GITOPS_WATCH_ALL_NAMESPACES: {{ .Values.agent.gitops.watchAllNamespaces | toString | quote }}
SHOEHORN_GITOPS_COMMAND_POLL_INTERVAL: {{ .Values.agent.gitops.commandPollInterval | default "10s" | quote }}
{{- if eq .Values.agent.gitops.tool "argocd" }}
SHOEHORN_GITOPS_ARGOCD_NAMESPACE: {{ .Values.agent.gitops.argocd.namespace | default "argocd" | quote }}
{{- if .Values.agent.gitops.argocd.serverURL }}
SHOEHORN_GITOPS_ARGOCD_SERVER_URL: {{ .Values.agent.gitops.argocd.serverURL | quote }}
{{- end }}
{{- end }}
{{- if eq .Values.agent.gitops.tool "fluxcd" }}
SHOEHORN_GITOPS_FLUXCD_NAMESPACE: {{ .Values.agent.gitops.fluxcd.namespace | default "flux-system" | quote }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Secret name — returns existingSecret if set, otherwise the chart-managed secret.
*/}}
{{- define "shoehorn-agent.secretName" -}}
{{- if .Values.shoehorn.existingSecret -}}
{{- .Values.shoehorn.existingSecret -}}
{{- else -}}
{{- include "shoehorn-agent.fullname" . -}}
{{- end -}}
{{- end -}}

{{/*
Secret key lookup from secretMappings.
Usage: {{ include "shoehorn-agent.secretKey" (dict "env" "SHOEHORN_API_TOKEN" "default" "api-token" "root" .) }}
*/}}
{{- define "shoehorn-agent.secretKey" -}}
{{- if and .root.Values.shoehorn.secretMappings (hasKey .root.Values.shoehorn.secretMappings .env) -}}
{{- index .root.Values.shoehorn.secretMappings .env -}}
{{- else -}}
{{- .default -}}
{{- end -}}
{{- end -}}

{{/*
Secret data for checksum calculation (only when chart manages the secret).
*/}}
{{- define "shoehorn-agent.secret" -}}
{{- if not .Values.shoehorn.existingSecret -}}
api-token: {{ .Values.shoehorn.apiToken | required "shoehorn.apiToken is required (or set shoehorn.existingSecret)" | quote }}
{{- if and (eq (.Values.agent.gitops.tool | default "") "argocd") .Values.agent.gitops.argocd.token }}
argocd-token: {{ .Values.agent.gitops.argocd.token | quote }}
{{- end }}
{{- end -}}
{{- end }}

