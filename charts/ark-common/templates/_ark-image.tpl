{{- define "arkcase.image.info.parsePullPolicy" -}}
  {{- $v := "" -}}
  {{- if . -}}
    {{- $p := (. | toString | lower) -}}
    {{- $l := list "IfNotPresent" "Always" "Never" -}}
    {{- range $l -}}
      {{- if eq (. | lower) $p -}}
        {{- $v = . -}}
      {{- end -}}
    {{- end -}}
    {{- if not $v -}}
      {{- fail (printf "Unknown pull policy value [%s] - must be one of %s" . $l) -}}
    {{- end -}}
  {{- end -}}
  {{- $v -}}
{{- end -}}

{{- define "arkcase.image.info.definition" -}}
  {{- $ctx := .ctx -}}
  {{- $chart := .chart -}}
  {{- $image := .image -}}
  {{- $edition := .edition -}}
  {{- $repository := .repository -}}
  {{- $data := .data -}}

  {{- $imageAttributes := list "repository" "tag" -}}
  {{- $commonAttributes := list "registry" "pullPolicy" -}}

  {{- $search := list -}}

  {{-
    $search = ( list
        ((not (empty $image)) | ternary (printf "local.%s.%s" $edition $image) "")
        (printf "local.%s" $edition)
        ((not (empty $image)) | ternary (printf "local.%s" $image) "")
        "local"
    ) | compact
  -}}

  {{- $candidates := list -}}
  {{- $allAttributes := (concat $imageAttributes $commonAttributes) -}}

  {{- if $commonAttributes -}}
    {{- $m := dict -}}
    {{- range $commonAttributes -}}
      {{- $m = set $m . . -}}
    {{- end -}}
    {{- $commonAttributes = $m -}}
  {{- end -}}
  {{- if $imageAttributes -}}
    {{- $m := dict -}}
    {{- range $imageAttributes -}}
      {{- $m = set $m . . -}}
    {{- end -}}
    {{- $imageAttributes = $m -}}
  {{- end -}}


  {{- $pending := dict -}}
  {{- range $allAttributes -}}
     {{- $pending = set $pending . . -}}
  {{- end -}}

  {{- $result := dict -}}
  {{- $imageSuffix := ((not (empty $image)) | ternary (printf ".%s" $image) "") -}}

  {{- $found := false -}}
  {{- range $s := $search -}}
    {{- /* Small optimization - don't search if there's nothing missing */ -}}
    {{- if $pending -}}
      {{- /* First things first: make sure the search scope is a non-empty map */ -}}
      {{- $r := (include "arkcase.tools.get" (dict "ctx" $data "name" $s) | fromYaml) -}}
      {{- if and $r.value (kindIs "map" $r.value) -}}
        {{- /* If we've been given an image name, we can only consider the image */ -}}
        {{- /* attributes from maps that match that given name (i.e. ends with */ -}}
        {{- /* $imageSuffix. If we don't have an image name, then named scopes will */ -}}
        {{- /* not be included in the search path possibilities. */ -}}
        {{- if or (not $image) (hasSuffix $imageSuffix $s) -}}
          {{- range $att := $imageAttributes -}}
            {{- /* Never override values we've already found */ -}}
            {{- if not (hasKey $result $att) -}}
              {{- $found = (or $found (hasKey $r.value $att)) -}}
              {{- if $found -}}
                {{- $v := get $r.value $att -}}
                {{- /* Only accept non-empty strings */ -}}
                {{- if and $v (kindIs "string" $v) -}}
                  {{- $result = set $result $att $v -}}
                  {{- /* Mark the found attribute as ... well ... found! */ -}}
                  {{- $pending = omit $pending $att -}}
                {{- end -}}
              {{- end -}}
            {{- end -}}
          {{- end -}}
        {{- end -}}

        {{- /* Only proceed if we've found the image "declaration" */ -}}
        {{- if $found -}}
          {{- range $att := $commonAttributes -}}
            {{- /* Never override values we've already found */ -}}
            {{- if not (hasKey $result $att) -}}
              {{- $v := get $r.value $att -}}
              {{- /* Only accept non-empty strings */ -}}
              {{- if and $v (kindIs "string" $v) -}}
                {{- $result = set $result $att $v -}}
                {{- /* Mark the found attribute as ... well ... found! */ -}}
                {{- $pending = omit $pending $att -}}
              {{- end -}}
            {{- end -}}
          {{- end -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}

  {{- /* If we didn't find an image, but we were given a fallback repository, */ -}}
  {{- /* then we render it as if it were a top-level image. */ -}}
  {{- if and $repository (not (hasKey $result "repository")) -}}
    {{- $result = set $result "repository" $repository -}}
    {{- $pending = omit $pending "repository" -}}

    {{- if and $pending (hasKey $data.local $repository) -}}
      {{- $scope := get $data.local $repository -}}
      {{- if and $scope (kindIs "map" $scope) -}}
        {{- /* Try to get the image attributes from the specifically-named branch */ -}}
        {{- range $att := $allAttributes -}}
          {{- /* Never override values we've already found */ -}}
          {{- if not (hasKey $result $att) -}}
            {{- $v := get $scope $att -}}
            {{- /* Only accept non-empty strings */ -}}
            {{- if and $v (kindIs "string" $v) -}}
              {{- $result = set $result $att $v -}}
              {{- /* Mark the found attribute as ... well ... found! */ -}}
              {{- $pending = omit $pending $att -}}
            {{- end -}}
          {{- end -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}

    {{- /* Whatever we got above, we only seek out common attributes */ -}}
    {{- /* from the overarching branch. This avoids collisions with */ -}}
    {{- /* image attributes for single-image charts. */ -}}
    {{- if $pending -}}
      {{- $scope := $data.local -}}
      {{- range $att := $commonAttributes -}}
        {{- /* Never override values we've already found */ -}}
        {{- if not (hasKey $result $att) -}}
          {{- $v := get $scope $att -}}
          {{- /* Only accept non-empty strings */ -}}
          {{- if and $v (kindIs "string" $v) -}}
            {{- $result = set $result $att $v -}}
            {{- /* Mark the found attribute as ... well ... found! */ -}}
            {{- $pending = omit $pending $att -}}
          {{- end -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}

  {{- /* Finally, if this is the "default" image, and doesn't have a tag, */ -}}
  {{- /* then by default use the chart's appversion value as the image tag. */ -}}
  {{- if and (not $image) (not (hasKey $result "tag")) -}}
    {{- $result = set $result "tag" ($ctx.Chart.AppVersion | toString) -}}
    {{- $pending = omit $pending "tag" -}}
  {{- end -}}

  {{- /* Now we have the map with the explicitly set data. */ -}}
  {{- /* We must now found any pending overrides, and apply them */ -}}
  {{- /* using the correct order of precedence. */ -}}

  {{-
    $search = (
      list
        "global.image"
        (printf "global.%s.image" $chart)
        ((not (empty $image)) | ternary (printf "global.%s.image.%s" $chart $image) "")
        (printf "global.%s.image.%s" $chart $edition)
        ((not (empty $image)) | ternary (printf "global.%s.image.%s.%s" $chart $edition $image) "")
    ) | compact
  -}}
  {{- $pending = dict -}}
  {{- range $allAttributes -}}
     {{- $pending = set $pending . . -}}
  {{- end -}}
  {{- $override := dict -}}
  {{- range $s := $search -}}
    {{- /* Small optimization - don't search if there's nothing missing */ -}}
    {{- if $pending -}}
      {{- $r := (include "arkcase.tools.get" (dict "ctx" $data "name" $s) | fromYaml) -}}
      {{- if and $r.value (kindIs "map" $r.value) -}}
        {{- /* Find the remaining attributes */ -}}
        {{- range $att := $allAttributes -}}
          {{- if and (not (hasKey $override $att)) (hasKey $r.value $att) -}}
            {{- $v := get $r.value $att -}}

            {{- /* Only accept non-empty strings */ -}}
            {{- if and $v (kindIs "string" $v) -}}
              {{- $override = set $override $att $v -}}
              {{- /* Mark the found attribute as ... well ... found! */ -}}
              {{- $pending = omit $pending $att -}}
            {{- end -}}
          {{- end -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}

  {{- merge $override $result | toYaml -}}
{{- end -}}

{{- define "arkcase.image.pullSecrets.compute" -}}
  {{- $chart := .chart -}}
  {{- $edition := .edition -}}
  {{- $data := .data -}}

  {{- $candidates := list -}}

  {{-
    $candidates = concat $candidates (
      list
        "global.image.pullSecrets"
        (printf "global.image.%s.pullSecrets" $edition)
        (printf "global.%s.image.%s.pullSecrets" $chart $edition)
        (printf "local.%s.pullSecrets" $edition)
        "local.pullSecrets"
    )
  -}}

  {{- /* Now compute the values */ -}}
  {{- $v := "" -}}
  {{- $p := "" -}}
  {{- range $c := $candidates -}}
    {{- /* First non-blank wins! If the value is set to non-blank, */ -}}
    {{- /* or the candidate is blank, we skip this iteration */ -}}
    {{- if (not $p) -}}
      {{- $r := (include "arkcase.tools.get" (dict "ctx" $data "name" $c) | fromYaml) -}}
      {{- if and $r $r.value (not (kindIs "map" $r.value)) -}}
        {{- $v = $r.value -}}
        {{- $p = $c -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}

  {{- $r := dict "value" "" "location" "" -}}
  {{- if $v -}}
    {{- /* We support a single string, a CSV string, or a list ... the string gets converted to a list */ -}}
    {{- if (kindIs "string" $v) -}}
      {{- $v = splitList "," $v -}}
    {{- end -}}
    {{- $d := dict -}}
    {{- $f := list -}}
    {{- range $v -}}
      {{- /* Each element is either a string, or a map for whom only the "name:" key will be consumed */ -}}
      {{- /* if it's anything else, this is an error */ -}}
      {{- $s := "" -}}
      {{- if and (kindIs "string" .) . -}}
        {{- $s = . -}}
      {{- else if and (kindIs "map" .) .name -}}
        {{- $s = (.name | toString) -}}
      {{- else -}}
        {{- fail (printf "Invalid pull secret type %s - must be a valid RFC-1123 hostname part (from %s)" (kindOf .) $p) -}}
      {{- end -}}

      {{- /* Deduplicate */ -}}
      {{- if and $s (not (hasKey $d $s)) -}}
        {{- /* Made sure sure it's a valid pull secret name */ -}}
        {{- if not (include "arkcase.tools.hostnamePart" $s) -}}
          {{- fail (printf "Invalid pull secret name [%s] - must be a valid RFC-1123 hostname part (from %s)" $s $p) -}}
        {{- end -}}
        {{- $d = set $d $s $s -}}
        {{- $f = append $f (dict "name" $s) -}}
      {{- end -}}
    {{- end -}}
    {{- if $f -}}
      {{- $r = dict "value" $f "location" $p -}}
    {{- end -}}
  {{- end -}}
  {{- $r | toYaml -}}
{{- end -}}

{{- define "arkcase.image.pullSecrets.cached" -}}
  {{- $ctx := . -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The  parameter must be the root context (. or $)" -}}
  {{- end -}}

  {{- $edition := (empty (include "arkcase.enterprise" $ctx) | ternary "community" "enterprise") -}}

  {{- /* First things first: do we have any global overrides? */ -}}
  {{- $global := $ctx.Values.global -}}
  {{- if or (not $global) (not (kindIs "map" $global)) -}}
    {{- $global = dict -}}
  {{- end -}}

  {{- /* Now get the local values */ -}}
  {{- $local := $ctx.Values -}}
  {{- if and $local (hasKey $local "image") $local.image (kindIs "map" $local.image) -}}
    {{- $local = $local.image -}}
  {{- else -}}
    {{- $local = dict -}}
  {{- end -}}

  {{- /* The keys on this map are the images in the local repository */ -}}
  {{- $chart := $ctx.Chart.Name -}}
  {{- $data := dict "local" $local "global" $global -}}

  {{- $cacheKey := "PullSecret" -}}
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
    {{- $yamlResult = include "arkcase.image.pullSecrets.compute" (dict "chart" $chart "edition" $edition "data" $data) -}}
    {{- $masterCache = set $masterCache $chartName ($yamlResult | fromYaml) -}}
  {{- else -}}
    {{- $yamlResult = get $masterCache $chartName | toYaml -}}
  {{- end -}}
  {{- $yamlResult -}}
{{- end -}}

{{- /*
Render the pull secret
*/ -}}
{{- define "arkcase.image.pullSecrets" -}}
  {{- $ctx := . -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The  parameter must be the root context (. or $)" -}}
  {{- end -}}

  {{- $r := (include "arkcase.image.pullSecrets.cached" $ctx | fromYaml) -}}
  {{- if and $r $r.value -}}
imagePullSecrets: {{- toYaml $r.value | nindent 2 }}
  {{- end -}}
{{- end -}}

{{- /*
Compute the image information for the named image, including registry, repository, tag,
and image pull policy, while taking into account the edition in play (enterprise vs.
community) in order to choose the correct image.
*/ -}}
{{- define "arkcase.image.info.cached" -}}
  {{- $ctx := .ctx -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The 'ctx' parameter must be the root context (. or $)" -}}
  {{- end -}}

  {{- $name := .name -}}
  {{- $repository := .repository -}}
  {{- $tag := .tag -}}
  {{- $useChartTag := .useChartTag -}}

  {{- if not (hasKey . "enterprise") -}}
    {{- fail "The enterprise flag must be set" -}}
  {{- end -}}
  {{- $edition := .enterprise | ternary "enterprise" "community" -}}

  {{- /* First things first: do we have any global overrides? */ -}}
  {{- $global := $ctx.Values.global -}}
  {{- if or (not $global) (not (kindIs "map" $global)) -}}
    {{- $global = dict -}}
  {{- end -}}

  {{- /* Now get the local values */ -}}
  {{- $local := $ctx.Values -}}
  {{- if and $local (hasKey $local "image") $local.image (kindIs "map" $local.image) -}}
    {{- $local = $local.image -}}
  {{- else -}}
    {{- $local = dict -}}
  {{- end -}}

  {{- /* The keys on this map are the images in the local repository */ -}}
  {{- $chart := $ctx.Chart.Name -}}
  {{- $data := dict "local" $local "global" $global -}}

  {{- $image := (include "arkcase.image.info.definition" (dict "ctx" $ctx "chart" $chart "image" $name "edition" $edition "repository" $repository "data" $data) | fromYaml) -}}

  {{- /* Make sure we have a repository for the image */ -}}
  {{- $finalRepository := $image.repository -}}
  {{- if not $finalRepository -}}
    {{- $finalRepository = $repository -}}
  {{- end -}}
  {{- if not $finalRepository -}}
    {{- fail (printf "Failed to find a repository value for image [%s], chart [%s] (%s)" $name $chart $edition) -}}
  {{- end -}}
  {{- $image = set $image "image" $finalRepository -}}

  {{- /* Append the tag, if necessary */ -}}
  {{- $finalTag := $image.tag -}}
  {{- if not $finalTag -}}
    {{- $finalTag = $tag -}}
  {{- end -}}
  {{- if and (not $finalTag) $useChartTag -}}
    {{- $finalTag = $ctx.Chart.Version -}}
  {{- end -}}
  {{- if $finalTag -}}
    {{- $image = set $image "image" (printf "%s:%s" $image.image $finalTag) -}}
  {{- end -}}

  {{- /* Append the registry, if necessary */ -}}
  {{- if $image.registry -}}
    {{- $image = set $image "image" (printf "%s/%s" $image.registry $image.image) -}}
  {{- end -}}
  {{- $image | toYaml -}}
{{- end -}}

{{- /*
Fetch and compute if necessary the image information for the named image
*/ -}}
{{- define "arkcase.image.info" -}}
  {{- $ctx := . -}}
  {{- $name := "" -}}
  {{- $repository := "" -}}
  {{- $tag := "" -}}
  {{- $useChartTag := true -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- $ctx = .ctx -}}
    {{- if not (include "arkcase.isRootContext" $ctx) -}}
      {{- fail "The given 'ctx' parameter must be the root context (. or $)" -}}
    {{- end -}}

    {{- $name = .name -}}
    {{- if not $name -}}
      {{- fail "The given 'name' parameter must be present and not be the empty string" -}}
    {{- end -}}
    {{- $repository = .repository -}}
    {{- $tag = .tag -}}
    {{- $useChartTag := (eq "true" (.useChartTag | toString | default "false" | lower)) -}}
  {{- end -}}

  {{- if not $name -}}
    {{- /* If no name was given (i.e. called with $ctx == $ or .), we use the part name. */ -}}
    {{- $name = default (include "arkcase.part.name" $ctx) "" -}}
  {{- end -}}

  {{- $enterprise := (not (empty (include "arkcase.enterprise" $ctx))) -}}

  {{- $cacheKey := "ContainerImages" -}}
  {{- $masterCache := dict -}}
  {{- if (hasKey $ctx $cacheKey) -}}
    {{- $masterCache = get $ctx $cacheKey -}}
    {{- if and $masterCache (not (kindIs "map" $masterCache)) -}}
      {{- $masterCache = dict -}}
    {{- end -}}
  {{- end -}}
  {{- $ctx = set $ctx $cacheKey $masterCache -}}

  {{- /* We do not use arkcase.fullname b/c we don't want to deal with partnames */ -}}
  {{- $imageName := (printf "%s-%s-%s" (include "common.fullname" $ctx) $name) -}}
  {{- $yamlResult := "" -}}
  {{- if not (hasKey $masterCache $imageName) -}}
    {{- $yamlResult = include "arkcase.image.info.cached" (dict "ctx" $ctx "name" $name "enterprise" $enterprise "repository" $repository "tag" $tag "useChartTag" $useChartTag) -}}
    {{- $masterCache = set $masterCache $imageName ($yamlResult | fromYaml) -}}
  {{- else -}}
    {{- $yamlResult = get $masterCache $imageName | toYaml -}}
  {{- end -}}
  {{- $yamlResult -}}
{{- end -}}

{{- /*
Render the image name taking into account the registry, repository, image name, and tag.
*/ -}}
{{- define "arkcase.image" -}}
  {{- $imageInfo := (include "arkcase.image.info" . | fromYaml) -}}
image: {{ $imageInfo.image | quote }}
  {{- with $imageInfo.pullPolicy }}
imagePullPolicy: {{ . }}
  {{- end }}
{{- end -}}
