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
          (printf "global.image.%s" $value)
          (printf "global.image.%s.%s" $value $edition)
      )
    -}}
  {{- end -}}

  {{-
    $detailed := compact (
      list
        $value
        (printf "%s.%s" $value $edition)
        (and $image (ne $value "pullSecrets") | ternary (printf "%s.%s" $image $value) "")
        (printf "%s.%s" $edition $value)
        (and $image (ne $value "pullSecrets") | ternary (printf "%s.%s.%s" $edition $image $value) "")
    )
  -}}

  {{- /* Render the global candidate values */ -}}
  {{- $globalPrefix := (printf "global.%s.image" $chart) -}}
  {{- range $d := $detailed -}}
    {{- $candidates = append $candidates (printf "%s.%s" $globalPrefix $d) -}}
  {{- end -}}

  {{- /* The local values go in exact reverse order to the global */ -}}
  {{- $localPrefix := "local" -}}
  {{- $candidates = list -}}
  {{- range $d := (reverse $detailed) -}}
    {{- if $d -}}
      {{- $candidates = append $candidates (printf "%s.%s" $localPrefix $d) -}}
    {{- end -}}
  {{- end -}}

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

  {{- dict "value" $v "position" $p | toYaml -}}
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
  {{- $result := dict -}}
  {{- range $value := list "pullPolicy" "pullSecrets" "repository" "registry" "tag" -}}
    {{- $r := (include "arkcase.image.info.getValue" (dict "chart" $chart "image" $name "edition" $edition "value" $value "data" $data) | fromYaml) -}}
    {{- if and $r $r.value -}}
      {{- if eq $value "pullPolicy" -}}
        {{- /* Make sure it's a valid pull policy value */ -}}
        {{- if not (kindIs "string" $r.value) -}}
          {{- fail (printf "The pull policy value must be a string (%s) - at %s" (kindOf $r.value) $r.position) -}}
        {{- end -}}
        {{- $r = (include "arkcase.image.info.parsePullPolicy" $r.value) -}}
      {{- else if and (eq $value "pullSecrets") -}}
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
            {{- fail (printf "Invalid pull secret type %s - must be a valid RFC-1123 hostname part (from %s)" (kindOf .) $r.position) -}}
          {{- end -}}

          {{- /* Deduplicate */ -}}
          {{- if and $s (not (hasKey $d $s)) -}}
            {{- /* Made sure sure it's a valid pull secret name */ -}}
            {{- if not (include "arkcase.tools.hostnamePart" $s) -}}
              {{- fail (printf "Invalid pull secret name [%s] - must be a valid RFC-1123 hostname part (from %s)" $s $r.position) -}}
            {{- end -}}
            {{- $d = set $d $s $s -}}
            {{- $f = append $f (dict "name" $s) -}}
          {{- end -}}
        {{- end -}}
        {{- $r = $f -}}
      {{- else -}}
        {{- $r = $r.value -}}
      {{- end -}}
      {{- $result = set $result $value $r -}}
    {{- end -}}
  {{- end -}}

  {{- /* Make sure we have a repository for the image */ -}}
  {{- $finalRepository := $result.repository -}}
  {{- if not $finalRepository -}}
    {{- $finalRepository = $repository -}}
  {{- end -}}
  {{- if not $finalRepository -}}
    {{- fail (printf "Failed to find a repository value for image [%s], chart [%s] (%s)" $name $chart $edition) -}}
  {{- end -}}
  {{- $result = set $result "image" $finalRepository -}}

  {{- /* Append the tag, if necessary */ -}}
  {{- $finalTag := $result.tag -}}
  {{- if not $finalTag -}}
    {{- $finalTag = $tag -}}
  {{- end -}}
  {{- if $finalTag -}}
    {{- $result = set $result "image" (printf "%s:%s" $result.image $finalTag) -}}
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
