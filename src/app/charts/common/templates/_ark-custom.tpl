{{- define "arkcase.customization" -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The single parameter must be the root context ($ or .)" -}}
  {{- end -}}

  {{- $custom := (include "arkcase.tools.conf" (dict "ctx" $ctx "value" "customization" "detailed" true) | fromYaml) -}}
  {{- if and $custom $custom.value (eq "string" $custom.type) -}}
    {{- if not (regexMatch "^[-a-zA-Z0-9_]+$" $custom.value) -}}
      {{- fail (printf "Invalid format for the customization name (global.conf.customization): [%s]" $custom.value) -}}
    {{- end -}}
    {{- $custom = $custom.value -}}
  {{- else -}}
    {{- $custom = "custom" -}}
  {{- end -}}

  {{- /* The customization name should always be in lowercase */ -}}
  {{- $custom | lower -}}
{{- end -}}
