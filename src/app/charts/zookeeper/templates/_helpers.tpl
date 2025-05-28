{{- define "arkcase.zookeeper.external" -}}
  {{- $url := (include "arkcase.tools.conf" (dict "ctx" $ "value" "zookeeper.url" "detailed" true) | fromYaml) -}}
  {{- if and $url $url.global -}}
    {{- true -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.zookeeper.replicas" -}}
  {{- $cluster := (include "arkcase.cluster" $ | fromYaml) -}}
  {{- $replicas := (max 1 ($cluster.replicas | int)) -}}
  {{- $pad := 0 -}}
  {{- if not (mod $replicas 2) -}}
    {{- /* It's an even number ... add one to support at least the given number of replicas */ -}}
    {{- $pad = 1 -}}
  {{- end -}}

  {{- /* We have a hard limit of 255 replicas */ -}}
  {{- min 255 (add $replicas $pad) -}}
{{- end -}}

{{- define "__arkcase.zookeeper.zkhost.default" -}}
  {{- $zkHost := list -}}
  {{- $release := $.Release.Name -}}
  {{- $subsystem := (include "arkcase.subsystem.name" $) -}}
  {{- $podDomain := (include "arkcase.service.headless" $) -}}
  {{- $port := 2181 -}}
  {{- $replicas := (include "arkcase.zookeeper.replicas" $ | atoi) -}}
  {{- range $id := (until $replicas) -}}
    {{- $zkHost = append $zkHost (printf "%s-%s-%d.%s:%d" $release $subsystem $id $podDomain $port) -}}
  {{- end -}}
  {{- $zkHost | join "," -}}
{{- end -}}

{{- define "arkcase.zookeeper.zkhost" -}}
  {{- $external := (include "arkcase.tools.conf" (dict "ctx" $ "value" "zookeeper.url" "detailed" true) | fromYaml) -}}
  {{- if and $external.global $external.value -}}
    {{- $external.value -}}
  {{- else -}}
    {{- include "__arkcase.zookeeper.zkhost.default" $ -}}
  {{- end -}}
{{- end -}}
