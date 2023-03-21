{{- define "alfresco.fullName" -}}
  {{- if not (include "arkcase.isRootContext" .) -}}
    {{- fail "The parameter must be the root context" -}}
  {{- end -}}

  {{- $fullName := (include "arkcase.fullName" .) -}}
  {{- $template := (.Template.Name | base) -}}
  {{- $template = (trimSuffix (ext $template) $template) -}}
  {{- $template = (trimPrefix "alf-" $template | lower) -}}
  {{- printf "%s-%s" $fullName ($template | replace "_" "-") -}}
{{- end -}}

{{- define "arkcase.alfresco.searchSecret" -}}
  {{- if not (include "arkcase.isRootContext" .) -}}
    {{- fail "The parameter must be the root context" -}}
  {{- end -}}

  {{- $fullname := (include "arkcase.fullname" .) -}}
  {{- $secretKey := (printf "%s-searchSecret" $fullname) -}}
  {{- if not (hasKey . $secretKey) -}}
    {{- $newSecret := (randAlphaNum 64 | b64enc) -}}
    {{- $crap := set . $secretKey $newSecret -}}
    {{- $secretKey = $newSecret -}}
  {{- else -}}
    {{- $secretKey = get . $secretKey -}}
  {{- end -}}
  {{- $secretKey -}}
{{- end -}}
