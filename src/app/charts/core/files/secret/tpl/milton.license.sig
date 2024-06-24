{{- $milton := (include "arkcase.license" (dict "ctx" $ "name" "milton") | fromYaml) -}}
{{- if and $milton $milton.signature -}}
  {{- $milton.signature | b64dec -}}
{{- else -}}
<!-- no milton license signature configured -->
{{- end -}}
