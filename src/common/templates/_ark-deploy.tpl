{{- define "arkcase.deployment.volume.name" -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The root context must be provided as the single parameter, or as the 'ctx' parameter" -}}
  {{- end -}}

  {{- printf "%s-%s-deployment" $ctx.Release.Namespace $ctx.Release.Name -}}
{{- end -}}
