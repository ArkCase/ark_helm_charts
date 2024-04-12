{{- define "arkcase.resources.parseCpu.single" -}}
  {{- $data := ($ | default "" | toString | upper) -}}
  {{- if regexMatch "^[1-9][0-9]*M$" $data -}}
    {{- /* Already in milli-CPU syntax */ -}}
    {{- $data | lower -}}
  {{- else if regexMatch "^(0|[1-9][0-9]*)([.][0-9]+)?$" $data -}}
    {{- /* Convert to milli-cpu syntax */ -}}
    {{- printf "%dm" ($data | mulf 1000 | int64) -}}
  {{- else if (eq $data "*") -}}
    {{- "*" -}}
  {{- else if $data -}}
    {{- fail (printf "Invalid CPU units description: [%s]" $) -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.resources.parseCpu" -}}
  {{- $data := ($ | toString) -}}
  {{- $result := dict -}}
  {{- $key := "cpu" -}}
  {{- if regexMatch "^([^-]+)-([^-]+)$" $data -}}
    {{- $data = (splitList "-" $data) -}}
    {{- $req := (include "arkcase.resources.parseCpu.single" (first $data)) -}}
    {{- if $req -}}
      {{- $result = set $result "requests" (dict $key $req) -}}
    {{- end -}}
    {{- $lim := (include "arkcase.resources.parseCpu.single" (last $data)) -}}
    {{- if $lim -}}
      {{- $result = set $result "limits" (dict $key $lim) -}}
    {{- end -}}
  {{- else if regexMatch "^[^-]+$" $data -}}
    {{- $val := (include "arkcase.resources.parseCpu.single" $) -}}
    {{- if $val -}}
      {{- $result = dict "requests" (dict $key $val) "limits" (dict $key $val) -}}
    {{- end -}}
  {{- else if $data -}}
    {{- fail (printf "Invalid CPU requests-limits description string: [%s]" $) -}}
  {{- end -}}
  {{- $result | toYaml -}}
{{- end -}}

{{- define "arkcase.resources.parseMem.single" -}}
  {{- $data := ($ | default "" | toString | upper) -}}
  {{- if regexMatch "^[1-9][0-9]*[EPTGMK]I?$" $data -}}
    {{- $data | replace "I" "i" | replace "K" "k" | replace "ki" "Ki" -}}
  {{- else if (eq $data "*") -}}
    {{- "*" -}}
  {{- else if $data -}}
    {{- fail (printf "Invalid Memory units: [%s]" $) -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.resources.parseMem" -}}
  {{- $data := ($ | toString) -}}
  {{- $result := dict -}}
  {{- $key := "memory" -}}
  {{- if regexMatch "^([^-]+)-([^-]+)$" $data -}}
    {{- $data = (splitList "-" $data) -}}
    {{- $req := (include "arkcase.resources.parseMem.single" (first $data)) -}}
    {{- if $req -}}
      {{- $result = set $result "requests" (dict $key $req) -}}
    {{- end -}}
    {{- $lim := (include "arkcase.resources.parseMem.single" (last $data)) -}}
    {{- if $lim -}}
      {{- $result = set $result "limits" (dict $key $lim) -}}
    {{- end -}}
  {{- else if regexMatch "^[^-]+$" $data -}}
    {{- $val := (include "arkcase.resources.parseMem.single" $) -}}
    {{- if $val -}}
      {{- $result = dict "requests" (dict $key $val) "limits" (dict $key $val) -}}
    {{- end -}}
  {{- else if $data -}}
    {{- fail (printf "Invalid CPU requests-limits description string: [%s]" $) -}}
  {{- end -}}
  {{- $result | toYaml -}}
{{- end -}}

{{- define "arkcase.resources.parseCpuMem.single" -}}
  {{- $data := ($ | toString) -}}
  {{- $result := dict -}}
  {{- if $data -}}
    {{- /* This is the "MEMSPEC,CPUSPEC" format, so split on the comma and parse each value */ -}}
    {{- $data = (splitList "," $data) -}}
    {{- if $data -}}
      {{- /* The first element is the memory spec */ -}}
      {{- $parts := $data -}}
      {{- $mem := (include "arkcase.resources.parseMem.single" (first $parts)) -}}
      {{- if $mem -}}
        {{- $result = set $result "memory" $mem -}}
      {{- end -}}

      {{- /* If there's a second element, it's the CPU spec. We ignore all others */ -}}
      {{- if (ge (len $parts) 2) -}}
        {{- $cpu := (include "arkcase.resources.parseCpu.single" (index $parts 1)) -}}
        {{- if $cpu -}}
          {{- $result = set $result "cpu" $cpu -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
  {{- $result | toYaml -}}
{{- end -}}

{{- define "arkcase.resources.parseCpuMem" -}}
  {{- $data := ($ | toString) -}}
  {{- $result := dict -}}
  {{- if $data -}}
    {{- /* This is the "MEMSPEC,CPUSPEC" format, so split on the comma and parse each value */ -}}
    {{- $data = (splitList "," $data) -}}
    {{- if $data -}}
      {{- /* The first element is the memory spec */ -}}
      {{- $parts := $data -}}
      {{- $mem := (include "arkcase.resources.parseMem" (first $parts) | fromYaml) -}}
      {{- if $mem -}}
        {{- $result = merge $result $mem -}}
      {{- end -}}

      {{- /* If there's a second element, it's the CPU spec. We ignore all others */ -}}
      {{- if (ge (len $parts) 2) -}}
        {{- $cpu := (include "arkcase.resources.parseCpu" (index $parts 1) | fromYaml) -}}
        {{- if $cpu -}}
          {{- $result = merge $result $cpu -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
  {{- $result | toYaml -}}
{{- end -}}

{{- define "arkcase.resources.parseResourceTarget" -}}
  {{- $data := $ -}}

  {{- $result := dict -}}
  {{- if (kindIs "string" $data) -}}
    {{- /* This is the "MEMSPEC,CPUSPEC" format */ -}}
    {{- $result = (include "arkcase.resources.parseCpuMem" $data | fromYaml) -}}
  {{- else if (kindIs "map" $data) -}}
    {{- $cpuMem := pick $data "cpu" "memory" -}}
    {{- $reqLim := pick $data "requests" "limits" -}}
    {{- /* We're not interested in anything other keys */ -}}
    {{- if and $cpuMem $reqLim -}}
      {{- fail "You may only specify 'cpu-mem' or 'req-lim' when describing resources allocations, not both forms intermingled" -}}
    {{- end -}}

    {{- if $cpuMem -}}
      {{- $mem := ((and (hasKey $cpuMem "memory") (not (empty $cpuMem.memory))) | ternary (include "arkcase.resources.parseMem" $cpuMem.memory | fromYaml) dict) -}}
      {{- $result = merge $result $mem -}}

      {{- $cpu := ((and (hasKey $cpuMem "cpu") (not (empty $cpuMem.cpu))) | ternary (include "arkcase.resources.parseCpu" $cpuMem.cpu | fromYaml) dict) -}}
      {{- $result = merge $result $cpu -}}
    {{- end -}}

    {{- if $reqLim -}}
      {{- if and (hasKey $reqLim "requests") $reqLim.requests -}}
        {{- $req := $reqLim.requests -}}
        {{- if (kindIs "string" $req) -}}
          {{- $req = (include "arkcase.resources.parseCpuMem.single" $req | fromYaml) -}}
        {{- else if (kindIs "map" $req) -}}
          {{- /* If this is a map, then it must contain cpu/mem */ -}}
          {{- $req = pick $req "cpu" "memory" -}}
          {{- $mem := (and (hasKey $req "memory") (not (empty $req.memory)) | ternary (include "arkcase.resources.parseMem.single" $req.memory) "") -}}
          {{- $cpu := (and (hasKey $req "cpu") (not (empty $req.cpu)) | ternary (include "arkcase.resources.parseCpu.single" $req.cpu) "") -}}
          {{- $req = dict "memory" $mem "cpu" $cpu -}}
        {{- else -}}
          {{- fail (printf "Invalid format for resource requests: %s" $req) -}}
        {{- end -}}
        {{- $result = set $result "requests" $req -}}
      {{- end -}}

      {{- if and (hasKey $reqLim "limits") $reqLim.limits -}}
        {{- $lim := $reqLim.limits -}}
        {{- if (kindIs "string" $lim) -}}
          {{- $lim = (include "arkcase.resources.parseCpuMem.single" $lim | fromYaml) -}}
        {{- else if (kindIs "map" $lim) -}}
          {{- /* If this is a map, then it must contain cpu/mem */ -}}
          {{- $lim = pick $lim "cpu" "memory" -}}
          {{- $mem := (and (hasKey $lim "memory") (not (empty $lim.memory)) | ternary (include "arkcase.resources.parseMem.single" $lim.memory) "") -}}
          {{- $cpu := (and (hasKey $lim "cpu") (not (empty $lim.cpu)) | ternary (include "arkcase.resources.parseCpu.single" $lim.cpu) "") -}}
          {{- $lim = dict "memory" $mem "cpu" $cpu -}}
        {{- else -}}
          {{- fail (printf "Invalid format for resource limits: %s" $lim) -}}
        {{- end -}}
        {{- $result = set $result "limits" $lim -}}
      {{- end -}}
    {{- end -}}
  {{- else if $data -}}
    {{- fail (printf "The resource specification must be a properly formatted string or map (%s == %s)" (kindOf $) $) -}}
  {{- end -}}

  {{- $result | toYaml -}}
{{- end -}}

{{- define "arkcase.resources.parseSection" -}}
  {{- /* This will either be global.resources.${component}, local.resources, local.resources.devel or local.resources.default */ -}}
  {{- /* they're all structured the same, and thus can and should be parsed the same */ -}}
  {{- $base := $ -}}
  {{- $result := dict -}}
  {{- if or (hasKey $base "cpu") (hasKey $base "memory") -}}
    {{- $result = dict "common" (include "arkcase.resources.parseResourceTarget" (pick $base "cpu" "memory") | fromYaml) -}}
  {{- else if or (hasKey $base "limits") (hasKey $base "requests") -}}
    {{- $result = dict "common" (include "arkcase.resources.parseResourceTarget" (pick $base "limits" "requests") | fromYaml) -}}
  {{- else -}}
    {{- /* at this point, base contains common, or part-named sections /* -}}

    {{- /* First, sanitize the common configuration */ -}}
    {{- $common := (include "arkcase.resources.parseResourceTarget" $base.common | fromYaml) -}}

    {{- /* Go through each part described and render its configuration */ -}}
    {{- range $k, $v := (omit $base "common") -}}
      {{- if (include "arkcase.tools.hostnamePart" $k) -}}
        {{- $part := (include "arkcase.resources.parseResourceTarget" $v | fromYaml) -}}
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
      {{- if (kindIs "string" $development) -}}
        {{- $development = dict "common" (include "arkcase.resources.parseCpuMem" $development | fromYaml) -}}
      {{- else if (kindIs "map" $development) -}}
        {{- $development = (include "arkcase.resources.parseSection" $development | fromYaml) -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}

  {{- /* Parse out the local default resources and construct the allocations for this chart */ -}}
  {{- $default := dict "common" dict -}}
  {{- if hasKey $local "default" -}}
    {{- $default = $local.default -}}
    {{- if (kindIs "string" $default) -}}
      {{- $default = dict "common" (include "arkcase.resources.parseCpuMem" $default | fromYaml) -}}
    {{- else if (kindIs "map" $default) -}}
      {{- $default = (include "arkcase.resources.parseSection" $default | fromYaml) -}}
    {{- end -}}
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
    {{- if (kindIs "string" $global) -}}
      {{- $global = dict "common" (include "arkcase.resources.parseCpuMem" $global | fromYaml) -}}
    {{- else if (kindIs "map" $global) -}}
      {{- $global = (include "arkcase.resources.parseSection" $global | fromYaml) -}}
    {{- else -}}
      {{- $global = dict "common" dict -}}
    {{- end -}}
  {{- else -}}
    {{- /* No global configuration for this chart, so we skip it */ -}}
    {{- $global = dict "common" dict -}}
  {{- end -}}

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

  {{- $cacheKey := "ArkCase-Resources" -}}
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
  {{- $ctx := $ -}}
  {{- $part := "" -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- $ctx = $.ctx -}}
    {{- if not (include "arkcase.isRootContext" $ctx) -}}
      {{- fail "The 'ctx' parameter given must be the root context (. or $)" -}}
    {{- end -}}
    {{- $part = ($.part | toString) -}}
  {{- end -}}

  {{- if (not $part) -}}
    {{- $part = (include "arkcase.part.name" $ctx | default "common") -}}
  {{- end -}}

  {{- $resources := (include "arkcase.resources.cached" $ctx | fromYaml) -}}
  {{- if (not (hasKey $resources $part)) -}}
    {{- $part = "common" -}}
  {{- end -}}

  {{- $part = get $resources $part -}}

  {{- $reqMem := "" -}}
  {{- $reqCpu := "" -}}
  {{- $limMem := "" -}}
  {{- $limCpu := "" -}}

  {{- if and (hasKey $part "requests") $part.requests -}}
    {{- $reqMem = (and (hasKey $part.requests "memory") (not (empty $part.requests.memory)) | ternary $part.requests.memory "") -}}
    {{- $reqCpu = (and (hasKey $part.requests "cpu") (not (empty $part.requests.cpu)) | ternary $part.requests.cpu "") -}}
  {{- end -}}

  {{- if and (hasKey $part "limits") $part.limits -}}
    {{- $limMem = (and (hasKey $part.limits "memory") (not (empty $part.limits.memory)) | ternary $part.limits.memory "") -}}
    {{- $limCpu = (and (hasKey $part.limits "cpu") (not (empty $part.limits.cpu)) | ternary $part.limits.cpu "") -}}
  {{- end -}}

  {{- if (eq "*" $reqCpu) -}}{{- $reqCpu = "" -}}{{- end -}}
  {{- if (eq "*" $reqMem) -}}{{- $reqMem = "" -}}{{- end -}}
  {{- if (eq "*" $limCpu) -}}{{- $limCpu = "" -}}{{- end -}}
  {{- if (eq "*" $limMem) -}}{{- $limMem = "" -}}{{- end -}}

  {{- $results := dict -}}

  {{- $requests := dict -}}
  {{- if $reqCpu -}}{{- $requests = set $requests "cpu" $reqCpu -}}{{- end -}}
  {{- if $reqMem -}}{{- $requests = set $requests "memory" $reqMem -}}{{- end -}}
  {{- if $requests -}}{{- $results = set $results "requests" $requests -}}{{- end -}}

  {{- $limits := dict -}}
  {{- if $limCpu -}}{{- $limits = set $limits "cpu" $limCpu -}}{{- end -}}
  {{- if $limMem -}}{{- $limits = set $limits "memory" $limMem -}}{{- end -}}
  {{- if $limits -}}{{- $results = set $results "limits" $limits -}}{{- end -}}

  {{- $results | toYaml -}}
{{- end -}}
