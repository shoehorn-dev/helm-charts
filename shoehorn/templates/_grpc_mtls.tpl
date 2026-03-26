{{/*
gRPC mTLS volume mounts (add to volumeMounts section)
*/}}
{{- define "shoehorn.grpcMtlsVolumeMounts" -}}
{{- if .Values.global.mtls.enabled }}
- name: grpc-certs
  mountPath: /etc/shoehorn/certs
  readOnly: true
{{- end }}
{{- end }}

{{/*
gRPC mTLS volumes (add to volumes section)
*/}}
{{- define "shoehorn.grpcMtlsVolumes" -}}
{{- if .Values.global.mtls.enabled }}
- name: grpc-certs
  secret:
    secretName: {{ include "shoehorn.fullname" . }}-grpc-mtls-cert
    defaultMode: 0400
{{- end }}
{{- end }}
