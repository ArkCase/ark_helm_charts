{{- define "arkcase.postgres.rootPassword" -}}
  {{- default "admin" (.Values.configuration).rootPassword -}}
{{- end -}}
