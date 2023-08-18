{{- define "arkcase.samba.external" -}}
  {{- $serverNames := (include "arkcase.ldap.serverNames" $ | fromYaml) -}}
  {{- $external := 0 -}}
  {{- range $server := $serverNames.result -}}
    {{- $url := (include "arkcase.ldap" (dict "ctx" $ "server" $server "value" "url" "detailed" true) | fromYaml) -}}
    {{- if and $url $url.external -}}
      {{- $external = add $external 1 -}}
    {{- end -}}
  {{- end -}}
  {{- /* If all the servers are external, then LDAP is external. */ -}}
  {{- /* Otherwise, there is at least one tree to serve. */ -}}
  {{- (eq $external (len $serverNames.result)) | ternary "true" "" -}}
{{- end -}}

{{- define "arkcase.samba.seeds" -}}
  {{- if not (include "arkcase.isRootContext" $) -}}
    {{- fail "The parameter given must be the root context (. or $)" -}}
  {{- end -}}

  {{- /* Find the seeds configuration (i.e. custom YAML provided by the deployer) */ -}}
  {{- /* If there's no such configuration, we simply render our own seeds. */ -}}
  {{- /* Otherwise, use those as our boot-up seeds */ -}}

  {{- /* The seeds must be a dict whose entries must dicts themselves */ -}}
  {{- $seeds := ((($.Values.global).conf).ldap).seed -}}

  {{- $result := dict -}}
  {{- if and $seeds (kindIs "map" $seeds) -}}
    {{- range $k, $v := $seeds -}}
      {{- $result = set $result (printf "seed-%s.yaml" $k) ($v | toYaml) -}}
    {{- end -}}
  {{- end -}}

  {{- /* Fill in the gaps with the default seeds, if they're not covered */ -}}
  {{- range $path, $_ := (.Files.Glob "files/seeds/seed-*.yaml") }}
    {{- $k := ($path | base) -}}
    {{- if not (hasKey $result $k) -}}
      {{- $result = set $result $k ($.Files.Get $path) -}}
    {{- end -}}
  {{- end }}

  {{- $result | toYaml -}}
{{- end -}}
