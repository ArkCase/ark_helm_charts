{{- define "arkcase.ldap.baseParam" -}}
  {{- $ctx := $ -}}
  {{- $root := true -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- $ctx = $.ctx -}}
    {{- $root = false -}}
  {{- end -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The parameter must be the root context, or a map with the root context as the 'ctx' element" -}}
  {{- end -}}
  {{- $result := dict "ctx" $ctx -}}
  {{- if and (not $root) (kindIs "string" $.server) $.server -}}
    {{- $result = set $result "server" $.server -}}
  {{- end -}}
  {{- $result | toYaml -}}
{{- end -}}

{{- define "arkcase.ldap.serverNames" -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- $ctx := $.ctx -}}
  {{- end -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The parameter must be the root context, or a map with the root context as the 'ctx' element" -}}
  {{- end -}}

  {{- $global := ((($ctx.Values.global).conf).ldap | default dict) -}}
  {{- $global = (kindIs "map" $global | ternary (keys (omit $global "default")) list) -}}
  {{- $local := (($ctx.Values.configuration).ldap | default dict) -}}
  {{- $local = (kindIs "map" $local | ternary (keys (omit $local "default")) list) -}}
  {{- dict "result" (concat $local $global | sortAlpha | uniq) | toYaml -}}
{{- end -}}

{{- define "arkcase.ldap" -}}
  {{- /* First, fetch the whole LDAP configuration */ -}}
  {{- $params := merge (pick $ "ctx" "debug") (dict "detailed" true "value" "ldap") -}}
  {{- $ldap := (include "arkcase.tools.conf" $params | fromYaml) -}}
  {{- if and $ldap (kindIs "map" $ldap.value) $ldap.value -}}
    {{- $ldap = $ldap.value -}}
  {{- else -}}
    {{- fail "The LDAP configuration is incorrect - cannot continue." -}}
  {{- end -}}

  {{- /* Next, identify which server we're supposed to narrow the search down to */ -}}
  {{- $serverNames := (include "arkcase.ldap.serverNames" $.ctx | fromYaml) -}}
  {{- $server := (hasKey $ "server" | ternary $.server "") -}}
  {{- $server = (kindIs "string" $server | ternary $server "") -}}

  {{- /* Special case: if the server name "default" is used, treat as if no server name given */ -}}
  {{- $server = (ne "default" $server) | ternary $server "" -}}

  {{- if not $server -}}
    {{- /* No server specified, pick the default */ -}}
    {{- $default := (include "arkcase.tools.conf" (dict "ctx" $.ctx "debug" $.debug "detailed" true "value" "ldap.default") | fromYaml) -}}
    {{- if and $default (kindIs "string" $default.value) $default.value -}}
      {{- $server = $default.value -}}
    {{- else -}}
      {{- if (eq 1 (len $serverNames.result)) -}}
        {{- /* We only have one server definition, use that */ -}}
        {{- $server = (first $serverNames.result) -}}
      {{- else -}}
        {{- /* We have more than one server definition, no default set, and we were not given a server name to use ... this is a problem */ -}}
        {{- fail "Configuration error - the 'ldap.default' entry must be a non-empty string" -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}

  {{- /* If we declared a server with the name "default", this is a no-no! */ -}}
  {{- if eq "default" $server -}}
    {{- fail "The LDAP server name 'default' is reserved and may not be used" -}}
  {{- end -}}

  {{- if not ($serverNames.result | has $server) -}}
    {{- fail (printf "The LDAP server name '%s' is invalid - must be one of %s" $server $serverNames.result) -}}
  {{- end -}}

  {{- /* We have the server name we want!! Now get the server configuration */ -}}
  {{- $prefix := (printf "ldap.%s" $server) -}}
  {{- $params = (merge (pick $ "ctx" "value" "debug") (dict "detailed" true "prefix" $prefix)) -}}
  {{- $value := "" -}}
  {{- $result := (include "arkcase.tools.conf" $params | fromYaml) -}}
  {{- if and $result $result.value -}}
    {{- $value = $result.value -}}
    {{- if or (kindIs "map" $value) (kindIs "slice" $value) -}}
      {{- $value = toYaml $value -}}
    {{- end -}}
  {{- end -}}
  {{- $value -}}
{{- end -}}

{{/*
Compute the LDAP dc=XXX,dc=XXX from a given domain name

usage: ( include "arkcase.ldap.dc" "some.domain.com" )
result: "DC=some,DC=domain,DC=com"
*/}}
{{- define "arkcase.ldap.dc" -}}
  {{- $parts := splitList "." (include "arkcase.tools.mustHostname" . | upper) | compact -}}
  {{- $dc := "" -}}
  {{- $sep := "" -}}
  {{- range $parts -}}
    {{- $dc = (printf "%s%sdc=%s" $dc $sep .) -}}
    {{- if (eq $sep "") -}}
      {{- $sep = "," -}}
    {{- end -}}
  {{- end -}}
  {{- $dc -}}
{{- end -}}

{{- define "arkcase.ldap.rootDn" -}}
  {{- $params := (include "arkcase.ldap.baseParam" $ | fromYaml) -}}

  {{- $rootDn := (include "arkcase.ldap" (set $params "value" "domain")) -}}
  {{- if or (not $rootDn) (not (kindIs "string" $rootDn)) -}}
    {{- fail "No LDAP domain is configured - cannot continue" -}}
  {{- end -}}
  {{- include "arkcase.ldap.dc" $rootDn | lower -}}
{{- end -}}

{{- define "arkcase.ldap.baseDn" -}}
  {{- $params := (include "arkcase.ldap.baseParam" $ | fromYaml) -}}

  {{- $rootDn := (include "arkcase.ldap.rootDn" $params) -}}
  {{- $baseDn := (include "arkcase.ldap" (set $params "value" "baseDn")) -}}
  {{- if and $baseDn (kindIs "string" $baseDn) -}}
    {{- $baseDn = (printf "%s,%s" $baseDn $rootDn) -}}
  {{- else -}}
    {{- $baseDn = $rootDn -}}
  {{- end -}}
  {{- $baseDn -}}
{{- end -}}

{{- define "arkcase.ldap.bindDn" -}}
  {{- $params := (include "arkcase.ldap.baseParam" $ | fromYaml) -}}
  {{- $baseDn := (include "arkcase.ldap.baseDn" $params) -}}
  {{- include "arkcase.ldap" (set $params "value" "bind.dn") | replace "${baseDn}" $baseDn -}}
{{- end -}}

{{- define "arkcase.ldap.realm" -}}
  {{- $params := (include "arkcase.ldap.baseParam" $ | fromYaml) -}}
  {{- $realm := (include "arkcase.ldap" (set $params "value" "domain")) -}}
  {{- if not $realm -}}
    {{- fail "No LDAP domain is configured - cannot continue" -}}
  {{- end -}}
  {{- $parts := splitList "." (include "arkcase.tools.mustHostname" $realm | upper) -}}
  {{- (index $parts 0) -}}
{{- end -}}
