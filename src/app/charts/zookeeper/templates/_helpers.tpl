{{- define "arkcase.zookeeper.external" -}}
  {{- $url := (include "arkcase.tools.conf" (dict "ctx" $ "value" "zookeeper.url" "detailed" true) | fromYaml) -}}
  {{- if and $url $url.global -}}
    {{- true -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.zookeeper.nodes" -}}
  {{- $nodes := max 1 ($ | toString | atoi) -}}
  {{- $pad := 0 -}}
  {{- if not (mod $nodes 2) -}}
    {{- /* It's an even number ... add one to support at least the given number of nodes */ -}}
    {{- $pad = 1 -}}
  {{- end -}}

  {{- /* We have a hard limit of 255 nodes */ -}}
  {{- min 255 (add $nodes $pad) -}}
{{- end -}}

{{- define "__arkcase.zookeeper.zkhost.default" -}}
  {{- $cluster := (include "arkcase.cluster" $ | fromYaml) }}
  {{- $zkHost := list -}}
  {{- if $cluster.enabled -}}
    {{- $release := $.Release.Name -}}
    {{- $subsystem := (include "arkcase.subsystem.name" $) -}}
    {{- $podDomain := (include "arkcase.service.headless" $) -}}
    {{- $port := 2181 -}}
    {{- $nodes := (include "arkcase.zookeeper.nodes" $cluster.nodes | atoi) -}}
    {{- range $id := (until $nodes) -}}
      {{- $zkHost = append $zkHost (printf "%s-%s-%d.%s:%d" $release $subsystem $id $podDomain $port) -}}
    {{- end -}}
  {{- end -}}
  {{- $zkHost | join "," -}}
{{- end -}}

{{- define "arkcase.zookeeper.zkhost" -}}
  {{- $cluster := (include "arkcase.cluster" $ | fromYaml) }}
  {{- if $cluster.enabled -}}
    {{- $external := (include "arkcase.tools.conf" (dict "ctx" $ "value" "zookeeper.url" "detailed" true) | fromYaml) -}}
    {{- if and $external.global $external.value -}}
      {{- $external.value -}}
    {{- else -}}
      {{- include "__arkcase.zookeeper.zkhost.default" $ -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.zookeeper.minAvailable" -}}
  {{- $nodes := max 1 ($ | toString | atoi) -}}
  {{- /* We can lose at most half of our nodes */ -}}
  {{- div (add $nodes 1) 2 -}}
{{- end -}}
