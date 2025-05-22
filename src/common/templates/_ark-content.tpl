{{- define "arkcase.content.dialect" -}}
  {{- $ctx := $ -}}
  {{- $dialect := "" -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- $ctx = $.ctx -}}
    {{- if not (include "arkcase.isRootContext" $ctx) -}}
      {{- fail "The root context (. or $) must be given as the 'ctx' parameter, or the only parameter" -}}
    {{- end -}}
    {{- $dialect = ($.dialect | default $dialect | toString) -}}
  {{- end -}}

  {{- if (not $dialect) -}}
    {{- $settings := (include "arkcase.subsystem.settings" (dict "ctx" $ctx "subsys" "content") | fromYaml) -}}
    {{- $dialect = (get $settings "dialect" | default $dialect | toString | lower) -}}
  {{- end -}}

  {{- /* Make sure we always produce a default value */ -}}
  {{- $dialect | default "s3" -}}
{{- end -}}

{{- define "__arkcase.content.info.compute" -}}
  {{- $ctx := $.ctx -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The root context (. or $) must be given as the 'ctx' parameter, or the only parameter" -}}
  {{- end -}}

  {{- $dialect := $.dialect -}}

  {{- $settings := (include "arkcase.subsystem.settings" (dict "ctx" $ctx "subsys" "content") | fromYaml) -}}

  {{- /* Step one: load the common content engine configurations */ -}}
  {{- $cmInfo := ($ctx.Files.Get "cminfo.yaml" | fromYaml ) -}}
  {{- range $key, $cm := $cmInfo -}}
    {{- if hasKey $cm "aliases" -}}
      {{- $aliases := $cm.aliases -}}
      {{- $cm = (omit $cm "aliases") -}}
      {{- range $alias := $aliases -}}
        {{- $cmInfo = set $cmInfo $alias (set $cm "name" $alias) -}}
      {{- end -}}
    {{- end -}}
    {{- $cmInfo = set $cmInfo $key (set $cm "name" $key) -}}
  {{- end -}}

  {{- if not (hasKey $cmInfo $dialect) -}}
    {{- fail (printf "Unsupported content engine type '%s' - must be one of %s" $dialect (keys $cmInfo | sortAlpha)) -}}
  {{- end -}}

  {{- $cmInfo = get $cmInfo $dialect -}}
  {{- $cmConf := merge (deepCopy $settings) $cmInfo -}}
  {{- $cmConf = set $cmConf "dialect" $dialect -}}
  {{- $cmConf | toYaml -}}
{{- end -}}

{{- define "arkcase.content.info" -}}
  {{- $dialect := (include "arkcase.content.dialect" $) -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- $ctx = $.ctx -}}
    {{- if not (include "arkcase.isRootContext" $ctx) -}}
      {{- fail "The root context (. or $) must be given as the 'ctx' parameter, or the only parameter" -}}
    {{- end -}}
  {{- end -}}

  {{- $args :=
    dict
      "ctx" $ctx
      "template" "__arkcase.content.info.compute"
      "key" $dialect
      "params" (dict "ctx" $ctx "dialect" $dialect)
  -}}
  {{- include "__arkcase.tools.getCachedValue" $args -}}
{{- end -}}
