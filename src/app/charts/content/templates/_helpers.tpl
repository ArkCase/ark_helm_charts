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

{{- define "arkcase.alfresco.service.env" -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The parameter must be the root context" -}}
  {{- end -}}

  {{- $result := list -}}
  {{- $common := (include "common.name" $ctx) -}}
  {{- range $part := (list "main" "share" "activemq" "search" "sfs" "xform-core-aio" "xform-router") -}}
    {{- $result = append $result (
        dict
          "name" (printf "SERVICE_ALFRESCO_%s" ($part | replace "-" "_" | replace "." "_" | upper))
          "value" (printf "%s-%s" $common $part)
      )
    -}}
  {{- end -}}
  {{- if $result -}}
    {{- $result | toYaml -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.content.info.dialect" -}}
  {{- if not (include "arkcase.isRootContext" $) -}}
    {{- fail "The parameter must be the root context" -}}
  {{- end -}}
  {{- $content := (include "arkcase.cm.info" $ | fromYaml) -}}
  {{- $content.dialect -}}
{{- end -}}

{{- define "arkcase.content.minio.nodeCount" -}}
  {{- if not (include "arkcase.isRootContext" $) -}}
    {{- fail "The parameter must be the root context" -}}
  {{- end -}}

  {{- $content := (include "arkcase.cm.info" $ | fromYaml) -}}
  {{- $nodes := ($content.nodes | default 1 | toString | atoi) -}}
  {{- if (lt $nodes 1) -}}
    {{- $nodes = 1 -}}
  {{- else if (gt $nodes 1) -}}
    {{- /* The node count must be a multiple of 4 or 16 */ -}}
    {{- $mod4 := (mod $nodes 4) -}}
    {{- $mod16 := (mod $nodes 4) -}}
    {{- if and (ne $mod4 0) (ne $mod16 0) -}}
      {{- fail (printf "The number of nodes must be a multiple of 4 or 16: %d" $nodes) -}}
    {{- end -}}
  {{- end -}}
  {{- $nodes -}}
{{- end -}}

{{- define "arkcase.content.minio.nodes" -}}
  {{- if not (include "arkcase.isRootContext" $) -}}
    {{- fail "The parameter must be the root context" -}}
  {{- end -}}

  {{- $content := (include "arkcase.cm.info" $ | fromYaml) -}}
  {{- $nodes := ($content.nodes | default 1 | toString) -}}

  {{- /* If it's not set at all, use the default of 1 node */ -}}
  {{- if not $nodes -}}
    {{- $nodes = "0" -}}
  {{- else if not (regexMatch "^[0-9]+$" $nodes) -}}
    {{- fail (printf "The nodes value [%s] is not valid - it must be a numeric value" $nodes) -}}
  {{- end -}}

  {{- /* Remove leading zeros */ -}}
  {{- $nodes = (regexReplaceAll "^0+" $nodes "") -}}

  {{- /* In case it nuked the whole string :D */ -}}
  {{- $nodes = (empty $nodes) | ternary 0 (atoi $nodes) -}}
  {{- $pad := 0 -}}
  {{- if not (mod $nodes 2) -}}
    {{- /* It's an even number ... add one to support at least the given number of nodes */ -}}
    {{- $pad = 1 -}}
  {{- end -}}
  {{- $nodes = add $nodes $pad -}}

  {{- /* We have a hard limit of 255 nodes */ -}}
  {{- (gt $nodes 255) | ternary 255 $nodes -}}
{{- end -}}

{{- define "arkcase.content.minio.onePerHost" -}}
  {{- $onePerHost := (include "arkcase.tools.conf" (dict "ctx" $ "value" "onePerHost")) -}}
  {{- if (include "arkcase.toBoolean" $onePerHost) -}}
    {{- true -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.content.minio.minAvailable" -}}
  {{- $nodes := (include "arkcase.content.minio.nodes" $ | atoi) -}}
  {{- /* We can lose at most half of our nodes */ -}}
  {{- div (add $nodes 1) 2 -}}
{{- end -}}

{{- define "arkcase.content.indexing" -}}
  {{- if not (include "arkcase.isRootContext" $) -}}
    {{- fail "The parameter must be the root context" -}}
  {{- end -}}

  {{- $content := (include "arkcase.cm.info" $ | fromYaml) -}}
  {{- if or (not (hasKey $content "indexing")) (include "arkcase.toBoolean" $content.indexing) -}}
    {{- true -}}
  {{- end -}}
{{- end -}}
