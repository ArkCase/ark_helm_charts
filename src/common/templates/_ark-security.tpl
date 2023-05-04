{{- define "arkcase.serviceAccountName" -}}
  {{- $global := (include "arkcase.tools.get" (dict "ctx" $ "name" "Values.global.security.serviceAccountName") | fromYaml) -}}
  {{- if and $global $global.value -}}
    {{- $global.value -}}
  {{- else -}}
    {{- include "common.serviceAccountName" . -}}
  {{- end -}}
{{- end -}}
