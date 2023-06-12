{{- define "arkcase.zookeeper.external" -}}
  {{- $url := (include "arkcase.tools.conf" (dict "ctx" $ "value" "search.url" "detailed" true) | fromYaml) -}}
  {{- if and $url $url.global -}}
    {{- true -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.zookeeper.nodes" -}}
  {{- $nodes := (include "arkcase.tools.conf" (dict "ctx" $ "value" "nodes")) -}}

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

{{- define "arkcase.zookeeper.onePerHost" -}}
  {{- $onePerHost := (include "arkcase.tools.conf" (dict "ctx" $ "value" "onePerHost")) -}}
  {{- if (include "arkcase.toBoolean" $onePerHost) -}}
    {{- true -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.zookeeper.maxFailed" -}}
  {{- $nodes := (include "arkcase.zookeeper.nodes" $ | atoi) -}}
  {{- /* We can lose at most half of our nodes */ -}}
  {{- div $nodes 2 -}}
{{- end -}}
