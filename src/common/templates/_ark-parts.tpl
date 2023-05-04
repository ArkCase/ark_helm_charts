{{- define "arkcase.part.name" -}}
  {{- $ctx := . -}}
  {{- $explicit := false -}}
  {{- $partname := "" -}}

  {{- if hasKey . "ctx" -}}
    {{- $ctx = .ctx -}}
    {{- if hasKey . "subname" -}}
      {{- $partname = (.subname | toString | lower) -}}
      {{- $explicit = true -}}
    {{- end -}}
  {{- end -}}

  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "Incorrect context given - either submit the root context as the only parameter, or a 'ctx' parameter pointing to it" -}}
  {{- end -}}

  {{- if not $explicit -}}
    {{- $template := ($ctx.Template.Name | base | lower) -}}
    {{- $template = (trimSuffix (ext $template) $template) -}}

    {{- /* Does it match our required expression? */ -}}
    {{- if regexMatch "^ark-[a-z0-9]+-.*$" $template -}}
      {{- $partname = (regexReplaceAll "^(ark-[a-z0-9]+-)" $template "") -}}
    {{- end -}}
  {{- end -}}

  {{- if and $partname (regexMatch "^([a-z][a-z0-9-]*)?[a-z]$" $partname) -}}
    {{- $partname -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.values" -}}
  {{- $ctx := .ctx -}}
  {{- $base := .base -}}
  {{- if kindIs "string" $base -}}
    {{- /* Must be the name of the map we're supposed to work with */ -}}
    {{- if not (hasKey $ctx.Values $base) -}}
      {{- /* nothing to work with ... */ -}}
      {{- $base = "" -}}
    {{- else -}}
      {{- $base = get $ctx.Values $base -}}
    {{- end -}}
  {{- end -}}

  {{- /* The namespaced stuff can only be applied if the base object is a map */ -}}
  {{- if kindIs "map" $base -}}
    {{- $common := dict -}}
    {{- /* If there's a "common" key, use that as the base template data */ -}}
    {{- /* Otherwise, if there's no "common" object, use no data */ -}}
    {{- if hasKey $base "common" -}}
      {{- $common = get $base "common" -}}
    {{- end -}}
    {{- $partname := (include "arkcase.part.name" $ctx) -}}
    {{- if and $partname (hasKey $base $partname) -}}
      {{- $part := get $base $partname -}}
      {{- /* If both $part and $common are not "empty" (non-null), then */ -}}
      {{- /* they must be of the same type. Otherwise this is an error */ -}}
      {{- /* and we cannot proceed. */ -}}
      {{- if and $part $common -}}
        {{- /* They must be of the same type */ -}}
        {{- if not (eq (kindOf $part) (kindOf $common)) -}}
          {{- fail (printf "Mismatching types for common and part values: %s vs. %s"  (kindOf $part) (kindOf $common)) -}}
        {{- end -}}
        {{- if kindIs "map" $part -}}
          {{- /* Both are maps ... so merge them */ -}}
          {{- $base = merge $part $common -}}
        {{- else -}}
          {{- /* It's a scalar value, or a list ... so we return the value from the part */ -}}
          {{- $base = $part -}}
        {{- end -}}
      {{- else if $part -}}
        {{- $base = $part -}}
      {{- else -}}
        {{- $base = $common -}}
      {{- end -}}
    {{- else -}}
      {{- $base = $common -}}
    {{- end -}}
  {{- end -}}
  {{- if $base -}}
    {{- $base = (dict "value" $base) -}}
  {{- else -}}
    {{- $base = dict -}}
  {{- end -}}
  {{- $base | toYaml -}}
{{- end -}}
