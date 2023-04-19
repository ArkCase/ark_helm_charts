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

{{- define "arkcase.image.info.getValue" -}}
  {{- $chart := .chart -}}
  {{- $image := .image -}}
  {{- $edition := .edition -}}
  {{- $value := .value -}}
  {{- $data := .data -}}

  {{- $candidates := list -}}

  {{- /* First things first: the first two candidates are the "super global" values, but */ -}}
  {{- /* they don't apply for repository or tag */ -}}
  {{- if and (ne $value "tag") (ne $value "repository") -}}
    {{-
      $candidates = concat $candidates (
        list
          (printf "global.%s" $value)
          (printf "global.%s.%s" $value $edition)
      )
    -}}
  {{- end -}}

  {{-
    $detailed := list
        $value
        (printf "%s.%s" $value $edition)
        (and $image (ne $value "pullSecret") | ternary (printf "%s.%s" $image $value) "")
        (printf "%s.%s" $edition $value)
        (and $image (ne $value "pullSecret") | ternary (printf "%s.%s.%s" $edition $image $value) "")
  -}}

  {{- /* Render the global candidate values */ -}}
  {{- $globalPrefix := (printf "global.%s" $chart) -}}
  {{- range $d := $detailed -}}
    {{- if $d -}}
      {{- $candidates = append $candidates (printf "%s.%s" $globalPrefix $d) -}}
    {{- end -}}
  {{- end -}}

  {{- /* The local values go in exact reverse order to the global */ -}}
  {{- $localPrefix := "local" -}}
  {{- range $d := (reverse $detailed) -}}
    {{- if $d -}}
      {{- $candidates = append $candidates (printf "%s.%s" $localPrefix $d) -}}
    {{- end -}}
  {{- end -}}

  {{- /* Now compute the values */ -}}
  {{- $v := "" -}}
  {{- range $c := $candidates -}}
    {{- /* First non-blank wins! If the value is set to non-blank, */ -}}
    {{- /* or the candidate is blank, we skip this iteration */ -}}
    {{- if (not $v) -}}
      {{- $r := (include "arkcase.tools.get" (dict "ctx" $data "name" $c) | fromYaml) -}}
      {{- if and $r $r.value (kindIs "string" $r.value) -}}
        {{- $v = $r.value -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
  {{- $v -}}
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

  {{- if not (hasKey . "enterprise") -}}
    {{- fail "The enterprise flag must be set" -}}
  {{- end -}}
  {{- $edition := .enterprise | ternary "enterprise" "community" -}}

  {{- /* First things first: do we have any global overrides? */ -}}
  {{- $global := $ctx.Values.global -}}
  {{- if and $global (hasKey $global "image") $global.image (kindIs "map" $global.image) -}}
    {{- $global = $global.image -}}
  {{- else -}}
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
  {{- $result := dict -}}
  {{- range $value := list "pullPolicy" "pullSecret" "repository" "registry" "tag" -}}
    {{- $r := (include "arkcase.image.info.getValue" (dict "chart" $chart "image" $name "edition" $edition "value" $value "data" $data)) -}}
    {{- if $r -}}
      {{- if eq $value "pullPolicy" -}}
        {{- /* Make sure it's a valid pull policy value */ -}}
        {{- $r = (include "arkcase.image.info.parsePullPolicy" $r) -}}
      {{- else if and (eq $value "pullSecret") (not (include "arkcase.tools.hostnamePart" $r)) -}}
        {{- /* Made sure sure it's a valid pull secret name */ -}}
        {{- fail (printf "Invalid pull secret name [%s] - must be a valid RFC-1123 hostname part" $r) -}}
      {{- end -}}
      {{- $result = set $result $value $r -}}
    {{- end -}}
  {{- end -}}

  {{- /* Make sure we have a repository for the image */ -}}
  {{- if not $result.repository -}}
    {{- fail (printf "Failed to find a repository value for image [%s], chart [%s] (%s)" $name $chart $edition) -}}
  {{- end -}}
  {{- $result = set $result "image" $result.repository -}}

  {{- /* Append the tag, if necessary */ -}}
  {{- if $result.tag -}}
    {{- $result = set $result "image" (printf "%s:%s" $result.image $result.tag) -}}
  {{- end -}}
  {{- /* Append the registry, if necessary */ -}}
  {{- if $result.registry -}}
    {{- $result = set $result "image" (printf "%s/%s" $result.registry $result.image) -}}
  {{- end -}}
  {{- $result | toYaml -}}
{{- end -}}

{{- /*
Fetch and compute if necessary the image information for the named image
*/ -}}
{{- define "arkcase.image.info" -}}
  {{- $ctx := . -}}
  {{- $name := "" -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- $ctx = .ctx -}}
    {{- if not (include "arkcase.isRootContext" $ctx) -}}
      {{- fail "The given 'ctx' parameter must be the root context (. or $)" -}}
    {{- end -}}

    {{- $name = .name -}}
    {{- if not $name -}}
      {{- fail "The given 'name' parameter must be present and not be the empty string" -}}
    {{- end -}}
  {{- end -}}

  {{- if not $name -}}
    {{- /* If no name was given (i.e. called with $ctx == $ or .), we use the part name. */ -}}
    {{- $name = default (include "arkcase.part.name" $ctx) "" -}}
  {{- end -}}

  {{- $mode := (include "arkcase.deployment.mode" $ctx | fromYaml) -}}

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
    {{- $yamlResult = include "arkcase.image.info.cached" (set (pick . "ctx" "name") "enterprise" $mode.enterprise) -}}
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
  {{- $imageInfo.pullPolicy -}}
{{- end -}}

{{- /*
Render the pull secret
*/ -}}
{{- define "arkcase.image.pullSecret" -}}
  {{- $imageInfo := (include "arkcase.image.info" . | fromYaml) -}}
  {{- $imageInfo.pullSecret -}}
{{- end -}}
