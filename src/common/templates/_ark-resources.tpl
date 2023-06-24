{{- define "arkcase.resources.parseCpu" -}}
  {{- $data := ($ | toString | upper) -}}
  {{- if regexMatch "^[1-9][0-9]*M$" $data -}}
    {{- /* Already in milli-CPU syntax */ -}}
    {{- $data | lower -}}
  {{- else if regexMatch "^(0|[1-9][0-9]*)([.][0-9]+)?$" $data -}}
    {{- /* Convert to milli-cpu syntax */ -}}
    {{- printf "%dm" ($data | mulf 1000 | int64) -}}
  {{- else if (eq $data "*") -}}
    {{- "*" -}}
  {{- else if $data -}}
    {{- fail (printf "Invalid CPU units: [%s]" $) -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.resources.parseMem" -}}
  {{- $data := ($ | toString | upper) -}}
  {{- if regexMatch "^[1-9][0-9]*[EPTGMK]I?$" $data -}}
    {{- $data | replace "I" "i" | replace "K" "k" | replace "ki" "Ki" -}}
  {{- else if (eq $data "*") -}}
    {{- "*" -}}
  {{- else if $data -}}
    {{- fail (printf "Invalid Memory units: [%s]" $) -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.resources.parseCpuMem" -}}
  {{- $data := $ -}}
  {{- if (kindIs "string" $data) -}}
    {{- if $data -}}
      {{- /* This is the "MEM:CPU" format, so split on the colon and parse each value */ -}}
      {{- $data = (splitList ":" $data) -}}
      {{- if $data -}}
        {{- /* The first element is the memory spec */ -}}
        {{- $parts := $data -}}
        {{- $data = dict "mem" (first $parts) -}}

        {{- /* If there's a second element, it's the CPU spec. We ignore all others */ -}}
        {{- if (ge (len $parts) 2) -}}
          {{- $data = set $data "cpu" (index $parts 1) -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}

  {{- /* If the item is empty, then we can safely shoehorn it into a map */ -}}
  {{- if or (not $data) (not (kindIs "map" $data)) -}}
    {{- $data = dict -}}
  {{- end -}}

  {{- $result := dict -}}
  {{- $data = pick $data "cpu" "mem" -}}
  {{- if hasKey $data "cpu" -}}
    {{- $cpu := (include "arkcase.resources.parseCpu" ($data.cpu | toString)) -}}
    {{- if $cpu -}}
      {{- $result = set $result "cpu" $cpu -}}
    {{- end -}}
  {{- end -}}
  {{- if hasKey $data "mem" -}}
    {{- $mem := (include "arkcase.resources.parseMem" ($data.mem | toString)) -}}
    {{- if $mem -}}
      {{- $result = set $result "memory" $mem -}}
    {{- end -}}
  {{- end -}}
  {{- $result | toYaml -}}
{{- end -}}

{{- define "arkcase.resources.parseSection" -}}
  {{- /* This will either be global.resources.${component}, local.resources, local.resources.devel or local.resources.default */ -}}
  {{- /* they're all structured the same, and thus can and should be parsed the same */ -}}
  {{- $base := $ -}}
  {{- $result := dict -}}
  {{- if or (hasKey $base "cpu") (hasKey $base "mem") -}}
    {{- $result = dict "common" (include "arkcase.resources.parseCpuMem" (pick $base "cpu" "mem") | fromYaml) -}}
  {{- else -}}
    {{- /* at this point, base contains common, or part-named sections /* -}}

    {{- /* First, sanitize the common configuration */ -}}
    {{- $common := (include "arkcase.resources.parseCpuMem" $base.common | fromYaml) -}}

    {{- /* Go through each part described and render its configuration */ -}}
    {{- range $k, $v := (omit $base "common") -}}
      {{- if (include "arkcase.tools.hostnamePart" $k) -}}
        {{- $part := (include "arkcase.resources.parseCpuMem" $v | fromYaml) -}}
        {{- $result = set $result $k (merge $part $common) -}}
      {{- end -}}
    {{- end -}}

    {{- $result = (set $result "common" $common) -}}
  {{- end -}}

  {{ $result | toYaml -}}
{{- end -}}

{{- define "arkcase.resources.compute" -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The parameter given must be the root context (. or $)" -}}
  {{- end -}}

  {{- /* Get the localized resources */ -}}
  {{- $local := ($ctx.Values.resources | default dict) -}}
  {{- if not (kindIs "map" $local) -}}
    {{- $local = dict -}}
  {{- end -}}

  {{- /* We only take the development resources into account if we're in development mode, */ -}}
  {{- /* and the developer hasn't disabled the use of development resource allocations */ -}}
  {{- $development := dict "common" dict -}}
  {{- $dev := (include "arkcase.dev" $ | fromYaml) -}}
  {{- if and $dev.enabled $dev.resources -}}
    {{- /* Parse out the local development resources and construct the allocations for this chart */ -}}
    {{- if hasKey $local "development" -}}
      {{- $development = $local.development -}}
      {{- if not (kindIs "map" $development) -}}
        {{- $development = dict -}}
      {{- end -}}
      {{- $development = (include "arkcase.resources.parseSection" $development | fromYaml) -}}
    {{- end -}}
  {{- end -}}

  {{- /* Parse out the local default resources and construct the allocations for this chart */ -}}
  {{- $default := dict "common" dict -}}
  {{- if hasKey $local "default" -}}
    {{- $default = $local.default -}}
    {{- if not (kindIs "map" $default) -}}
      {{- $default = dict -}}
    {{- end -}}
    {{- $default = (include "arkcase.resources.parseSection" $default | fromYaml) -}}
  {{- end -}}

  {{- /* Get the global resources */ -}}
  {{- $global := (($ctx.Values.global).resources | default dict) -}}
  {{- if not (kindIs "map" $global) -}}
    {{- $global = dict -}}
  {{- end -}}
  {{- /* Find the global resources for this chart */ -}}
  {{- $chart := $.Chart.Name -}}
  {{- if hasKey $global $chart -}}
    {{- $global = get $global $chart -}}
    {{- if not (kindIs "map" $global) -}}
      {{- $global = dict -}}
    {{- end -}}
  {{- else -}}
    {{- /* No global configuration for this chart, so we skip it */ -}}
    {{- $global = dict -}}
  {{- end -}}

  {{- $global = (include "arkcase.resources.parseSection" $global | fromYaml) -}}

  {{- /* Now merge everything into a single resource table from where we can pull the resources */ -}}
  {{- /* For a single part (or from "common", if no part is given) */ -}}

  {{- $common := merge $global.common $development.common $default.common -}}
  {{- $allKeys := (concat (keys $global) (keys $development) (keys $default) | sortAlpha | uniq) -}}
  {{- $result := dict -}}
  {{- range $k := (without $allKeys "common") -}}
    {{- $m := dict -}}
    {{- /* Highest priority value is the global value, including the global common */ -}}
    {{- if hasKey $global $k -}}
      {{- $m = (get $global $k) -}}
    {{- end -}}
    {{- if hasKey $development $k -}}
      {{- /* Second highest priority goes to the devel value, which won't exist unless */ -}}
      {{- /* the conditions for it are set (i.e. development enabled, and dev resource */ -}}
      {{- /* allocations haven't been explicitly disabled */ -}}
      {{- $m = merge $m (get $development $k) -}}
    {{- end -}}
    {{- if hasKey $default $k -}}
      {{- /* Lowest priority goes to the default value */ -}}
      {{- $m = merge $m (get $default $k) -}}
    {{- end -}}

    {{- $result = set $result $k $m -}}
  {{- end -}}
  {{- $result = set $result "common" $common -}}

  {{- $result | toYaml -}}
{{- end -}}

{{- define "arkcase.resources.cached" -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The parameter given must be the root context (. or $)" -}}
  {{- end -}}

  {{- $cacheKey := "Resources" -}}
  {{- $masterCache := dict -}}
  {{- if (hasKey $ctx $cacheKey) -}}
    {{- $masterCache = get $ctx $cacheKey -}}
    {{- if and $masterCache (not (kindIs "map" $masterCache)) -}}
      {{- $masterCache = dict -}}
    {{- end -}}
  {{- end -}}
  {{- $ctx = set $ctx $cacheKey $masterCache -}}

  {{- $masterKey := $ctx.Release.Name -}}
  {{- $yamlResult := dict -}}
  {{- if not (hasKey $masterCache $masterKey) -}}
    {{- $yamlResult = (include "arkcase.resources.compute" $ctx) -}}
    {{- $masterCache = set $masterCache $masterKey ($yamlResult | fromYaml) -}}
  {{- else -}}
    {{- $yamlResult = get $masterCache $masterKey | toYaml -}}
  {{- end -}}
  {{- $yamlResult -}}
{{- end -}}

{{- define "arkcase.resources" -}}
  {{- $part := (include "arkcase.part.name" $) -}}
  {{- $resources := (include "arkcase.resources.cached" $ | fromYaml) -}}
  {{- if (not (hasKey $resources $part)) -}}
    {{- $part = "common" -}}
  {{- end -}}

  {{- $part = get $resources $part -}}
  {{- if and (hasKey $part "cpu") (eq "*" $part.cpu) -}}
    {{- $part = omit $part "cpu" -}}
  {{- end -}}
  {{- if and (hasKey $part "memory") (eq "*" $part.memory) -}}
    {{- $part = omit $part "memory" -}}
  {{- end -}}

  {{- /* Render both limits and requests identically */ -}}
  {{- dict "limits" $part "requests" $part | toYaml -}}
{{- end -}}
