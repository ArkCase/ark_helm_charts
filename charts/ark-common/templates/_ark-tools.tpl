{{- /*
Outputs "true" if the given parameter is a string that matches an IPv4 address (4 dot-separated octets between 0 and 255). If the string submitted is not an IPv4 address, the empty string will be output.

usage: ( include "arkcase.tools.checkIp" "some.ip.to.check" )
result: either "" or "true"
*/ -}}
{{- define "arkcase.tools.checkIp" -}}
  {{- $addx := (default "" .) -}}
  {{- $type := (kindOf $addx) -}}
  {{- if (not (eq "string" $type)) -}}
    {{- $addx = (toString $addx) -}}
  {{- end -}}
  {{- $fail := (eq 1 0) -}}
  {{- if and (not $fail) (eq (upper $addx) (lower $addx)) -}}
    {{- /* Second test: is it a set of 4 dot-separated numbers? */ -}}
    {{- $octets := splitList "." $addx }}
    {{- if eq ( $octets | len ) 4 }}
      {{- range $, $octet := $octets }}
        {{- if (not (regexMatch "^(0|[1-9][0-9]{0,2})$" $octet)) -}}
          {{- $fail = (eq 1 1) -}}
        {{- else -}}
          {{- $octet = (int $octet) -}}
          {{- if or (lt $octet 0) (gt $octet 255) -}}
            {{- $fail = (eq 1 1) -}}
          {{- end -}}
        {{- end -}}
      {{- end -}}
    {{- else -}}
      {{- $fail = (eq 1 1) -}}
    {{- end }}
  {{- else if (not $fail) -}}
    {{- $fail = (eq 1 1) -}}
  {{- end -}}
  {{- if not $fail -}}
    {{- true -}}
  {{- end -}}
{{- end -}}

{{- /*
Outputs "true" if the given parameter is a string that matches an RFC-1123 host or domain name. If the string submitted is not an RFC-1123 host or domain name, the empty string will be output.

usage: ( include "arkcase.tools.checkHostname" "some.hostname.to.check" )
result: either "" or "true"
*/ -}}
{{- define "arkcase.tools.checkHostname" -}}
  {{- $host := (default "" .) -}}
  {{- $type := (kindOf $host) -}}
  {{- if (not (eq "string" $type)) -}}
    {{- $host = (toString $host) -}}
  {{- end -}}
  {{- $fail := (eq 1 0) -}}
  {{- if not (regexMatch "^[a-z0-9]([-a-z0-9]*[a-z0-9])?([.][a-z0-9]([-a-z0-9]*[a-z0-9])?)*$" (lower $host)) -}}
    {{- $fail = (eq 1 1) -}}
  {{- end -}}
  {{- if not $fail -}}
    {{- true -}}
  {{- end -}}
{{- end -}}

{{- /*
Ensures that the given parameter is a string that matches an IPv4 address (4 dot-separated octets between 0 and 255), a list (slice) of IP addresses, or a comma-separated string of IP addresses. If any of the strings submitted is not an IP address, template processing will be halted. Will output the original parameter if it passes the checks. If the parameter is a list, the list will be sorted (alphabetically), uniqued, and compacted (empty strings removed).

usage: ( include "arkcase.tools.mustIp" "some.ip.to.check" )
       ( include "arkcase.tools.mustIp" (list "some.ip.to.check" "another.ip.to.check" ...) )
       ( include "arkcase.tools.mustIp" "some.ip.to.check,another.ip.to.check" )
*/ -}}
{{- define "arkcase.tools.mustIp" -}}
  {{- $param := (default list .) -}}
  {{- if not (include "arkcase.tools.isIp" $param) -}}
    {{- fail (printf "One of the values in %s is not an IPv4 address" $param) -}}
  {{- end -}}
  {{- $type := (kindOf $param) -}}
  {{- if eq "string" $type -}}
    {{- $param = (splitList "," $param) -}}
  {{- else if (eq "slice" $type) -}}
    {{- $param = (toStrings $param) -}}
  {{- end -}}
  {{- if (eq 1 (len $param)) -}}
    {{- range $param -}}
      {{- trim . -}}
    {{- end -}}
  {{- else -}}
    {{- (sortAlpha $param | uniq | compact) -}}
  {{- end -}}
{{- end -}}

{{- /*
Ensures that the given parameter is a string that matches a single IPv4 address. If the string is not an IPv4 address, template processing will be halted.

usage: ( include "arkcase.tools.mustSingleIp" "some.ip.to.check" )
*/ -}}
{{- define "arkcase.tools.mustSingleIp" -}}
  {{- $param := (toString (default "" .)) -}}
  {{- if not (include "arkcase.tools.checkIp" $param) -}}
    {{- fail (printf "The string [%s] is not an IPv4 address" $param) -}}
  {{- end -}}
  {{- trim . -}}
{{- end -}}

