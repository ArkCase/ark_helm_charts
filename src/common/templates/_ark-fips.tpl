{{- define "__arkcase.fips.default-crypto-dir" -}}
/app/crypto/bc
{{- end -}}

{{- define "arkcase.fips" -}}
  {{- $ctx := . -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- $ctx = $.ctx -}}
    {{- if not (include "arkcase.isRootContext" $ctx) -}}
      {{- fail "Must provide the root context (. or $) as either the only parameter, or the 'ctx' parameter" -}}
    {{- end -}}
  {{- end -}}
  {{- $global := ($ctx.Values.global | default dict) -}}
  {{- if not (kindIs "map" $global) -}}
    {{- $global = dict -}}
  {{- end -}}

  {{- $fips := (get $global "fips" | default (dict "enabled" false)) -}}
  {{- if (kindIs "map" $fips) -}}
    {{- $enabled := (hasKey $fips "enabled" | ternary (not (empty (include "arkcase.toBoolean" $fips.enabled))) false) -}}
    {{- $fips = set $fips "enabled" $enabled -}}
  {{- else -}}
    {{- $fips = dict "enabled" (not (empty (include "arkcase.toBoolean" ($fips | toString)))) -}}
  {{- end -}}

  {{- if $fips.enabled -}}
    {{- $cryptoDir := (get $fips "crypto-dir" | default (include "__arkcase.fips.default-crypto-dir" $) | toString) -}}
    {{- $modulePath := (get $fips "module-path" | default list) -}}
    {{- if $modulePath -}}
      {{- if not (kindIs "slice" $modulePath) -}}
        {{- fail (printf "The value for global.fips.module-path MUST be a list, not a %s: %s" (kindOf $modulePath) $modulePath) -}}
      {{- end -}}
      {{- $fips = set $fips "modulePath" (concat (list $cryptoDir) $modulePath | toStrings | compact | uniq) -}}
    {{- else -}}
      {{- $fips = set $fips "modulePath" (list $cryptoDir) -}}
    {{- end -}}
    {{- set $fips "cryptoDir" $cryptoDir | toYaml -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.fips.bool" -}}
  {{- (not (empty (include "arkcase.fips" $))) -}}
{{- end -}}

{{- define "arkcase.fips.module-path" -}}
  {{- $fips := (include "arkcase.fips" $ | fromYaml) -}}
  {{- if $fips -}}
--module-path={{ $fips.modulePath | join ":" }}
  {{- end -}}
{{- end -}}
