{{- define "arkcase.trusts.certs.compute" -}}
  {{- if not (include "arkcase.isRootContext" $) -}}
    {{- fail "The parameter given must be the root context (. or $)" -}}
  {{- end -}}

  {{- $global := ($.Values.global | default dict) -}}
  {{- if or (not $global) (not (kindIs "map" $global)) -}}
    {{- $global = dict -}}
  {{- end -}}

  {{- $trusts := $global.trusts -}}
  {{- if or (not $trusts) (not (kindIs "slice" $trusts)) -}}
    {{- $trusts = list -}}
  {{- end -}}

  {{- $finalTrusts := list -}}
  {{- range $trusts -}}
    {{- if (kindIs "string" .) -}}
      {{- $cert := "" -}}
      {{- if and (contains "-----BEGIN CERTIFICATE-----" .) (contains "-----END CERTIFICATE-----" .) -}}
        {{- $cert = . -}}
      {{- else -}}
        {{- /* Validate that it's a URL */ -}}
        {{- if not (regexMatch "^[a-zA-Z0-9_-]+://" .) -}}
          {{- fail (printf "This value for global.trusts is not valid - must be a PEM-encoded certificate, or a URL from which to download one (using curl): [%s]" .) -}}
        {{- end -}}
        {{- $cert = . -}}
      {{- end -}}
      {{- if $cert -}}
        {{- $finalTrusts = append $finalTrusts $cert -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}

  {{- dict "certs" $finalTrusts | toYaml -}}
{{- end -}}

{{- define "arkcase.trusts.certs" -}}
  {{- $ctx := . -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The parameter given must be the root context (. or $)" -}}
  {{- end -}}

  {{- $cacheKey := "SSLTrusts" -}}
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
    {{- $yamlResult = (include "arkcase.trusts.certs.compute" $ctx) -}}
    {{- $masterCache = set $masterCache $masterKey ($yamlResult | fromYaml) -}}
  {{- else -}}
    {{- $yamlResult = get $masterCache $masterKey | toYaml -}}
  {{- end -}}
  {{- $yamlResult -}}
{{- end -}}

{{- define "arkcase.trusts.secret" -}}
  {{- if not (include "arkcase.isRootContext" $) -}}
    {{- fail "The parameter given must be the root context (. or $)" -}}
  {{- end -}}
  {{- printf "%s-ssl-trusts" $.Release.Name -}}
{{- end -}}

{{- define "arkcase.trusts.mount" -}}
  {{- if not (include "arkcase.isRootContext" $) -}}
    {{- fail "The parameter given must be the root context (. or $)" -}}
  {{- end -}}
  {{- $volumeName := (include "arkcase.trusts.secret" $) -}}
- name: &sslTrustSecrets {{ $volumeName | quote }}
  mountPath: "/.ssl-trusts"
  readOnly: true
{{- end -}}

{{- define "arkcase.trusts.volume" -}}
  {{- if not (include "arkcase.isRootContext" $) -}}
    {{- fail "The parameter given must be the root context (. or $)" -}}
  {{- end -}}
  {{- $secretName := (include "arkcase.trusts.secret" $) -}}
- name: *sslTrustSecrets
  secret:
    optional: true
    secretName: *sslTrustSecrets
    defaultMode: 0444
{{- end -}}
