{{- define "__arkcase.db.info.compute" -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The parameter given must be the root context (. or $)" -}}
  {{- end -}}

  {{- $global := (dig "Values" "global" "conf" "rdbms" "settings" "" $ctx | default dict) -}}

  {{- /* Compute the dialect, falling back to the default if necessary */ -}}
  {{- $dialect = (get $global "dialect" | toString | default "postgresql") -}}
  {{- if not $dialect -}}
    {{- fail "Must provide the name of the database dialect to use in global.conf.rdbms.dialect" -}}
  {{- end -}}
  {{- $dialect = lower $dialect -}}

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
  {{- $dbConf := (deepCopy $global) -}}

  {{- /* Now we can merge things */ -}}
  {{- $dbConf = merge $dbConf (omit $dbInfo "aliases") -}}

  {{- $dbConf | toYaml -}}
{{- end -}}

{{- define "arkcase.db.info" -}}
  {{- $ctx := . -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The parameter given must be the root context (. or $)" -}}
  {{- end -}}

  {{- /* First things first: do we have any global overrides? */ -}}
  {{- $global := $ctx.Values.global -}}
  {{- if or (not $global) (not (kindIs "map" $global)) -}}
    {{- $global = dict -}}
  {{- end -}}

  {{- /* Now get the local values */ -}}
  {{- $local := $ctx.Values.configuration -}}
  {{- if or (not $local) (not (kindIs "map" $local)) -}}
    {{- $local = dict -}}
  {{- end -}}

  {{- /* The keys on this map are the images in the local repository */ -}}
  {{- $chart := $ctx.Chart.Name -}}
  {{- $data := dict "local" $local "global" $global -}}

  {{- $cacheKey := "ArkCase-DatabaseInfo" -}}
  {{- $masterCache := dict -}}
  {{- if (hasKey $ctx $cacheKey) -}}
    {{- $masterCache = get $ctx $cacheKey -}}
    {{- if and $masterCache (not (kindIs "map" $masterCache)) -}}
      {{- $masterCache = dict -}}
    {{- end -}}
  {{- end -}}
  {{- $ctx = set $ctx $cacheKey $masterCache -}}

  {{- /* We do not use arkcase.fullname b/c we don't want to deal with partnames */ -}}
  {{- $chartName := (include "common.fullname" $ctx) -}}
  {{- $yamlResult := dict -}}
  {{- if not (hasKey $masterCache $chartName) -}}
    {{- $yamlResult = (include "__arkcase.db.info.compute" $ctx) -}}
    {{- $masterCache = set $masterCache $chartName ($yamlResult | fromYaml) -}}
  {{- else -}}
    {{- $yamlResult = get $masterCache $chartName | toYaml -}}
  {{- end -}}
  {{- $yamlResult -}}
{{- end -}}
