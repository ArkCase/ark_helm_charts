{{- define "arkcase.solr.maxUnavailable" -}}
  {{- /* Compute the number of replicas based on our formula */ -}}
  {{- $nodes := max 1 ($ | toString | atoi) -}}
  {{- $maxUnavailable := "50%" -}}
  {{- if ge $nodes 2 -}}
    {{- $replicas := (le $nodes 2) | ternary $nodes (div (add $nodes 1) 2) -}}
    {{- /* We can lose up to ($replicas - 1) nodes */ -}}
    {{- $maxUnavailable = printf "%d" (sub $replicas 1) -}}
  {{- end -}}
  {{- $maxUnavailable -}}
{{- end -}}
