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
  {{- include "arkcase.subsystem-access.volumeMount.admin" (dict "ctx" $ "subsys" "acme" "key" "password" "mountPath" "/.acme.password") -}}
{{- end -}}

{{- define "arkcase.acme.volume" -}}
  {{- include "arkcase.subsystem-access.volume.admin" (dict "ctx" $ "subsys" "acme") -}}
{{- end -}}
