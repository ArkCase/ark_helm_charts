{{- define "arkcase.solr.maxFailed" -}}
  {{- /* Compute the number of replicas based on our formula */ -}}
  {{- $nodes := max 1 ($ | toString | atoi) -}}
  {{- $replicas := (le $nodes 2) | ternary $nodes (div (add $nodes 1) 2) -}}
  {{- /* We can lose up to ($replicas - 1) nodes */ -}}
  {{- sub $replicas 1 -}}
{{- end -}}
