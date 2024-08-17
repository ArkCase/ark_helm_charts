{{- define "__arkcase.db.info.compute" -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The parameter given must be the root context (. or $)" -}}
  {{- end -}}

  {{- $settings := (include "arkcase.subsystem.settings" $ctx | fromYaml) -}}

  {{- /* Compute the dialect, falling back to the default if necessary */ -}}
  {{- $dialect := (get $settings "dialect" | default "postgresql" | toString | lower) -}}

  {{- /* Step one: load the common database configurations */ -}}
  {{- $dbInfo := (.Files.Get "dbinfo.yaml" | fromYaml ) -}}
  {{- range $key, $db := $dbInfo -}}
    {{- if not (hasKey $db "scripts") -}}
      {{- $db = set $db "scripts" ($db.dialect | default $key) -}}
    {{- end -}}
    {{- if hasKey $db "aliases" -}}
      {{- range $alias := $db.aliases -}}
        {{- $dbInfo = set $dbInfo $alias (merge (dict "name" $key) (omit $db "aliases")) -}}
      {{- end -}}
    {{- end -}}
    {{- $db = set $db "name" $key -}}
    {{- $dbInfo = set $dbInfo $key $db -}}
  {{- end -}}

  {{- if not (hasKey $dbInfo $dialect) -}}
    {{- fail (printf "Unsupported database type '%s' - must be one of %s" $dialect (keys $dbInfo | sortAlpha)) -}}
  {{- end -}}

  {{- /* Step two: merge in the server and schema definitions */ -}}
  {{- $dbInfo = get $dbInfo $dialect -}}
  {{- $dbConf := (deepCopy $settings) -}}

  {{- /* Now we can merge things */ -}}
  {{- $dbConf = merge $dbConf (omit $dbInfo "aliases") -}}

  {{- $dbConf | toYaml -}}
{{- end -}}

{{- define "arkcase.db.info" -}}
  {{- $args :=
    dict
      "ctx" $
      "template" "__arkcase.db.info.compute"
  -}}
  {{- include "__arkcase.tools.getCachedValue" $args -}}
{{- end -}}
