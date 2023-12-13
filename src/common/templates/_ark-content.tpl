{{- define "arkcase.cm.external" -}}
  {{- $hostname := (include "arkcase.tools.conf" (dict "ctx" $ "value" "content.url" "detailed" true) | fromYaml) -}}
  {{- if and $hostname $hostname.global -}}
    {{- true -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.cm.info.compute" -}}
  {{- $ctx := . -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The parameter given must be the root context (. or $)" -}}
  {{- end -}}

  {{- $local := (($ctx.Values.configuration).content | default dict) -}}

  {{- $global := (($ctx.Values.global).conf).content -}}
  {{- if not $global -}}
    {{- $global = $ctx.Values -}}

    {{- if or (not (hasKey $global "global")) (not (kindIs "map" $global.global)) -}}
      {{- $global = set $global "global" dict -}}
    {{- end -}}
    {{- $global = $ctx.Values.global -}}

    {{- if or (not (hasKey $global "conf")) (not (kindIs "map" $global.conf)) -}}
      {{- $global = set $global "conf" dict -}}
    {{- end -}}
    {{- $global = $global.conf -}}

    {{- if or (not (hasKey $global "content")) (not (kindIs "map" $global.content)) -}}
      {{- $global = set $global "content" dict -}}
    {{- end -}}
    {{- $global = $global.content -}}
  {{- end -}}

  {{- $dialect := coalesce $global.dialect $local.dialect -}}
  {{- if not $dialect -}}
    {{- fail "Must provide the name of the content engine dialect to use in global.conf.content.dialect" -}}
  {{- end -}}

  {{- if not (kindIs "string" $dialect) -}}
    {{- $dialect = toString $dialect -}}
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
  {{- $cmConf := merge (deepCopy $global) $local $cmInfo -}}

  {{- /* We have to give these two special treatment */ -}}
  {{- $cmConf = omit $cmConf "url" "ui" -}}

  {{- $url := "" -}}
  {{- $ui := "" -}}
  {{- $g := true -}}
  {{- range $c := list $global $local $cmInfo -}}
    {{- if and (empty $url) (hasKey $c "url") -}}
      {{- $url = get $c "url" -}}
      {{- if (kindIs "string" $url) -}}
        {{- $a := (include "arkcase.tools.parseUrl" $url | fromYaml) -}}
        {{- if not $a.scheme -}}
          {{- fail (printf "Invalid content server API URL syntax [%s]" $url) -}}
        {{- end -}}
        {{- $url = (omit $a "userinfo") -}}
        {{- $url = set $url "global" $g -}}

        {{- if (hasKey $c "ui") -}}
          {{- $ui = get $c "ui" -}}
          {{- if (kindIs "string" $ui) -}}
            {{- $u := (include "arkcase.tools.parseUrl" $ui | fromYaml) -}}
            {{- if not $u.scheme -}}
              {{- fail (printf "Invalid content server UI URL syntax [%s]" $ui) -}}
            {{- end -}}
            {{- $ui = (omit $u "userinfo") -}}
            {{- $ui = set $ui "global" $g -}}
          {{- end -}}
        {{- end -}}
        {{- if not $ui -}}
          {{- $ui = $url -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
    {{- $g = false -}}
  {{- end -}}

  {{- /* Make sure there's an API url */ -}}
  {{- if not $url -}}
    {{- fail "Must provide the content store API URL in the 'content.url' configuration value" -}}
  {{- end -}}

  {{- $settings := dict -}}
  {{- range $c := list $global $local $cmInfo -}}
    {{- if and $c (hasKey $c "settings") (kindIs "map" $c.settings) -}}
      {{- $settings = merge $settings $c.settings -}}
    {{- end -}}
  {{- end -}}
  {{- $cmConf = set $cmConf "settings" $settings -}}

  {{- /* Grab the host + port from the URL */ -}}
  {{- $cmConf = set $cmConf "url" $url -}}
  {{- $cmConf = set $cmConf "ui" $ui -}}

  {{- if or (not (hasKey $cmConf "username")) (not (kindIs "string" $cmConf.username)) (empty $cmConf.username) -}}
    {{- $cmConf = set $cmConf "username" "arkcase" -}}
  {{- end -}}

  {{- if or (not (hasKey $cmConf "password")) (not (kindIs "string" $cmConf.password)) (empty $cmConf.password) -}}
    {{- $cmConf = set $cmConf "password" (sha1sum "arkcase" | lower) -}}
  {{- end -}}

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

  {{- $cacheKey := "CMInfo" -}}
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
    {{- $yamlResult = (include "arkcase.cm.info.compute" $ctx) -}}
    {{- $masterCache = set $masterCache $chartName ($yamlResult | fromYaml) -}}
  {{- else -}}
    {{- $yamlResult = get $masterCache $chartName | toYaml -}}
  {{- end -}}
  {{- $yamlResult -}}
{{- end -}}
