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
  {{- $chart := .chart -}}
  {{- $image := .image -}}
  {{- $edition := .edition -}}
  {{- $repository := .repository -}}
  {{- $data := .data -}}

  {{- $exclusiveAttributes := list "repository" "tag" -}}
  {{- $shareableAttributes := list "registry" "pullPolicy" -}}

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
  {{- $allAttributes := (concat $exclusiveAttributes $shareableAttributes) -}}

  {{- if $shareableAttributes -}}
    {{- $m := dict -}}
    {{- range $shareableAttributes -}}
      {{- $m = set $m . . -}}
    {{- end -}}
    {{- $shareableAttributes = $m -}}
  {{- end -}}
  {{- if $exclusiveAttributes -}}
    {{- $m := dict -}}
    {{- range $exclusiveAttributes -}}
      {{- $m = set $m . . -}}
    {{- end -}}
    {{- $exclusiveAttributes = $m -}}
  {{- end -}}


  {{- $pending := dict -}}
  {{- range $allAttributes -}}
     {{- $pending = set $pending . . -}}
  {{- end -}}

  {{- $result := dict -}}
  {{- $imageSuffix := ((not (empty $image)) | ternary (printf ".%s" $image) "") -}}

  {{- /* First, search on the maps that have the image's name */ -}}
  {{- range $s := $search -}}
    {{- /* Small optimization - don't search if there's nothing missing */ -}}
    {{- if $pending -}}
      {{- $r := (include "arkcase.tools.get" (dict "ctx" $data "name" $s) | fromYaml) -}}
      {{- if and $r.value (kindIs "map" $r.value) -}}
        {{- /* Find the remaining attributes */ -}}
        {{- range $att := $allAttributes -}}
          {{- $examine := (or (hasKey $shareableAttributes $att) (not $image) (and $imageSuffix (hasSuffix $imageSuffix $s))) -}}
          {{- if and $examine (not (hasKey $result $att)) (hasKey $r.value $att) -}}
            {{- $value := get $r.value $att -}}

            {{- /* We only take into account strings */ -}}
            {{- $ready := (or $result (not $imageSuffix) (hasSuffix $imageSuffix $s) (eq $att "repository")) -}}
            {{- if and $ready $value (kindIs "string" $value) -}}
              {{- $result = set $result $att $value -}}

              {{- /* Mark the found attribute as ... well ... found! */ -}}
              {{- $pending = omit $pending $att -}}
            {{- end -}}
          {{- end -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}

  {{- /* If we didn't find an image, but we were given a fallback repository, */ -}}
  {{- /* then we render it as if it were a top-level image. */ -}}
  {{- if and (not $result) $repository -}}
    {{- $result = dict "repository" $repository -}}
    {{- range (without $allAttributes "repository") -}} 
      {{- $v := get $data.local . -}}
      {{- if and $v (kindIs "string" $v) -}}
        {{- $result = set $result . $v -}}
      {{- end -}}
    {{- end -}}
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
            {{- $value := get $r.value $att -}}

            {{- /* We only take into account strings */ -}}
            {{- if and $value (kindIs "string" $value) -}}
              {{- $override = set $override $att $value -}}

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

{{- define "arkcase.image.info.pullSecrets" -}}
  {{- $chart := .chart -}}
  {{- $edition := .edition -}}
  {{- $data := .data -}}

  {{- $candidates := list -}}

  {{- /* First things first: the first two candidates are the "super global" values, but */ -}}
  {{- /* they don't apply for repository or tag */ -}}
  {{-
    $candidates = concat $candidates (
      list
        (printf "global.%s.image.%s.pullSecrets" $chart $edition)
        (printf "global.image.%s.pullSecrets" $edition)
        "global.image.pullSecrets"
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

  {{- dict "value" $v "location" $p | toYaml -}}
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

  {{- $image := (include "arkcase.image.info.definition" (dict "chart" $chart "image" $name "edition" $edition "repository" $repository "data" $data) | fromYaml) -}}

  {{- $r := (include "arkcase.image.info.pullSecrets" (dict "chart" $chart "edition" $edition "data" $data) | fromYaml) -}}
  {{- if and $r $r.value -}}
    {{- /* We support a single string, a CSV string, or a list ... the string gets converted to a list */ -}}
    {{- $v := $r.value -}}
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
        {{- fail (printf "Invalid pull secret type %s - must be a valid RFC-1123 hostname part (from %s)" (kindOf .) $r.location) -}}
      {{- end -}}

      {{- /* Deduplicate */ -}}
      {{- if and $s (not (hasKey $d $s)) -}}
        {{- /* Made sure sure it's a valid pull secret name */ -}}
        {{- if not (include "arkcase.tools.hostnamePart" $s) -}}
          {{- fail (printf "Invalid pull secret name [%s] - must be a valid RFC-1123 hostname part (from %s)" $s $r.location) -}}
        {{- end -}}
        {{- $d = set $d $s $s -}}
        {{- $f = append $f (dict "name" $s) -}}
      {{- end -}}
    {{- end -}}
    {{- $r = $f -}}
  {{- end -}}
  {{- $image = set $image "pullSecrets" $r -}}

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
    {{- $yamlResult = include "arkcase.image.info.cached" (dict "ctx" $ctx "name" $name "enterprise" $enterprise "repository" $repository "tag" $tag) -}}
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
  {{- $imageInfo.image -}}
{{- end -}}

{{- /*
Render the image's pull policy
*/ -}}
{{- define "arkcase.image.pullPolicy" -}}
  {{- $imageInfo := (include "arkcase.image.info" . | fromYaml) -}}
  {{- if $imageInfo.pullPolicy -}}
imagePullPolicy: {{ $imageInfo.pullPolicy }}
  {{- end -}}
{{- end -}}

{{- /*
Render the pull secret
*/ -}}
{{- define "arkcase.image.pullSecrets" -}}
  {{- $imageInfo := (include "arkcase.image.info" . | fromYaml) -}}
  {{- if $imageInfo.pullSecrets -}}
imagePullSecrets: {{- $imageInfo.pullSecrets | toYaml | nindent 2 }}
  {{- end -}}
{{- end -}}
