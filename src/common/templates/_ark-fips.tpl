{{- define "arkcase.fips" -}}
  {{- $ctx := . -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- $ctx = $.ctx -}}
    {{- if not (include "arkcase.isRootContext" $ctx) -}}
      {{- fail "Must provide the root context (. or $) as either the only parameter, or the 'ctx' parameter" -}}
    {{- end -}}
  {{- end -}}
  {{- $global := ($ctx.Values.global | default dict) -}}
  {{- if not (kindIs "map" $global) -}}
    {{- $global = dict -}}
  {{- end -}}

  {{- include "arkcase.toBoolean" $global.fips -}}
{{- end -}}

{{- define "arkcase.fips.bool" -}}
  {{- (not (empty (include "arkcase.fips" $))) -}}
{{- end -}}

{{- define "arkcase.fips.java-options" -}}
  {{- $fips := (include "arkcase.fips.bool" $) -}}
  {{- /* -Dcom.redhat.fips={{ $fips }} -Dorg.bouncycastle.fips.approved_only={{ $fips }} --module-path=/app/fips */ -}}
-Dcom.redhat.fips={{ $fips }} --module-path=/app/fips
{{- end -}}
