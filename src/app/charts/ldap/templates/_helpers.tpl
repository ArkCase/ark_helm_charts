{{- define "arkcase.samba.external" -}}
  {{- $conf := (include "arkcase.subsystem-access.conf" $ | fromYaml) -}}
  {{- not (empty $conf.external) | ternary "true" "" -}}
{{- end -}}

{{- define "arkcase.samba.seeds" -}}
  {{- if not (include "arkcase.isRootContext" $) -}}
    {{- fail "The parameter given must be the root context (. or $)" -}}
  {{- end -}}

  {{- /* Find the seeds configuration (i.e. custom YAML provided by the deployer) */ -}}
  {{- /* If there's no such configuration, we simply render our own seeds. */ -}}
  {{- /* Otherwise, use those as our boot-up seeds */ -}}

  {{- /* The seeds must be a dict whose entries must dicts themselves */ -}}
  {{- $seedConfig := ((($.Values.global).subsys).ldap).seed -}}

  {{- $result := dict -}}
  {{- if and $seedConfig (kindIs "map" $seedConfig) -}}
    {{- /* These values must be present regardless */ -}}
    {{-
      $preconfValues := (
        dict
          "domain" ""
          "realm" ""
          "rootDn" ""
          "baseDn" ""
          "userou" "userBaseDn"
          "groupou" "groupBaseDn"
      )
    -}}
    {{- range $serverName, $seeds := $seedConfig -}}
      {{- if (kindIs "map" $seeds) -}}
        {{- /* find the server section, replace the values for domain, realm, rootDn, baseDn, userou and groupou */ -}}
        {{- $server := $seeds.server -}}
        {{- if not (kindIs "map" $server) -}}
          {{- $server = dict -}}
        {{- end -}}

        {{- $prefix := (regexReplaceAllLiteral "[^A-Z0-9_]" ($serverName | snakecase | upper) "_") -}}

        {{- range $preconfKey, $preconfAlt := $preconfValues -}}
          {{- if not (hasKey $server $preconfKey) -}}
            {{- $server = set $server $preconfKey (printf "@env:%s_%s" ($prefix | upper) ($preconfAlt | default $preconfKey | snakecase | upper)) -}}
          {{- end -}}
        {{- end -}}
        {{- $seeds = set $seeds "server" $server -}}
        {{- $result = set $result (printf "seed-%s.yaml" $serverName) ($seeds | toYaml) -}}
      {{- else -}}
        {{- fail (printf "The seeds declaration in global.subsys.ldap.seed.%s is invalid: must be a map" $serverName) -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}

  {{- /* Fill in the gaps with the default seeds, if they're not covered */ -}}
  {{- range $path, $_ := (.Files.Glob "files/seeds/seed-*.yaml") -}}
    {{- $seedFile := ($path | base) -}}
    {{- if not (hasKey $result $seedFile) -}}
      {{- $result = set $result $seedFile ($.Files.Get $path) -}}
    {{- end -}}
  {{- end -}}

  {{- /* We don't allow override of these b/c these are for internal use only */ -}}
  {{- range $path, $_ := (.Files.Glob "files/seeds/managed-*.yaml") -}}
    {{- $seedFile := ($path | base) -}}
    {{- if not (hasKey $result $seedFile) -}}
      {{- $result = set $result $seedFile ($.Files.Get $path) -}}
    {{- end -}}
  {{- end -}}

  {{- $result | toYaml -}}
{{- end -}}
