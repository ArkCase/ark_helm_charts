{{- define "arkcase.artemis.admin" -}}
  {{- $admin := (include "arkcase.tools.conf" (dict "ctx" $ "value" "admin" "detailed" true) | fromYaml) -}}
  {{- with $admin.value -}}
    {{- . | toYaml  -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.artemis.users" -}}
  {{- $declaredUsers := (include "arkcase.tools.conf" (dict "ctx" $ "value" "users" "detailed" true) | fromYaml) -}}
  {{- with $declaredUsers.value -}}
    {{- . | toYaml  -}}
  {{- end -}}
{{- end -}}
