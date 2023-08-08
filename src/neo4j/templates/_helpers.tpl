{{- define "arkcase.neo4j.external" -}}
  {{- $hostname := (include "arkcase.tools.conf" (dict "ctx" $ "value" "analytics.hostname" "detailed" true) | fromYaml) -}}
  {{- if and $hostname $hostname.global -}}
    {{- true -}}
  {{- end -}}
{{- end -}}
