{{- define "__arkcase.cm.info.compute" -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The parameter given must be the root context (. or $)" -}}
  {{- end -}}

  {{- $settings := (include "arkcase.subsystem.settings" (dict "ctx" $ctx "subsys" "content") | fromYaml) -}}

  {{- /* Compute the dialect, falling back to the default if necessary */ -}}
  {{- $dialect := (get $settings "dialect" | default "s3" | toString | lower) -}}

  {{- /* Step one: load the common content engine configurations */ -}}
  {{- $cmInfo := (.Files.Get "cminfo.yaml" | fromYaml ) -}}
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

{{- define "arkcase.cm.info" -}}
  {{- $args :=
    dict
      "ctx" $
      "template" "__arkcase.cm.info.compute"
  -}}
  {{- include "__arkcase.tools.getCachedValue" $args -}}
{{- end -}}
