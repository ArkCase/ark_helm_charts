{{- define "arkcase.mariadb.rootPassword" -}}
  {{- default "admin" (.Values.configuration).rootPassword -}}
{{- end -}}

{{- define "arkcase.pentaho.datasource.params" -}}
  {{- $ctx := . -}}
  {{- if or (not $ctx) (not (kindIs "map" $ctx)) -}}
    {{- $ctx = dict -}}
  {{- end -}}
  {{- range $key, $value := $ctx -}}
{{ $key }}="{{ $value }}"
  {{- end -}}
{{- end -}}
