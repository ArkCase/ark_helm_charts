{{- define "arkcase.deployment.env" -}}
  {{- include "arkcase.subsystem-access.env" (dict "ctx" $ "subsys" "app" "key" "url" "name" "DEPL_URL") }}
{{- end -}}
