{{- define "arkcase.neo4j.external" -}}
  {{- $hostname := (include "arkcase.tools.conf" (dict "ctx" $ "value" "analytics.hostname" "detailed" true) | fromYaml) -}}
  {{- if and $hostname $hostname.global -}}
    {{- true -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.neo4j.enabled" -}}
  {{- if and (include "arkcase.subsystem.enabled" $) (not (include "arkcase.neo4j.external" $)) -}}
    {{- (not (empty (include "arkcase.portal" $ | fromYaml))) | ternary "true" "" -}}
  {{- end -}}
{{- end -}}
