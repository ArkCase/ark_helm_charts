{{- define "arkcase.app.image.artifacts" -}}
  {{- $imageName := "artifacts" -}}
  {{- $foia := (include "arkcase.foia" $.ctx | fromYaml) -}}
  {{- if $foia -}}
    {{- $imageName = (printf "%s-foia" $imageName) -}}
  {{- end -}}
  {{- $param := (merge (dict "name" $imageName) (omit $ "name")) -}}
  {{- include "arkcase.image" $param }}
{{- end -}}

{{- define "arkcase.artifacts.external" -}}
  {{- $url := (include "arkcase.tools.conf" (dict "ctx" $ "value" "app-artifacts.url" "detailed" true) | fromYaml) -}}
  {{- if or (and $url $url.global) -}}
    {{- true -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.app.issuerByDomain" -}}
  {{- $domain := (. | toString) -}}
  {{- $elements := (splitList "." $domain | compact) -}}
  {{- if (lt (len $elements) 2) -}}
    {{- fail (printf "Insufficient domain components in domain [%s] - must have at least 2" $domain) -}}
  {{- end -}}
  {{- /* Here we use reverse so we can grab the first two elements, and then flip them again */ -}}
  {{- slice (reverse $elements) 0 2 | reverse | join "-" -}}
{{- end -}}

{{- define "arkcase.app.ingress.sanitize-modules" -}}
  {{- $ingress := ($ | default dict) -}}
  {{- $entries := dict -}}
  {{- $hasPrivate := false -}}
  {{- if and $ingress $ingress.modules -}}
    {{- range $module, $mode := ((kindIs "map" $ingress.modules) | ternary $ingress.modules dict) -}}
      {{ if (not (include "arkcase.tools.hostnamePart" $module)) -}}
        {{- continue -}}
      {{- end -}}
      {{- $mode = ($mode | toString | default "off" | lower) -}}
      {{- if (eq "true" $mode) -}}
        {{- $mode = "public" -}}
      {{- end -}}
      {{- if or (eq "public" $mode) (eq "private" $mode) -}}
        {{- $entries = set $entries $module $mode -}}
        {{- $hasPrivate = (or $hasPrivate (eq "private" $mode)) -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
  {{- dict "private" $hasPrivate "entries" $entries | toYaml -}}
{{- end -}}

{{- define "arkcase.app.ingress.sanitize-cloud" -}}
  {{- $ctx := $.ctx -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The 'ctx' parameter given must be the root context (. or $)" -}}
  {{- end -}}

  {{- $baseUrl := $.baseUrl -}}
  {{- if or (not $baseUrl) (not (kindIs "map" $baseUrl)) -}}
    {{- fail "Must provide the parsed-out base URL object as the baseUrl parameter" -}}
  {{- end -}}

  {{- $ingress := ($.ingress | default dict) -}}
  {{- $result := dict -}}

  {{- /* First, set the basic stuff that overrides everything else */ -}}
  {{- if $ingress.className -}}
    {{- $result = set $result "className" $ingress.className -}}
  {{- end -}}
  {{- $result = set $result "labels" ((kindIs "map" $ingress.labels) | ternary $ingress.labels dict) -}}
  {{- $result = set $result "annotations" ((kindIs "map" $ingress.annotations) | ternary $ingress.annotations dict) -}}

  {{- /* Now check to see if we have any special cloud stuff */ -}}
  {{- /* (we ALWAYS have cloud stuff - even if it's just "default" */ -}}
  {{- $defaultCloud := (dict "type" "default") -}}

  {{- $cloud := dict -}}
  {{- if (hasKey $ingress "cloud") -}}
    {{- /* No backwards compatibility applicable */ -}}
    {{- $cloud = $ingress.cloud -}}
  {{- else if (include "arkcase.toBoolean" (get $ingress "ai5-rancher")) -}}
    {{- /* Provide a little backwards compatibility */ -}}
    {{- $hostname := $baseUrl.hostname -}}
    {{- if (hasKey $ingress "ai5-hostname") -}}
      {{- $hostname = (get $ingress "ai5-hostname" | toString) -}}
    {{- end -}}
    {{- $cloud = dict "type" "ai5" "ai5" (dict "public" (ne $hostname $baseUrl.hostname)) -}}
  {{- end -}}

  {{- /* Make sure the $cloud map has the expected form */ -}}
  {{- if not (kindIs "map" $cloud) -}}
    {{- if not (kindIs "string" $cloud) -}}
      {{- fail (printf "The ingress's cloud specification may be a string or a map, but not a %s: [%s]" (kindOf $cloud) $cloud) -}}
    {{- end -}}
    {{- $cloud = dict "type" $cloud -}}
  {{- end -}}
  {{- $cloud = merge $cloud $defaultCloud -}}

  {{- /* Get the specific cloud configurations from the values file */ -}}
  {{- $cloudType := $cloud.type -}}
  {{- $cloud = ((hasKey $cloud $cloudType) | ternary (get $cloud $cloudType) dict) -}}
  {{- if not (kindIs "map" $cloud) -}}
    {{- $cloud = dict -}}
  {{- end -}}

  {{- /* Get the general cloud configurations from the chart support */ -}}
  {{- $cloudSupport := ($ctx.Files.Get "clouds.yaml" | fromYaml | default dict) -}}
  {{- if $cloudSupport -}}
    {{- if not (hasKey $cloudSupport $cloudType) -}}
      {{- /* If we were given an unknown cloud configuration, use our default settings */ -}}
      {{- $cloudType = $defaultCloud.type -}}
    {{- end -}}
    {{- $cloudSupport = get $cloudSupport $cloudType -}}
    {{- if and $cloudSupport (kindIs "map" $cloudSupport) -}}
      {{- $cloud = merge $cloud $cloudSupport -}}
    {{- end -}}
  {{- end -}}

  {{- /* This will be used for rendering the labels/annotations */ -}}
  {{- $valueCtx := dict "url" (deepCopy $baseUrl) "cfg" (omit $cloud "labels" "annotations" "providesCertificate") -}}

  {{- /* Compute any dynamic label and annotation values */ -}}
  {{- range $element := (list "labels" "annotations") -}}
    {{- if not (hasKey $cloud $element) -}}
      {{- continue -}}
    {{- end -}}

    {{- $map := (get $cloud $element) -}}
    {{- range $key, $value := $map -}}
      {{- $map = set $map $key (tpl ($value | toString) $valueCtx | trim) -}}
    {{- end -}}
    {{- $cloud = set $cloud $element $map -}}
  {{- end -}}

  {{- /* Ensure this value is a boolean! */ -}}
  {{- $cloud = set $cloud "providesCertificate" (not (empty (include "arkcase.toBoolean" $cloud.providesCertificate))) -}}

  {{- merge $result (pick $cloud "className" "labels" "annotations" "providesCertificate") | toYaml -}}
{{- end -}}
