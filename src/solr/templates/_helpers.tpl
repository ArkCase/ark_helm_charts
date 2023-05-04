{{- define "arkcase.solr.external" -}}
  {{- $url := (include "arkcase.tools.conf" (dict "ctx" $ "value" "search.url" "detailed" true) | fromYaml) -}}
  {{- if and $url $url.global -}}
    {{- true -}}
  {{- end -}}
{{- end -}}
