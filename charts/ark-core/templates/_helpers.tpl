{{- define "arkcase.core.configPriority" -}}
  {{- $ctx := . -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "Must send the root context as the only parameter" -}}
  {{- end -}}

  {{- with (include "arkcase.tools.conf" (dict "ctx" $ctx "value" "priorities")) -}}
    {{- $priority := . -}}
    {{- if not (kindIs "string" $priority) -}}
      {{- fail "The priority list must be a comma-separated list" -}}
    {{- end -}}
    {{- $result := list -}}
    {{- range $i := splitList "," $priority -}}
      {{- /* Skip empty elements */ -}}
      {{- if $i -}}
        {{- $result = append $result $i -}}
      {{- end -}}
    {{- end -}}
    {{- $priority = "" -}}
    {{- if $result -}}
      {{- $priority = (printf "%s," (join "," $result)) -}}
    {{- end -}}
    {{- $priority -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.core.messaging.openwire" -}}
  {{- $messaging := (include "arkcase.tools.parseUrl" (include "arkcase.tools.conf" (dict "ctx" $ "value" "messaging.url")) | fromYaml) }}
  {{- $scheme := ($messaging.scheme | default "tcp") -}}
  {{- $host := ($messaging.host | default "messaging") -}}
  {{- $port := (include "arkcase.tools.conf" (dict "ctx" $ "value" "messaging.openwire") | default "61616" | int) -}}
  {{- printf "%s://%s:%d" $scheme $host $port -}}
{{- end -}}
