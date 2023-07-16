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

{{- define "arkcase.core.content.url" -}}
  {{- if not (include "arkcase.isRootContext" $) -}}
    {{- fail "Must send the root context as the only parameter" -}}
  {{- end -}}

  {{- $contentUrl := (include "arkcase.tools.conf" (dict "ctx" $ "value" "content.url")) -}}
  {{- if not ($contentUrl) -}}
    {{- $dialect := (include "arkcase.tools.conf" (dict "ctx" $ "value" "content.dialect")) -}}
    {{- if or (not $dialect) (eq "alfresco" $dialect) -}}
      {{- $contentUrl = "http://content-main:8080/alfresco" -}}
    {{- else if (eq "s3" $dialect) -}}
      {{- $contentUrl = "http://content-minio:9000/" -}}
    {{- else -}}
      {{- fail (printf "Unsupported content dialect [%s]" $dialect) -}}
    {{- end -}}
  {{- end -}}
  {{- $contentUrl -}}
{{- end -}}

{{- define "arkcase.core.content.share" -}}
  {{- if not (include "arkcase.isRootContext" $) -}}
    {{- fail "Must send the root context as the only parameter" -}}
  {{- end -}}

  {{- $shareUrl := (include "arkcase.tools.conf" (dict "ctx" $ "value" "content.shareUrl")) -}}
  {{- if not ($shareUrl) -}}
    {{- $shareUrl = "http://content-share:8080/share" -}}
  {{- end -}}
  {{- $shareUrl -}}
{{- end -}}

{{- define "arkcase.core.foia" -}}
  {{- /* Do nothing just yet */ -}}
  {{- dict "enabled" false "springProfile" "FOIA_server" | toYaml -}}
{{- end -}}
