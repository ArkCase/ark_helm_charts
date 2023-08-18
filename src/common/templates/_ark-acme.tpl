{{- define "arkcase.acme.env" -}}
  {{- $url := (include "arkcase.tools.parseUrl" "https://acme:9000" | fromYaml) -}}
  {{- $acme := (include "arkcase.dependency.target" (dict "ctx" $ "hostname" "acme") | fromYaml) -}}
  {{- if $acme -}}
    {{- if not (hasKey $acme "url") -}}
      {{- fail "You must specify the acme endpoint using a URL, not a hostname-port combination" -}}
    {{- end -}}
    {{- $scheme := ($url.scheme | lower) -}}
    {{- if (ne "https" $scheme) -}}
      {{- fail (printf "The acme URL must be an HTTPS URL: %s" $url.url) -}}
    {{- end -}}
    {{- $url = $acme.url -}}
  {{- end -}}
- name: ACME_URL
  value: {{ $url.url | quote }}
{{- end -}}

{{- define "arkcase.acme.sharedSecret" -}}
  {{- if not (include "arkcase.isRootContext" $) -}}
    {{- fail "The parameter given must be the root context (. or $)" -}}
  {{- end -}}
  {{- printf "%s-acme-shared" $.Release.Name -}}
{{- end -}}

{{- define "arkcase.acme.passwordVariable" -}}
ACME_CLIENT_PASSWORD
{{- end -}}

{{- define "arkcase.acme.volumeMount" -}}
  {{- if not (include "arkcase.isRootContext" $) -}}
    {{- fail "The parameter given should be the root context (. or $)" -}}
  {{- end -}}
- name: &acmeVolume "acme"
  mountPath: "/.acme.password"
  subPath: &acmePassword {{ include "arkcase.acme.passwordVariable" $ | quote }}
  readOnly: true
{{- end -}}

{{- define "arkcase.acme.volume" -}}
  {{- if not (include "arkcase.isRootContext" $) -}}
    {{- fail "The parameter given should be the root context (. or $)" -}}
  {{- end -}}
- name: *acmeVolume
  secret:
    optional: false
    secretName: {{ include "arkcase.acme.sharedSecret" $ | quote }}
    defaultMode: 0444
    items:
      - key: *acmePassword
        path: *acmePassword
{{- end -}}
