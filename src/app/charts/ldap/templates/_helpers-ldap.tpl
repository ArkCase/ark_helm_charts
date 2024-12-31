{{/*
Compute the LDAP dc=XXX,dc=XXX from a given domain name

usage: ( include "__arkcase.ldap.dc" "some.domain.com" )
result: "dc=some,dc=domain,dc=com"
*/}}
{{- define "__arkcase.ldap.dc" -}}
  {{- $parts := splitList "." (include "arkcase.tools.mustHostname" $ | lower) | compact -}}
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

{{- define "__arkcase.ldap.realm" -}}
  {{- splitList "." (include "arkcase.tools.mustHostname" $ | upper) | compact | first -}}
{{- end -}}

{{- define "__arkcase.ldap.settings.compute" -}}
  {{- $ctx := $ -}}

  {{- $defaultsFile := "server-defaults.yaml" -}}
  {{- $defaults := ($ctx.Files.Get $defaultsFile | fromYaml) -}}
  {{- if or (not $defaults) (not (kindIs "map" $defaults)) -}}
    {{- fail (printf "The file '%s' did not contain the required server default information" $defaultsFile) -}}
  {{- end -}}

  {{- $settings := (include "arkcase.subsystem.settings" $ctx | fromYaml) -}}

  {{- /* Ok ... merge the two! */ -}}
  {{- $result := dict -}}

  {{- /* This doesn't change */ -}}
  {{- $result = set $result "default" $defaults.default -}}

  {{- range $server := (keys (omit $defaults "default") | sortAlpha) -}}
    {{- $def := (get $defaults $server) -}}
    {{- if (not (kindIs "map" $def)) -}}
      {{- $def = dict -}}
    {{- end -}}
    {{- $set := (get $settings $server) -}}
    {{- if (not (kindIs "map" $set)) -}}
      {{- $set = dict -}}
    {{- end -}}

    {{- $final := dict -}}

    {{- /* Compute the domain */ -}}
    {{- $final = set $final "domain" (pluck "domain" $set $settings $def | compact | first | lower) -}}

    {{- /* Compute the realm based on the domain */ -}}
    {{- $final = set $final "realm" (pluck "realm" $set $settings | compact | first | default (include "__arkcase.ldap.realm" $final.domain)) -}}

    {{- /* Compute the rootDn from the domain unless it's expressly given */ -}}
    {{- $final = set $final "rootDn" (pluck "rootDn" $set $settings | compact | first | default (include "__arkcase.ldap.dc" $final.domain)) -}}

    {{- /* Continue to use this idiom moving forward */ -}}
    {{- $final = set $final "baseDn" (pluck "baseDn" $set $def | compact | first) -}}

    {{- range $obj := (list "user" "group") -}}
      {{- $defObj := (get $def $obj | default dict) -}}
      {{- if (not (kindIs "map" $defObj)) -}}
        {{- $defObj = dict -}}
      {{- end -}}
      {{- $setObj := (get $set $obj | default dict) -}}
      {{- if (not (kindIs "map" $setObj)) -}}
        {{- $setObj = dict -}}
      {{- end -}}

      {{- $finObj := dict -}}

      {{- $class := (pluck "class" $setObj $defObj | compact | first | default $obj) -}}
      {{- $finObj = set $finObj "class" $class -}}

      {{- range $k := (keys (omit $defObj "class") | sortAlpha) -}}
        {{- $v := (pluck $k $setObj $defObj | compact | first) -}}
        {{- if $v -}}
          {{- $v = $v | replace (printf "${%sClass}" $obj) $class -}}
        {{- end -}}
        {{- $finObj = set $finObj $k $v -}}
      {{- end -}}

      {{- $final = set $final $obj $finObj -}}
    {{- end -}}

    {{- $result = set $result $server $final -}}
  {{- end -}}

  {{- $result | toYaml -}}
{{- end -}}

{{- define "arkcase.ldap.settings" -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The parameter must be the root context ($ or .)" -}}
  {{- end -}} 
    
  {{- $args :=
    dict  
      "ctx" $ctx
      "template" "__arkcase.ldap.settings.compute"
  -}}
  {{- include "__arkcase.tools.getCachedValue" $args -}}
{{- end -}}

{{- define "arkcase.ldap.serverNames" -}}
  {{- $settings := (include "arkcase.ldap.settings" $ | fromYaml) -}}
  {{- dict "result" (keys (omit $settings "default") | sortAlpha) | toYaml -}}
{{- end -}}

{{- define "arkcase.ldap.domains" -}}
  {{- $settings := (include "arkcase.ldap.settings" $ | fromYaml) -}}
  {{- $result := dict -}}
  {{- range $server, $data := (omit $settings "default") -}}
    {{- $result = set $result $server $data.domain -}}
  {{- end -}}
  {{- $result | toYaml -}}
{{- end -}}

{{- define "arkcase.ldap" -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- $ctx = $.ctx -}}
    {{- if not (include "arkcase.isRootContext" $ctx) -}}
      {{- fail "The must provide the root context (. or $) as either the only parameter, or the 'ctx' parameter" -}}
    {{- end -}}
  {{- end -}}
  {{- $settings := (include "arkcase.ldap.settings" $ctx | fromYaml) -}}
  {{- $server := ((hasKey $ "server") | ternary $.server $settings.default) -}}
  {{- if not $server -}}
    {{- fail "The LDAP server name must be a non-empty string" -}}
  {{- end -}}
  {{- if (eq $server "default") -}}
    {{- $server = $settings.default -}}
  {{- end -}}

  {{- if (not (hasKey $settings $server)) -}}
    {{- fail (printf "The LDAP server configuration '%s' could not be found" $server) -}}
  {{- end -}}

  {{- $result := get $settings $server -}}
  {{- if not (kindIs "map" $result) -}}
    {{- $result = dict -}}
  {{- end -}}

  {{- $settings = (include "arkcase.subsystem.settings" $ctx | fromYaml) -}}

  {{- $result | toYaml -}}
{{- end -}}

{{- define "arkcase.ldap.flat" -}}
  {{- $ctx := ((hasKey $ "ctx") | ternary $.ctx $) -}}
  {{- $server := ((hasKey $ "server") | ternary $.server "" | toString | default "arkcase") -}}
  {{- $result := dict -}}
  {{- range $k, $v := (include "arkcase.ldap" (dict "ctx" $ctx "server" $server) | fromYaml) -}}
    {{- if (kindIs "map" $v) -}}
      {{- range $subK, $subV := $v -}}
        {{- $result = set $result (printf "%s%s" $k (title $subK)) ($subV | default "" | toString) -}}
      {{- end -}}
    {{- else if (kindIs "slice" $v) -}}
      {{- $result = set $result $k $v -}}
    {{- else -}}
      {{- $result = set $result $k ($v | default "" | toString) -}}
    {{- end -}}
  {{- end -}}
  {{- $result | toYaml -}}
{{- end -}}