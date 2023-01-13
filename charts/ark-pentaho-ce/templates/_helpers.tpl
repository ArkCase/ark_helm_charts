{{- define "arkcase.mariadb.rootPassword" -}}
  {{- default "admin" (.Values.configuration).rootPassword -}}
{{- end -}}
