{{- define "arkcase.solr.maxFailed" -}}
  {{- $nodes := (include "arkcase.cluster.nodes" $ | atoi) -}}
  {{- /* Compute the number of replicas based on our formula */ -}}
  {{- $replicas := (le $nodes 2) | ternary $nodes (div (add $nodes 1) 2) -}}
  {{- /* We can lose up to ($replicas - 1) nodes */ -}}
  {{- sub $replicas 1 -}}
{{- end -}}
