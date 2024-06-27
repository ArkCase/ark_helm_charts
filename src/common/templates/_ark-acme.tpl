{{- define "arkcase.acme.env" -}}
  {{- if not (include "arkcase.isRootContext" $) -}}
    {{- fail "The parameter given must be the root context (. or $)" -}}
  {{- end -}}
- name: SSL_DIR
  value: "/.ssl"
- name: ACME_SERVICE_NAME
  value: {{ include "arkcase.service.name" $ | quote }}
{{ include "arkcase.subsystem-access.env.conn" (dict "ctx" $ "subsys" "acme" "key" "url" "name" "ACME_URL") }}
{{- end -}}

{{- define "arkcase.acme.volumeMount" -}}
  {{- if not (include "arkcase.isRootContext" $) -}}
    {{- fail "The parameter given should be the root context (. or $)" -}}
  {{- end -}}
  {{- include "arkcase.subsystem-access.volumeMount.admin" (dict "ctx" $ "subsys" "acme" "key" "password" "mountPath" "/.acme.password") | nindent 0}}
{{- end -}}

{{- define "arkcase.acme.volumeMount-shared" -}}
  {{- include "arkcase.acme.volumeMount" $ | nindent 0 }}
- name: "acme-ssl-vol"
  mountPath: "/.ssl"
{{- end -}}

{{- define "arkcase.acme.volume" -}}
  {{- if not (include "arkcase.isRootContext" $) -}}
    {{- fail "The parameter given should be the root context (. or $)" -}}
  {{- end -}}
  {{- include "arkcase.subsystem-access.volume.admin" (dict "ctx" $ "subsys" "acme") | nindent 0}}
{{- end -}}

{{- define "arkcase.acme.volume-shared" -}}
  {{- include "arkcase.acme.volume" $ | nindent 0 }}
# The shared certificates volume is laughably tiny
- name: "acme-ssl-vol"
  emptyDir:
    medium: "Memory"
    sizeLimit: 4Mi
{{- end -}}
