{{- define "arkcase.solr.maxUnavailable" -}}
  {{- /* Allow losing up to half our pods */ -}}
  {{- (div (max 1 ($ | toString | atoi)) 2) -}}
{{- end -}}
