{{- define "arkcase.deployment.env" -}}
  {{- if not (include "arkcase.isRootContext" $) -}}
    {{- fail "The parameter given must be the root context (. or $)" -}}
  {{- end -}}
  {{- include "arkcase.subsystem-access.env.admin" (dict "ctx" $ "subsys" "app" "key" "url" "name" "DEPL_URL") }}
{{- end -}}