{{- /*
Outputs "true" if the given parameter is a string that matches a single IPv4 address. If the string is not an IPv4 address, the empty string will be output.

usage: ( include "arkcase.tools.isSingleIp" "some.ip.to.check" )
result: either "" or "true"
*/ -}}
{{- define "arkcase.tools.isSingleIp" -}}
  {{- include "arkcase.tools.checkIp" (toString (default "" .)) -}}
{{- end -}}

{{- /*
Outputs "true" if the given parameter is a string that matches an IPv4 address (4 dot-separated octets between 0 and 255), a list (slice) of IP addresses, or a comma-separated string of IP addresses. If any of the strings submitted is not an IP address, the empty string will be output.

usage: ( include "arkcase.tools.isIp" "some.ip.to.check" )
       ( include "arkcase.tools.isIp" (list "some.ip.to.check" "another.ip.to.check" ...) )
       ( include "arkcase.tools.isIp" "some.ip.to.check,another.ip.to.check" )
*/ -}}
{{- define "arkcase.tools.isIp" -}}
  {{- $allAddx := (default list .) -}}
  {{- $type := (kindOf $allAddx) -}}
  {{- if eq "string" $type -}}
    {{- $allAddx = (splitList "," $allAddx) -}}
  {{- else if (eq "slice" $type) -}}
    {{- $allAddx = (toStrings $allAddx) -}}
  {{- else -}}
    {{- fail (printf "The parameter must either be a string or a slice (%s)" $type) -}}
  {{- end -}}
  {{- $allAddx = (sortAlpha $allAddx | uniq | compact) -}}
  {{- $fail := (eq 1 0) -}}
  {{- range $allAddx -}}
    {{- if and (not $fail) (not (include "arkcase.tools.checkIp" .)) -}}
      {{- $fail = (eq 1 1) -}}
    {{- end -}}
  {{- end -}}
  {{- if not $fail -}}
    {{- true -}}
  {{- end -}}
{{- end -}}

{{- /*
Ensures that the given parameter is a string that matches an RFC-1123 host or domain name, a list (slice) of host or domain names, or a comma-separated string of host or domain names. If any of the strings submitted is not an RFC-1123 host or domain name, template processing will be halted.

usage: ( include "arkcase.tools.mustHostname" "some.hostname.to.check" )
       ( include "arkcase.tools.mustHostname" (list "some.hostname.to.check" "another.hostname.to.check" ...) )
       ( include "arkcase.tools.mustHostname" "some.hostname.to.check,another.hostname.to.check" )
*/ -}}
{{- define "arkcase.tools.mustHostname" -}}
  {{- $param := (default list .) -}}
  {{- if not (include "arkcase.tools.isHostname" $param) -}}
    {{- fail (printf "One of the values in %s is not an RFC-1123 host or domain name" $param) -}}
  {{- end -}}
  {{- $type := (kindOf $param) -}}
  {{- if eq "string" $type -}}
    {{- $param = (splitList "," $param) -}}
  {{- else if (eq "slice" $type) -}}
    {{- $param = (toStrings $param) -}}
  {{- end -}}
  {{- if (eq 1 (len $param)) -}}
    {{- range $param -}}
      {{- trim . -}}
    {{- end -}}
  {{- else -}}
    {{- (sortAlpha $param | uniq | compact) -}}
  {{- end -}}
{{- end -}}

{{- /*
Ensures that the given parameter is a string that matches a single RFC-1123 host or domain name. If the string is not an RFC-1123 host or domain name, template processing will be halted.

usage: ( include "arkcase.tools.mustSingleHostname" "some.hostname.to.check" )
*/ -}}
{{- define "arkcase.tools.mustSingleHostname" -}}
  {{- $param := (toString (default "" .)) -}}
  {{- if not (include "arkcase.tools.checkHostname" $param) -}}
    {{- fail (printf "The string [%s] is not an RFC-1123 host or domain name" $param) -}}
  {{- end -}}
  {{- trim . -}}
{{- end -}}

{{- /*
Outputs "true" if the given parameter is a string that matches a single RFC-1123 host or domain name. If the string is not an RFC-1123 host or domain name, the empty string will be output.

usage: ( include "arkcase.tools.isSingleHostname" "some.hostname.to.check" )
result: either "" or "true"
*/ -}}
{{- define "arkcase.tools.isSingleHostname" -}}
  {{- include "arkcase.tools.checkHostname" (toString (default "" .)) -}}
{{- end -}}

