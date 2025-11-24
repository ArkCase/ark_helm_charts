{{- define "__arkcase.db.config.compute" -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The root context (. or $) must be given as the only parameter" -}}
  {{- end -}}

  {{- /* Load the common database configurations */ -}}
  {{- $result := dict -}}
  {{- $dbInfo := (.Files.Get "dbinfo.yaml" | fromYaml ) -}}
  {{- range $key, $db := $dbInfo -}}
    {{- if not (hasKey $db "scripts") -}}
      {{- $db = set $db "scripts" ($db.dialect | default $key) -}}
    {{- end -}}
    {{- if hasKey $db "aliases" -}}
      {{- range $alias := $db.aliases -}}
        {{- $result = set $result $alias (merge (dict "name" $key) (omit $db "aliases")) -}}
      {{- end -}}
    {{- end -}}
    {{- $db = set $db "name" $key -}}
    {{- $result = set $result $key (omit $db "aliases") -}}
  {{- end -}}
  {{- $result | toYaml -}}
{{- end -}}

{{- define "arkcase.db.config" -}}
  {{- $args :=
    dict
      "ctx" $
      "template" "__arkcase.db.config.compute"
  -}}
  {{- include "__arkcase.tools.getCachedValue" $args -}}
{{- end -}}

{{- define "__arkcase.db.info.compute" -}}
  {{- $ctx := $ -}}

  {{- $defaultDialect := "" -}}
  {{- $settings := dict -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- $ctx = $.ctx -}}
    {{- if not (include "arkcase.isRootContext" $ctx) -}}
      {{- fail "The root context (. or $) must be given either as the only parameter, or the 'ctx' parameter" -}}
    {{- end -}}
    {{- $settings = dict "dialect" $.dialect -}}
  {{- else -}}
    {{- $defaultDialect = "postgresql" -}}
    {{- $settings = (include "arkcase.subsystem.settings" (dict "ctx" $ctx "subsys" "rdbms") | fromYaml) -}}
  {{- end -}}

  {{- /* Compute the dialect, falling back to the default if necessary */ -}}
  {{- $dialect := (get $settings "dialect" | default $defaultDialect | toString | lower) -}}
  {{- if not $dialect -}}
    {{- fail "No database dialect given - can't continue!" -}}
  {{- end -}}

  {{- $dbInfo := (include "arkcase.db.config" $ctx | fromYaml) -}}

  {{- if not (hasKey $dbInfo $dialect) -}}
    {{- fail (printf "Unsupported database type '%s' - must be one of %s" $dialect (keys $dbInfo | sortAlpha)) -}}
  {{- end -}}

  {{- merge (deepCopy $settings) (get $dbInfo $dialect) | toYaml -}}
{{- end -}}

{{- define "arkcase.db.info" -}}
  {{- $ctx := $ -}}
  {{- if (include "arkcase.isRootContext" $ctx) -}}
    {{- $args :=
      dict
        "ctx" $ctx
        "template" "__arkcase.db.info.compute"
    -}}
    {{- include "__arkcase.tools.getCachedValue" $args -}}
  {{- else -}}
    {{- /* We're not doing the auto-computed stuff, so we don't cache it */ -}}
    {{- include "__arkcase.db.info.compute" $ -}}
  {{- end -}}
{{- end -}}
