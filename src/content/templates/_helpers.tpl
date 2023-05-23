{{- define "arkcase.alfresco.searchSecret" -}}
  {{- if not (include "arkcase.isRootContext" $) -}}
    {{- fail "The parameter must be the root context" -}}
  {{- end -}}

  {{- $fullname := (include "common.fullname" $) -}}
  {{- $secretKey := (printf "%s-searchSecret" $fullname) -}}
  {{- if not (hasKey $ $secretKey) -}}
    {{- $newSecret := (randAlphaNum 63 | b64enc) -}}
    {{- $crap := set $ $secretKey $newSecret -}}
    {{- $secretKey = $newSecret -}}
  {{- else -}}
    {{- $secretKey = get $ $secretKey -}}
  {{- end -}}
  {{- $secretKey -}}
{{- end -}}

{{- define "arkcase.alfresco.service" -}}
  {{- $ctx := .ctx -}}
  {{- $name := .name -}}
  {{- printf "%s-%s" (include "common.name" $ctx) $name -}}
{{- end -}}

{{- define "arkcase.content.external" -}}
  {{- $url := (include "arkcase.tools.conf" (dict "ctx" $ "value" "content.url" "detailed" true) | fromYaml) -}}
  {{- if and $url $url.global -}}
    {{- true -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.content.engine" -}}
  {{- if not (include "arkcase.isRootContext" $) -}}
    {{- fail "The parameter must be the root context" -}}
  {{- end -}}
  {{- $content := ($.Values.global).content | default dict -}}
  {{- if not (kindIs "map" $content) -}}
    {{- $content = dict -}}
  {{- end -}}

  {{- /* This is the default engine to use */ -}}
  {{- $engine := "alfresco" -}}
  {{- if (hasKey $content "engine" -}}
    {{- $engine = ($content.engine | toString | lower) -}}
    {{- if and (ne "s3" $engine) (ne "alfresco" $engine) -}}
      {{- fail (printf "Unknown content engine [%s] set (global.content.engine)" $engine) -}}
    {{- end -}}
  {{- end -}}
  {{- $engine -}}
{{- end -}}

{{- define "arkcase.content.minio.nodeCount" -}}
  {{- if not (include "arkcase.isRootContext" $) -}}
    {{- fail "The parameter must be the root context" -}}
  {{- end -}}
  {{- $nodes := (include "arkcase.tools.conf" (dict "ctx" $ "value" "content.minio.nodes" "detailed" true) | fromYaml) -}}
  {{- if and $nodes $nodes.global -}}
    {{- $nodes = ($nodes | toString | atoi) -}}
  {{- end -}}

  {{- if lt $nodes 1 -}}
    {{- $nodes = 1 -}}
  {{- else if gt $nodes 1 -}}
    {{- /* The node count must be a multiple of 4 or 16 */ -}}
    {{- $mod4 := (mod $nodes 4) -}}
    {{- $mod16 := (mod $nodes 4) -}}
    {{- if and (ne $mod4 0) (ne $mod16 0) -}}
      {{- fail (printf "The number of nodes must be a multiple of 4 or 16: %d" $nodes) -}}
    {{- end -}}
  {{- end -}}
  {{- $nodes -}}
{{- end -}}
