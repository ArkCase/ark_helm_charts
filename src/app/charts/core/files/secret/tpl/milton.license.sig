{{- $milton := (include "arkcase.license" (dict "ctx" $ "name" "milton") | fromYaml) -}}
{{- if and $milton $milton.data $milton.data.signature -}}
  {{- $milton.data.signature | b64dec -}}
{{- else -}}
<!-- no milton license signature configured -->
{{- end -}}
