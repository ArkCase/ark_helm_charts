{{- define "arkcase.tools.enterprise" -}}
  {{- $ctx := . -}}
  {{- if not (include "arkcase.isRootContext" .) -}}
    {{- $ctx = .ctx -}}
    {{- if not (include "arkcase.isRootContext" $ctx) -}}
      {{- fail "The given 'ctx' parameter is not the root context" -}}
    {{- end -}}
  {{- end -}}

  {{- if (include "arkcase.toBoolean" ($ctx.Values.configuration).enterprise) -}}
    {{- true -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.enterprise.image" -}}
  {{- $edition := "ce" -}}
  {{- if (include "arkcase.tools.enterprise" .) -}}
    {{- $edition = "ee" -}}
  {{- end -}}
  {{- (include "arkcase.tools.image" .) | replace "${EDITION}" $edition -}}
{{- end -}}

{{- define "arkcase.enterprise.subimage" -}}
  {{- $edition := "ce" -}}
  {{- if (include "arkcase.tools.enterprise" .) -}}
    {{- $edition = "ee" -}}
  {{- end -}}
  {{- (include "arkcase.tools.subimage" .) | replace "${EDITION}" $edition -}}
{{- end -}}

{{- define "arkcase.enterprise.imageRegistry" -}}
  {{- $edition := "ce" -}}
  {{- if (include "arkcase.tools.enterprise" .) -}}
    {{- $image := (required "No image information was found in the Values object" .Values.image) -}}
    {{- $global := (default dict .Values.global) -}}
    {{- $registryName := $image.enterpriseRegistry -}}
    {{- if $global -}}
      {{- if $global.enterpriseImageRegistry -}}
        {{- $registryName = $global.enterpriseImageRegistry -}}
      {{- end -}}
    {{- end -}}
    {{- $registryName -}}
  {{- else -}}
    {{- include "arkcase.tools.imageRegistry" . -}}
  {{- end -}}
{{- end -}}