{{- /*
Outputs "true" if the given parameter is a string that matches an RFC-1123 host or domain name, a list (slice) of host or domain names, or a comma-separated string of host or domain names. If any of the strings submitted is not an RFC-1123 host or domain name, the empty string will be output.

usage: ( include "arkcase.tools.isHostname" "some.hostname.to.check" )
       ( include "arkcase.tools.isHostname" (list "some.hostname.to.check" "another.hostname.to.check" ...) )
       ( include "arkcase.tools.isHostname" "some.hostname.to.check,another.hostname.to.check" )
result: either "" or "true"
*/ -}}
{{- define "arkcase.tools.isHostname" -}}
  {{- $allHosts := (default list .) -}}
  {{- $type := (kindOf $allHosts) -}}
  {{- if eq "string" $type -}}
    {{- $allHosts = (splitList "," $allHosts) -}}
  {{- else if (eq "slice" $type) -}}
    {{- $allHosts = (toStrings $allHosts) -}}
  {{- else -}}
    {{- fail (printf "The parameter must either be a string or a slice (%s)" $type) -}}
  {{- end -}}
  {{- $allHosts = (sortAlpha $allHosts | uniq | compact) -}}
  {{- $fail := (eq 1 0) -}}
  {{- range $allHosts -}}
    {{- if (not $fail) -}}
      {{- /* if it's an IP address, or if it doesn't match the RFC-1123 hostname expression, it's not a hostname */ -}}
      {{- if or (include "arkcase.tools.checkIp" .) (not (include "arkcase.tools.checkHostname" .)) -}}
        {{- $fail = (eq 1 1) -}}
      {{- end }}
    {{- else -}}
      {{- $fail = (eq 1 1) -}}
    {{- end -}}
  {{- end -}}
  {{- if not $fail -}}
    {{- true -}}
  {{- end -}}
{{- end -}}

{{/*
Compute the Samba dc=XXX,dc=XXX from a given domain name

usage: ( include "arkcase.tools.samba.dc" "some.domain.com" )
result: "DC=some,DC=domain,DC=com"
*/}}
{{- define "arkcase.tools.samba.dc" -}}
  {{- $parts := splitList "." (include "arkcase.tools.mustHostname" . | upper) -}}
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

{{/*
Compute the Samba REALM name from a given domain name

usage: ( include "arkcase.tools.samba.realm" "some.domain.com" )
result: "SOME"
*/}}
{{- define "arkcase.tools.samba.realm" -}}
  {{- $parts := splitList "." (include "arkcase.tools.mustHostname" . | upper) -}}
  {{- (index $parts 0) -}}
{{- end -}}

