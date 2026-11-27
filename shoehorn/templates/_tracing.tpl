{{/*
CA for the tracing collector (global.tracing.caSecretRef). Outside development
the services only send traces over TLS; this lets a collector outside the gRPC
mesh be verified with its own CA. The services read it from
OTEL_EXPORTER_OTLP_TRACES_CERTIFICATE, ahead of the mesh CA.
*/}}
{{- define "shoehorn.tracingCaConfigured" -}}
{{- $ref := .Values.global.tracing.caSecretRef | default dict -}}
{{- if (get $ref "key") }}true{{ end -}}
{{- end }}

{{- define "shoehorn.tracingCaEnv" -}}
{{- if include "shoehorn.tracingCaConfigured" . }}
- name: OTEL_EXPORTER_OTLP_TRACES_CERTIFICATE
  value: "/etc/shoehorn/tracing-ca/ca.crt"
{{- end }}
{{- end }}

{{- define "shoehorn.tracingCaVolumeMounts" -}}
{{- if include "shoehorn.tracingCaConfigured" . }}
- name: tracing-ca
  mountPath: /etc/shoehorn/tracing-ca
  readOnly: true
{{- end }}
{{- end }}

{{- define "shoehorn.tracingCaVolumes" -}}
{{- if include "shoehorn.tracingCaConfigured" . }}
{{- $ref := .Values.global.tracing.caSecretRef }}
{{- $name := (get $ref "name") | default ((.Values.secret | default dict).defaultName | default "") }}
{{- if not $name }}
{{- fail "\n\nglobal.tracing.caSecretRef: set its name, or secret.defaultName at the top level.\n" }}
{{- end }}
- name: tracing-ca
  secret:
    secretName: {{ $name }}
    items:
      - key: {{ get $ref "key" }}
        path: ca.crt
    defaultMode: 0444
{{- end }}
{{- end }}
