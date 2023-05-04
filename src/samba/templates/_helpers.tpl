{{- define "arkcase.samba.step" -}}
  {{- /* Default result is true, unless explicitly turned off */ -}}
  {{- $result := "true" -}}
  {{- $config := (.Values.configuration | default dict) -}}
  {{- if and (hasKey $config "step") (kindIs "map" $config.step) (hasKey $config.step "enabled") (not (eq "true" ($config.step.enabled | toString | lower))) -}}
    {{- $result = "" -}}
  {{- end -}}
  {{- $result -}}
{{- end -}}

{{- define "arkcase.samba.external" -}}
  {{- $url := (include "arkcase.tools.conf" (dict "ctx" $ "value" "ldap.url" "detailed" true) | fromYaml) -}}
  {{- if and $url $url.global -}}
    {{- true -}}
  {{- end -}}
{{- end -}}
