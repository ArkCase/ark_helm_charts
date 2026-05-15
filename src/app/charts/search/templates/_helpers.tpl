{{- define "arkcase.solr.scale" -}}
  {{- $cluster := (include "arkcase.cluster" $ | fromYaml) }}
  {{- $nodes := ($cluster.replicas | int) -}}
  {{- /* remember to store the numbers as strings!! */ -}}
  {{- $scale := dict "replicas" "1" "shards" "1" "loss" "0" "nodes" ($nodes | toString) -}}
  {{- if (gt $nodes 1) -}}
    {{- /* We need fewer replicas than nodes b/c we want to spread the load */ -}}
    {{- $replicas := (add (div $nodes 2) 1) -}}
    {{- $scale = set $scale "replicas" ($replicas | toString) -}}

    {{- /* make sure we have plenty of shards to go around for all nodes */ -}}
    {{- $shards := (add (sub $nodes $replicas) 1) -}}
    {{- $scale = set $scale "shards" ($shards | toString) -}}

    {{- /* we can lose all but one replica for any shard! */ -}}
    {{- $loss := sub $replicas 1 -}}
    {{- $scale = set $scale "loss" ($loss | toString) -}}
  {{- end -}}
  {{- $scale | toYaml -}}
{{- end -}}
