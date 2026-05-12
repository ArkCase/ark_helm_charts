{{- /*
use an algorithm to determine this ... the number of shards should be half the number of Solr cluster nodes, and the number of replicas should be half the number of shards + 1 ... or so ... I forget ... I'll fix this up shortly :D
*/ -}}
{{- define "arkcase.core.search.shards" -}}
2
{{- end -}}

{{- define "arkcase.core.search.replicas" -}}
2
{{- end -}}

{{- define "arkcase.core.search.env" -}}
- name: SOLR_COLLECTION_SHARDS
  value: {{ include "arkcase.core.search.shards" $ | toString | quote }}
- name: SOLR_COLLECTION_REPLICAS
  value: {{ include "arkcase.core.search.replicas" $ | toString | quote }}
{{- end -}}
