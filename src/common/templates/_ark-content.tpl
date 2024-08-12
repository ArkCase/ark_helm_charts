{{- define "__arkcase.cm.info.compute" -}}
  {{- $ctx := . -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The parameter given must be the root context (. or $)" -}}
  {{- end -}}

  {{- $global := (dig "conf" "content" "settings" "" $ctx.Values.global | default dict) -}}

  {{- /* Compute the dialect, falling back to the default if necessary */ -}}
  {{- $dialect := (get $global "dialect" | toString | default "s3") -}}
  {{- if not $dialect -}}
    {{- fail (printf "Must provide the name of the content engine dialect to use in global.conf.content.settings.dialect (%s)" $dialect) -}}
  {{- end -}}
  {{- $dialect = lower $dialect -}}

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
  {{- $cmConf := merge (deepCopy $global) $cmInfo -}}
  {{- $cmConf = set $cmConf "dialect" $dialect -}}
  {{- $cmConf | toYaml -}}
{{- end -}}

{{- define "arkcase.cm.info" -}}
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

  {{- $cacheKey := "ArkCase-ContentManagerInfo" -}}
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
    {{- $yamlResult = (include "__arkcase.cm.info.compute" $ctx) -}}
    {{- $masterCache = set $masterCache $chartName ($yamlResult | fromYaml) -}}
  {{- else -}}
    {{- $yamlResult = get $masterCache $chartName | toYaml -}}
  {{- end -}}
  {{- $yamlResult -}}
{{- end -}}
