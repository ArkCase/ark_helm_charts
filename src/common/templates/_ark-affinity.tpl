{{- define "__arkcase.node-affinity.match" -}}
  {{- $type := ($.type | toString | lower) -}}
  {{- $op := ($.op | toString) -}}
  {{- $values := ($.values | toString | splitList "," | compact | sortAlpha) -}}
  {{- if or (eq $op "DoesNotExist") (eq $op "Exists") -}}
    {{- $values = list -}}
  {{- end -}}
  {{- $result := dict "key" (printf "armedia.com/support-%s" $type) "operator" $op -}}
  {{- if $values -}}
    {{- $result = set $result "values" $values -}}
  {{- end -}}
  {{- $result | toYaml -}}
{{- end -}}

{{- define "arkcase.node-affinity.gpu-required" -}}
  {{- include "__arkcase.node-affinity.match" (dict "type" "gpu" "op" "In" "values" "true") -}}
{{- end -}}

{{- define "arkcase.node-affinity.gpu-avoid" -}}
  {{- include "__arkcase.node-affinity.match" (dict "type" "gpu" "op" "NotIn" "values" "true") -}}
{{- end -}}
