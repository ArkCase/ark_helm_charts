{{- define "arkcase.deployment.envvars" -}}
  {{- $url := (include "arkcase.tools.parseUrl" "https://app-artifacts" | fromYaml) -}}
  {{- $artifacts := (include "arkcase.dependency.target" (dict "ctx" $ "hostname" "app-artifacts") | fromYaml) -}}
  {{- if $artifacts -}}
    {{- if not (hasKey $artifacts "url") -}}
      {{- fail "You must specify the artifacts endpoint using a URL, not a hostname-port combination" -}}
    {{- end -}}
    {{- $scheme := ($url.scheme | lower) -}}
    {{- if and (ne "http" $scheme) (ne "https" $scheme) -}}
      {{- fail (printf "The artifacts URL must be an HTTP or HTTPS URL: %s" $url.url) -}}
    {{- end -}}
    {{- $url = $artifacts.url -}}
  {{- end -}}
- name: DEPL_URL
  value: {{ $url.url | quote }}
{{- end -}}
