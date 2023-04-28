{{- define "arkcase.rdbms.external" -}}
  {{- $hostname := (include "arkcase.tools.conf" (dict "ctx" $ "value" "rdbms.hostname" "detailed" true) | fromYaml) -}}
  {{- if and $hostname $hostname.global -}}
    {{- true -}}
  {{- end -}}
{{- end -}}
