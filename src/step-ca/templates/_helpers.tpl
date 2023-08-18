{{- define "arkcase.acme.external" -}}
  {{- if not (include "arkcase.isRootContext" $) -}}
    {{- fail "The parameter given must be the root context ($ or .)" -}}
  {{- end -}}
  {{- $acme := (include "arkcase.tools.conf" (dict "ctx" $ "value" "acme.url" "detailed" true)) -}}
  {{- if and $acme $acme.found $acme.global $acme.value -}}
    {{- true -}}
  {{- fi -}}
{{- end -}}
