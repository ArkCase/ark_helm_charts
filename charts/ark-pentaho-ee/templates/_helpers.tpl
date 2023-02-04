{{- define "arkcase.mariadb.rootPassword" -}}
  {{- default "admin" (.Values.configuration).rootPassword -}}
{{- end -}}

{{- define "arkcase.pentaho.datasource.params" -}}
  {{- $ctx := . -}}
  {{- if or (not $ctx) (not (kindIs "map" $ctx)) -}}
    {{- $ctx = dict -}}
  {{- end -}}
{{- /* This isn't indented to make it easier to render it properly */ -}}
{{- range $key, $value := $ctx -}}
{{ $key }}="{{ $value }}"
{{ end -}}
{{- /* End unindented block */ -}}
{{- end -}}
