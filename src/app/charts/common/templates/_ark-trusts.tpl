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
  {{- $current := 0 -}}
  {{- $dupes := dict -}}
  {{- range $trusts -}}
    {{- $current = add 1 $current -}}
    {{- if (kindIs "string" .) -}}
      {{- $value := "" -}}
      {{- $type := "" -}}
      {{- if and (contains "-----BEGIN CERTIFICATE-----" .) (contains "-----END CERTIFICATE-----" .) -}}
        {{- $value = . -}}
        {{- $type = "pem" -}}
      {{- else if (regexMatch "^([^:/?#]+)://([^/?#]*)([^?#]*)([?]([^#]*))?(#(.*))?$" .) -}}
        {{- $value = . -}}
        {{- $type = "url" -}}
      {{- else if (regexMatch "^(([^@]+)@)?(([^:]+):([1-9][0-9]*))$" .) -}}
        {{- $value = . -}}
        {{- $type = "ssl" -}}
      {{- else -}}
        {{- fail (printf "Value # %d for global.trusts is not valid - must be a PEM-encoded certificate, URL from which to download one (using curl), or an SSL endpoing of the form [serverName@]hostnameOrIP[:port]. Bad value = [%s]" $current .) -}}
      {{- end -}}

      {{- if $value -}}
        {{- $hash := ($value | sha256sum) -}}
        {{- if (not (hasKey $dupes $hash)) -}}
          {{- $name := (printf "ssl-trust-%03d" (len $finalTrusts)) -}}
          {{- $result := (dict "type" $type "name" $name "value" $value "hash" $hash) -}}
          {{- $finalTrusts = append $finalTrusts $result -}}
          {{- $dupes = set $dupes $hash $result -}}
        {{- end -}}
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

  {{- $cacheKey := "ArkCase-SSLTrusts" -}}
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
  mountPath: "/.trusts"
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
