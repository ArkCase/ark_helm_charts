{{- define "arkcase.app.image.artifacts" -}}
  {{- $imageName := "artifacts" -}}
  {{- $foia := (include "arkcase.foia" $.ctx | fromYaml) -}}
  {{- if $foia -}}
    {{- $imageName = (printf "%s-foia" $imageName) -}}
  {{- end -}}
  {{- $param := (merge (dict "name" $imageName) (omit $ "name")) -}}
  {{- include "arkcase.image" $param }}
{{- end -}}

{{- define "arkcase.artifacts.external" -}}
  {{- $url := (include "arkcase.tools.conf" (dict "ctx" $ "value" "artifacts.url" "detailed" true) | fromYaml) -}}
  {{- if or (and $url $url.global) -}}
    {{- true -}}
  {{- end -}}
{{- end -}}
