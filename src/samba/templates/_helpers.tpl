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
  {{- $serverNames := (include "arkcase.tools.ldap.serverNames" $ | fromYaml) -}}
  {{- $external := 0 -}}
  {{- range $server := $serverNames.result -}}
    {{- $url := (include "arkcase.tools.ldap" (dict "ctx" $ "server" $server "value" "url" "detailed" true) | fromYaml) -}}
    {{- if and $url $url.external -}}
      {{- $external = add $external 1 -}}
    {{- end -}}
  {{- end -}}
  {{- /* If all the servers are external, then LDAP is external. */ -}}
  {{- /* Otherwise, there is at least one tree to serve. */ -}}
  {{- (eq $external (len $serverNames.result)) | ternary "true" "" -}}
{{- end -}}