{{- /*
Retrieve a mapped value in dot-separated notation, returning an empty string if the value isn't found, or any of the intermediate steps isn't found.  If the "required" parameter is set to "true", then a missing value will cause a fail() to be triggered indicating what portion(s) of the path could not be resolved. If the "check" parameter is set to "true", only the existence of the value will be checked for and "true" will be returned if it exists, with the empty string being returned if it does not (the "required" value will still be respected).

Parameter: a dict with two keys:
             - ctx = the root context (either "." or "$")
             - name = a string with the dot-separated name/path of the value to fetch
             - required (optional) = boolean to indicate whether a missing value should result in a fault
             - test (optional) = boolean to indicate whether we're only testing for the value's presence, or returning the value

usage: ( include "arkcase.tools.get" (dict "ctx" $ "name" "some.name.to.find" "required" "true|false" "check" "true|false") )
*/ -}}
{{- define "arkcase.tools.get" -}}
  {{- /* First things first - do we have a map to search within? */ -}}
  {{- if not (hasKey . "ctx") -}}
    {{- fail "Must provide the 'ctx' map to retrieve 'name' from" -}}
  {{- end -}}
  {{- $ctx := .ctx -}}
  {{- if not (kindIs "map" $ctx) -}}
    {{- fail "The 'ctx' parameter must be a map" -}}
  {{- end -}}

  {{- /* Next, make sure we have a value to seek out */ -}}
  {{- if not (hasKey . "name") -}}
    {{- fail "Must provide the 'name' to retrieve from the 'ctx' map" -}}
  {{- end -}}
  {{- $name := .name -}}
  {{- if not (kindIs "string" $name) -}}
    {{- fail "The 'name' parameter must be a string" -}}
  {{- end -}}

  {{- $origName := $name -}}
  {{- /* Remove consecutive dots */ -}}
  {{- $name = (regexReplaceAll "[.]+" $name ".") -}}
  {{- /* Remove leading and trailing dots */ -}}
  {{- $name = (regexReplaceAll "^[.]?(.*?)[.]?$" $name "${1}") -}}
  {{- if or (eq "." $name) (empty $name) -}}
    {{- fail (printf "The string [%s] is not allowed as the name to search for (resolves as [%s])" $origName $name) -}}
  {{- end -}}

  {{- $test := (and (hasKey . "test") (get . "test")) -}}

  {{- $currentMap := $ctx -}}
  {{- $currentKey := list -}}
  {{- $parts := (splitList "." $name) -}}
  {{- $failed := "" -}}
  {{- range $parts -}}
    {{- if not $failed -}}
      {{- if not (hasKey $currentMap .) -}}
        {{- $failed = (printf "Failed to find the name [%s] - got as far as [%s], which is a %s" $name ($currentKey | join ".") (kindOf $currentMap)) -}}
      {{- else -}}
        {{- $next := get $currentMap . -}}
        {{- if or (kindIs "map" $next) (eq (len $currentKey) (sub (len $parts) 1)) -}}
          {{- /* If this is the last element, then it's OK for it to not be a map */ -}}
          {{- $currentKey = (append $currentKey .) -}}
          {{- $currentMap = $next -}}
        {{- else -}}
          {{- $currentKey = (append $currentKey .) -}}
          {{- $failed = (printf "Failed to resolve the name [%s] - got as far as [%s], which is a %s" $name ($currentKey | join ".") (kindOf $next)) -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}

  {{- /* Collect the return value */ -}}
  {{- $value := $currentMap -}}
  {{- if $test -}}
    {{- $value = "true" -}}
  {{- end -}}
  {{- if $failed -}}
    {{- if (.required) -}}
      {{- fail $failed -}}
    {{- else -}}
      {{- $value = "" -}}
    {{- end -}}
  {{- else -}}
    {{- if not $test -}}
      {{- /* If the value is a scalar, then just spit it out, otherwise toYaml it for consumption on the other end */ -}}
      {{- $kind := (kindOf $value) -}}
      {{- if not (or (eq "string" $kind) (eq "bool" $kind) (eq "int" $kind) (eq "float64" $kind)) -}}
        {{- $value = ($value | toYaml | nindent 0) -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}

  {{- /* Output the return value */ -}}
  {{- $value -}}
{{- end -}}

{{- /*
Check for the existence of a mapped value in dot-separated notation, returning "true" if it exists, or an empty string otherwise.  This is identical to using "arkcase.tools.get" with "required=false" and "check=true"

Parameter: a dict with two keys:
             - ctx = the root context (either "." or "$")
             - name = a string with the dot-separated name/path of the value to fetch

usage: ( include "arkcase.tools.check" (dict "ctx" $ "name" "some.name.to.find") )
*/ -}}
{{- define "arkcase.tools.check" -}}
  {{- $crap := unset . "required" -}}
  {{- $crap = set . "test" "true" -}}
  {{- include "arkcase.tools.get" . -}}
{{- end -}}

{{- /*
Check to see if the "enabled" value is set to "true", or is not set (which causes it to default to "true")
*/ -}}
{{- define "arkcase.tools.enabled" -}}
  {{- if or .Values.enabled (not (hasKey .Values "enabled")) -}}
    {{- true -}}
  {{- end -}}
{{- end -}}

{{- /*
Create the environment variables to facilitate detecting the Pod's IP, name, namespace, and host IP
*/ -}}
{{- define "arkcase.tools.baseEnv" -}}
- name: POD_NAME
  valueFrom:
    fieldRef:
      fieldPath: metadata.name
- name: POD_NAMESPACE
  valueFrom:
    fieldRef:
      fieldPath: metadata.namespace
- name: POD_IP
  valueFrom:
    fieldRef:
      fieldPath: status.podIP
- name: POD_HOST_IP
  valueFrom:
    fieldRef:
      fieldPath: status.hostIP
{{- end -}}

{{- /*
Render the image name taking into account the registry, repository, image name, and tag.
*/ -}}
{{- define "arkcase.tools.image" -}}
  {{- $image := (required "No image information was found in the Values object" .Values.image) -}}
  {{- $global := (default dict .Values.global) -}}
  {{- $registryName := $image.registry -}}
  {{- $repositoryName := (required "No repository (image) name was given" $image.repository) -}}
  {{- $tag := (toString (default "latest" $image.tag)) -}}
  {{- if $global -}}
    {{- if $global.imageRegistry -}}
      {{- $registryName = $global.imageRegistry -}}
    {{- end -}}
  {{- end -}}
  {{- if $registryName -}}
    {{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
  {{- else -}}
    {{- printf "%s:%s" $repositoryName $tag -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.tools.imagePullPolicy" -}}
  {{- $image := (required "No image information was found in the Values object" .Values.image) -}}
  {{- $global := (default dict .Values.global) -}}
  {{- $tag := (toString (default "latest" $image.tag)) -}}
  {{- $pullPolicy := (toString (default "IfNotPresent" $image.pullPolicy)) -}}
  {{- if not (eq $pullPolicy "Never") -}}
    {{- if or (empty $tag) (eq $tag "latest") -}}
      {{- $pullPolicy = "Always" -}}
    {{- else -}}
      {{- $pullPolicy = "IfNotPresent" -}}
    {{- end -}}
  {{- end -}}
  {{- $pullPolicy -}}
{{- end -}}
