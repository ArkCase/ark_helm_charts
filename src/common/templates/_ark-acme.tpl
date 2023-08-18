{{- define "arkcase.acme.envvars" -}}
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
