{{- define "arkcase.solr.maxFailed" -}}
  {{- $nodes := (include "arkcase.cluster.nodes" $) -}}
  {{- div $nodes 2 -}}
{{- end -}}
