{{- define "arkcase.get-existing.config" -}}
  {{- $ctx := $.ctx -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "Must provide the root context as the 'ctx' parameter" -}}
  {{- end -}}

  {{- $resource := ((not (empty (include "arkcase.toBoolean" $.secret))) | ternary "Secret" "ConfigMap") -}}
  {{- $name := $.name -}}
  {{- if not (include "arkcase.tools.hostnamePart" $name) -}}
    {{- fail (printf "The resource name [%s] is not a valid %s name" $name $resource) -}}
  {{- end -}}

  {{- $result := dict -}}
  {{- if or $ctx.Release.IsUpgrade (not (empty (include "arkcase.toBoolean" $.always))) -}}
    {{- $obj := (lookup "v1" $resource $ctx.Release.Namespace $name) -}}
    {{- $key := "data" -}}
    {{- $result = ((hasKey $obj $key) | ternary (get $obj $key) dict | default dict) -}}
  {{- end -}}
  {{- $result | toYaml -}}
{{- end -}}
