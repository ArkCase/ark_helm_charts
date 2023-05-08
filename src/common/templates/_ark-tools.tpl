{{/* vim: set filetype=mustache: */}}

{{- define "arkcase.toBoolean" -}}
  {{- $v := (. | toString | lower) -}}
  {{- if eq "true" $v -}}
    {{- true -}}
  {{- end -}}
{{- end -}}

{{- /* Output the full name, optionally supporting a subcomponent name for charts with mutliple components */ -}}
{{- define "arkcase.fullname" -}}
  {{- $partname := (include "arkcase.part.name" .) -}}
  {{- $ctx := . -}}

  {{- if (hasKey $ctx "ctx") -}}
    {{- $ctx = .ctx -}}
  {{- end -}}

  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "Incorrect context given - either submit the root context as the only parameter, or a 'ctx' parameter pointing to it" -}}
  {{- end -}}

  {{- $fullname := (include "common.fullname" $ctx) -}}
  {{- if $partname -}}
    {{- $fullname = (printf "%s-%s" $fullname $partname) -}}
  {{- end -}}
  {{- $fullname | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- /* Output the short name, optionally supporting a subcomponent name for charts with mutliple components */ -}}
{{- define "arkcase.name" -}}
  {{- $partname := (include "arkcase.part.name" .) -}}
  {{- $ctx := . -}}

  {{- if (hasKey $ctx "ctx") -}}
    {{- $ctx = .ctx -}}
  {{- end -}}

  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "Incorrect context given - either submit the root context as the only parameter, or a 'ctx' parameter pointing to it" -}}
  {{- end -}}

  {{- $name := (include "common.name" $ctx) -}}
  {{- if $partname -}}
    {{- $name = (printf "%s-%s" $name $partname) -}}
  {{- end -}}
  {{- $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- /* Check to see if the given object is the top-level context map */ -}}
{{- define "arkcase.isRootContext" -}}
  {{- if and (kindIs "map" .) (hasKey . "Values") (hasKey . "Chart") (hasKey . "Release") (hasKey . "Files") (hasKey . "Capabilities") (hasKey . "Template") -}}
    {{- true -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.labels" -}}
  {{- $partname := (include "arkcase.part.name" .) -}}
  {{- $ctx := . -}}

  {{- if (hasKey $ctx "ctx") -}}
    {{- $ctx = .ctx -}}
  {{- end -}}

  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "Incorrect context given - either submit the root context as the only parameter, or a 'ctx' parameter pointing to it" -}}
  {{- end -}}

{{ include "arkcase.labels.standard" . }}
{{- if $ctx.Chart.AppVersion }}
app.kubernetes.io/version: {{ $ctx.Chart.AppVersion | quote }}
{{- end }}
app: {{ $ctx.Chart.Name | quote }}
version: {{ $ctx.Chart.AppVersion | quote }}
{{- end -}}

{{- define "arkcase.selectorLabels" -}}
  {{- include "arkcase.labels.matchLabels" . -}}
{{- end }}

{{/*
Kubernetes standard labels
*/}}
{{- define "arkcase.labels.standard" -}}
  {{- $partname := (include "arkcase.part.name" .) -}}
  {{- $ctx := . -}}

  {{- if (hasKey $ctx "ctx") -}}
    {{- $ctx = .ctx -}}
  {{- end -}}

  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "Incorrect context given - either submit the root context as the only parameter, or a 'ctx' parameter pointing to it" -}}
  {{- end -}}

{{ include "arkcase.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ $ctx.Release.Service }}
helm.sh/chart: {{ include "common.names.chart" $ctx }}
{{- end -}}

{{/*
Labels to use on deploy.spec.selector.matchLabels and svc.spec.selector
*/}}
{{- define "arkcase.labels.matchLabels" -}}
  {{- $partname := (include "arkcase.part.name" .) -}}
  {{- $ctx := . -}}

  {{- if (hasKey $ctx "ctx") -}}
    {{- $ctx = .ctx -}}
  {{- end -}}

  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "Incorrect context given - either submit the root context as the only parameter, or a 'ctx' parameter pointing to it" -}}
  {{- end -}}

app.kubernetes.io/instance: {{ $ctx.Release.Name }}
app.kubernetes.io/name: {{ include "common.names.name" $ctx }}
  {{- if $partname }}
app.kubernetes.io/part: {{ $partname }}
  {{- end }}
{{- end -}}

{{- define "arkcase.tools.normalizePath" -}}
  {{- $path := . -}}
  {{- if not (kindIs "string" $path) -}}
    {{- fail (printf "The parameter must be a string value (%s = %s)" (kindOf $path) ($path | toString)) -}}
  {{- end -}}
  {{- $stack := list -}}
  {{- range $e := (splitList "/" $path | compact) -}}
    {{- if (eq "." $e) -}}
      {{- /* Do nothing ... this path component can be ignored */ -}}
    {{- else if eq ".." $e -}}
      {{- if not $stack -}}
        {{- fail (printf "The path string [%s] contains too many '..' components" $path) -}}
      {{- end -}}
      {{- $stack = rest $stack -}}
    {{- else -}}
      {{- $stack = prepend $stack $e -}}
    {{- end -}}
  {{- end -}}
  {{- if isAbs $path -}}
    {{- /* This will cause the leading slash to be added */ -}}
    {{- if $stack -}}
      {{- $stack = append $stack "" -}}
    {{- else -}}
      {{- $stack = list "" "" -}}
    {{- end -}}
  {{- end -}}
  {{- reverse $stack | join "/" -}}
{{- end -}}

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
  {{- $fail := false -}}
  {{- if and (not $fail) (eq (upper $addx) (lower $addx)) -}}
    {{- /* Second test: is it a set of 4 dot-separated numbers? */ -}}
    {{- $octets := splitList "." $addx }}
    {{- if eq ( $octets | len ) 4 }}
      {{- range $, $octet := $octets }}
        {{- if (not (regexMatch "^(0|[1-9][0-9]{0,2})$" $octet)) -}}
          {{- $fail = true -}}
        {{- else -}}
          {{- $octet = (int $octet) -}}
          {{- if or (lt $octet 0) (gt $octet 255) -}}
            {{- $fail = true -}}
          {{- end -}}
        {{- end -}}
      {{- end -}}
    {{- else -}}
      {{- $fail = true -}}
    {{- end }}
  {{- else if (not $fail) -}}
    {{- $fail = true -}}
  {{- end -}}
  {{- if not $fail -}}
    {{- true -}}
  {{- end -}}
{{- end -}}

{{- /*
Outputs "true" if the given parameter is a hostname part that matches an RFC-1123. If the string submitted is not an RFC-1123 hostname part, nothing will be output.

usage: ( include "arkcase.tools.hostnamePart" "some-hostname-part-to-check" )
result: either "" or the value
*/ -}}
{{- define "arkcase.tools.hostnamePart" -}}
  {{- $part := (default "" .) -}}
  {{- if not (kindIs "string" $part) -}}
    {{- $part = (toString $part) -}}
  {{- end -}}
  {{- if (regexMatch "^([a-z0-9][-a-z0-9]*)?[a-z0-9]$" (lower $part)) -}}
    {{- $part -}}
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
  {{- $fail := false -}}
  {{- if not (regexMatch "^([a-z0-9][-a-z0-9]*)?[a-z0-9]([.]([a-z0-9][-a-z0-9]*)?[a-z0-9])*$" (lower $host)) -}}
    {{- $fail = true -}}
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
  {{- $fail := false -}}
  {{- range $allAddx -}}
    {{- if and (not $fail) (not (include "arkcase.tools.checkIp" .)) -}}
      {{- $fail = true -}}
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
  {{- $fail := false -}}
  {{- range $allHosts -}}
    {{- if (not $fail) -}}
      {{- /* if it's an IP address, or if it doesn't match the RFC-1123 hostname expression, it's not a hostname */ -}}
      {{- if or (include "arkcase.tools.checkIp" .) (not (include "arkcase.tools.checkHostname" .)) -}}
        {{- $fail = true -}}
      {{- end }}
    {{- else -}}
      {{- $fail = true -}}
    {{- end -}}
  {{- end -}}
  {{- if not $fail -}}
    {{- true -}}
  {{- end -}}
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
  {{- $name = (include "arkcase.tools.normalizeDots" $name) -}}
  {{- if or (eq "." $name) (not $name) -}}
    {{- fail (printf "The string [%s] is not allowed as the name to search for (resolves as [%s])" $origName $name) -}}
  {{- end -}}

  {{- $test := (and (hasKey . "test") (eq "true" (.test | toString | trim | lower))) -}}
  {{- $yaml := (and (hasKey . "yaml") (eq "true" (.yaml | toString | trim | lower))) -}}

  {{- $current := $ctx -}}
  {{- $currentKey := list -}}
  {{- $parts := (splitList "." $name) -}}
  {{- $failed := "" -}}
  {{- range $parts -}}
    {{- if not $failed -}}
      {{- if not (hasKey $current .) -}}
        {{- $failed = (printf "Failed to find the name [%s] - got as far as [%s], which is a %s" $name ($currentKey | join ".") (kindOf $current)) -}}
      {{- else -}}
        {{- $next := get $current . -}}
        {{- if or (kindIs "map" $next) (eq (len $currentKey) (sub (len $parts) 1)) -}}
          {{- /* If this is the last element, then it's OK for it to not be a map */ -}}
          {{- $currentKey = (append $currentKey .) -}}
          {{- $current = $next -}}
        {{- else -}}
          {{- $currentKey = (append $currentKey .) -}}
          {{- $failed = (printf "Failed to resolve the name [%s] - got as far as [%s], which is a %s" $name ($currentKey | join ".") (kindOf $next)) -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}

  {{- /* Collect the return value */ -}}
  {{- $value := ($test | ternary true $current) -}}
  {{- if $failed -}}
    {{- if (.required) -}}
      {{- fail $failed -}}
    {{- end -}}
    {{- $value = "" -}}
  {{- end -}}

  {{- /* Output the return value */ -}}
  {{- if $yaml -}}
    {{- /* If we've been asked to return the value as YAML, we only encode it */ -}}
    {{- /* as YAML if it's a structure. Otherwise, we output it verbatim */ -}}
    {{- $kind := kindOf $value -}}
    {{- if or (eq $kind "slice") (eq $kind "map") -}}
      {{- $value = $value | toYaml -}}
    {{- end -}}
  {{- else -}}
    {{- /* If we don't want to encode the value directly, we wrap it in a map */ -}}
    {{- /* and encode it all as YAML so it can be decoded using fromYaml */ -}}
    {{- $value = dict "value" $value "type" (kindOf $value) "name" .name "search" (join "." $currentKey) | toYaml -}}
  {{- end -}}
  {{- $value -}}
{{- end -}}

{{- /*
Check for the existence of a mapped value in dot-separated notation, returning "true" if it exists, or an empty string otherwise.  This is identical to using "arkcase.tools.get" with "required=false" and "check=true"

Parameter: a dict with two keys:
             - ctx = the root context (either "." or "$")
             - name = a string with the dot-separated name/path of the value to fetch
             - test = a string with the dot-separated name/path of the value to fetch

usage: ( include "arkcase.tools.check" (dict "ctx" $ "name" "some.name.to.find") )
*/ -}}
{{- define "arkcase.tools.check" -}}
  {{- $result := (include "arkcase.tools.get" (set (omit . "required") "test" "true") | fromYaml) -}}
  {{- if $result.value -}}
    {{- true -}}
  {{- end -}}
{{- end -}}

{{- /*
Check if persistence is enabled, assuming a missing setting defaults to true
*/ -}}
{{- define "arkcase.tools.checkEnabledFlag" -}}
  {{- if (and (kindIs "map" .) (or (not (hasKey . "enabled")) (eq "true" (.enabled | toString | lower)))) -}}
    {{- true -}}
  {{- end -}}
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
Ensure that the given value is an integer value - even if in string form
*/ -}}
{{- define "arkcase.tools.mustInt" -}}
  {{- $value := . -}}
  {{- if kindIs "string" $value -}}
    {{- if not (regexMatch "^-?[1-9][0-9]*$" $value) -}}
      {{- fail (printf "The value [%s] is not a valid integer" $value) -}}
    {{- end -}}
    {{- $value = ($value | int64) -}}
  {{- else if or (kindIs "int" $value) (kindIs "int64" $value) (kindIs "float64" $value) -}}
    {{- $value = ($value | int64) -}}
  {{- else if $value -}}
    {{- fail (printf "The value [%s] is not a valid integer (%s)" $value) -}}
  {{- end -}}
  {{- $value -}}
{{- end -}}

{{- /*
Check that the given value is either a numeric port (1-65535) or a potentially valid port name (per /etc/services), and
return either the value if correct, or the empty string if not.
*/ -}}
{{- define "arkcase.tools.checkPort" -}}
  {{- $value := . -}}
  {{- $result := "" -}}
  {{- if kindIs "string" $value -}}
    {{- /* Check that it's not the empty string and it contains no spaces */ -}}
    {{- if regexMatch "^[^\\s]+$" $value -}}
      {{- /* Might be an /etc/services port, or a port number */ -}}
      {{- if regexMatch "^[0-9]+$" $value -}}
        {{- /* It's a "number" (but may have leading zeros, so check) */ -}}
        {{- if regexMatch "^[1-9][0-9]*$" $value -}}
          {{- /* It's a valid number! Check that it's a number between 1 and 65535 */ -}}
          {{- $value = ($value | int) -}}
          {{- if and (ge $value 1) (le $value 65535) -}}
            {{- $result = $value -}}
          {{- end -}}
        {{- end -}}
      {{- else -}}
        {{- /* Might be an /etc/services port */ -}}
        {{- $result = $value -}}
      {{- end -}}
    {{- end -}}
  {{- else if or (kindIs "int" $value) (kindIs "int64" $value) (kindIs "float64" $value) -}}
    {{- /* Check that it's a number between 1 and 65535 */ -}}
    {{- $value = ($value | int64) -}}
    {{- if and (ge $value 1) (le $value 65535) -}}
      {{- $result = $value -}}
    {{- end -}}
  {{- else -}}
    {{- /* Most definitely not a valid port specification */ -}}
  {{- end -}}
  {{- $result -}}
{{- end -}}

{{- define "arkcase.tools.conf.isGlobal" -}}
  {{- $var := . -}}
  {{- if and $var (not (kindIs "string" $var)) -}}
    {{- $var = (toString $var) -}}
  {{- else if not $var -}}
    {{- $var = "" -}}
  {{- end -}}
  {{- (hasPrefix "Values.global.conf." (include "arkcase.tools.normalizeDots" $var)) | ternary "true" "" -}}
{{- end -}}

{{- define "arkcase.tools.conf.isLocal" -}}
  {{- $var := . -}}
  {{- if and $var (not (kindIs "string" $var)) -}}
    {{- $var = (toString $var) -}}
  {{- else if not $var -}}
    {{- $var = "" -}}
  {{- end -}}
  {{- (hasPrefix "Values.configuration." (include "arkcase.tools.normalizeDots" $var)) | ternary "true" "" -}}
{{- end -}}

{{- define "arkcase.tools.conf" -}}
  {{- $ctx := .ctx -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The context given (either the parameter map, or the 'ctx' value within) is not the top-level context" -}}
  {{- end -}}
  {{- $debug := and (hasKey . "debug") .debug -}}

  {{- $value := .value -}}
  {{- if and $value (not (kindIs "string" $value)) -}}
    {{- fail (printf "The 'value' parameter must be a string, not a %s" (kindOf $value)) -}}
  {{- else if not $value -}}
    {{- $value = "" -}}
  {{- end -}}

  {{- $prefix := (.prefix | default "") -}}
  {{- if and $prefix (kindIs "string" $prefix) -}}
    {{- $prefix = (include "arkcase.tools.normalizeDots" $prefix | trimPrefix "." | trimSuffix ".") -}}
  {{- end -}}
  {{- if and $value $prefix -}}
    {{- $value = (printf "%s.%s" $prefix $value) -}}
  {{- else if $prefix -}}
    {{- $value = $prefix -}}
  {{- end -}}

  {{- $result := dict -}}
  {{- $searched := list -}}
  {{- range (list (printf "global.conf.%s" $ctx.Chart.Name) "global.conf" "configuration") -}}
    {{- if or (not $result) (not $result.value) -}}
      {{- $key := (empty $value) | ternary . (printf "%s.%s" . $value ) -}}
      {{- if $debug -}}
        {{- $searched = append $searched (printf "Values.%s" $key) -}}
      {{- end -}}
      {{- $result = (include "arkcase.tools.get" (dict "ctx" $ctx "name" (printf "Values.%s" $key)) | fromYaml) -}}
      {{- if and $result $result.value -}}
        {{- $result = set $result "global" (hasPrefix "global.conf" $key) -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
  {{- if $debug -}}
    {{- fail (dict "result" $result "searched" $searched "global" (dict "conf" (($ctx.Values.global).conf | default dict)) "configuration" ($ctx.Values.configuration | default dict) | toYaml | nindent 0) -}}
  {{- end -}}
  {{- if .detailed -}}
    {{- $result | toYaml -}}
  {{- else -}}
    {{- $v := $result.value -}}
    {{- if or (kindIs "map" $v) (kindIs "slice" $v) -}}
      {{- $v = (toYaml $v) -}}
    {{- end -}}
    {{- $v -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.tools.ldap" -}}
  {{- $params := merge (pick $ "ctx" "value" "debug") (dict "detailed" true "prefix" "ldap") -}}
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

usage: ( include "arkcase.tools.ldap.dc" "some.domain.com" )
result: "DC=some,DC=domain,DC=com"
*/}}
{{- define "arkcase.tools.ldap.dc" -}}
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

{{- define "arkcase.tools.normalizeDots" -}}
  {{- splitList "." $ | compact | join "." -}}
{{- end -}}

{{- define "arkcase.tools.ldap.baseDn" -}}
  {{- $baseDn := (include "arkcase.tools.ldap" (dict "ctx" . "value" "baseDn")) -}}
  {{- if not $baseDn -}}
    {{- $baseDn = (include "arkcase.tools.ldap" (dict "ctx" . "value" "domain")) -}}
    {{- if not $baseDn -}}
      {{- fail "No LDAP domain is configured - cannot continue" -}}
    {{- end -}}
    {{- $baseDn = (include "arkcase.tools.ldap.dc" $baseDn | lower) -}}
  {{- end -}}
  {{- $baseDn -}}
{{- end -}}

{{- define "arkcase.tools.ldap.bindDn" -}}
  {{- $baseDn := (include "arkcase.tools.ldap.baseDn" $) -}}
  {{- include "arkcase.tools.ldap" (dict "ctx" $ "value" "bind.dn") | replace "${baseDn}" $baseDn -}}
{{- end -}}

{{- define "arkcase.tools.ldap.realm" -}}
  {{- $realm := (include "arkcase.tools.ldap" (dict "ctx" . "value" "domain")) -}}
  {{- if not $realm -}}
    {{- fail "No LDAP domain is configured - cannot continue" -}}
  {{- end -}}
  {{- $parts := splitList "." (include "arkcase.tools.mustHostname" $realm | upper) -}}
  {{- (index $parts 0) -}}
{{- end -}}

{{- define "arkcase.tools.parseUrl" -}}
  {{- $url := . -}}
  {{- $data := urlParse $url -}}

  {{- if hasKey $data "host" -}}
    {{- /* Host may be of the form (host)?(:port)? */ -}}
    {{- $hostInfo := split ":" $data.host -}}

    {{- /* Purify the host information */ -}}
    {{- $host := "" -}}
    {{- if $hostInfo._0 -}}
      {{- $host = $hostInfo._0 -}}
    {{- end -}}
    {{- $data = set $data "host" $host -}}

    {{- /* Purify the port information */ -}}
    {{- $port := 0 -}}
    {{- if $hostInfo._1 -}}
      {{- $port = ($hostInfo._1 | int) -}}
    {{- else if eq "https" $data.scheme -}}
      {{- $port = 443 -}}
    {{- else if eq "http" $data.scheme -}}
      {{- $port := 80 -}}
    {{- else if eq "ldaps" $data.scheme -}}
      {{- $port = 636 -}}
    {{- else if eq "ldap" $data.scheme -}}
      {{- $port := 389 -}}
    {{- else if eq "ftp" $data.scheme -}}
      {{- $port := 21 -}}
    {{- else if eq "ftps" $data.scheme -}}
      {{- $port := 990 -}}
    {{- else if eq "sftp" $data.scheme -}}
      {{- $port := 22 -}}
    {{- end -}}
    {{- $data = set $data "port" $port -}}
  {{- end -}}

  {{- if hasKey $data "path" -}}
    {{- /* Pick out the context */ -}}
    {{- $path := list -}}
    {{- range $p := (splitList "/" $data.path) -}}
      {{- if $p -}}
        {{- $path = append $path $p -}}
      {{- end -}}
    {{- end -}}
    {{- $context := "" -}}
    {{- if gt (len $path) 0 -}}
      {{- $context = (first $path) -}}
    {{- end -}}
    {{- $data = set $data "context" $context -}}
    {{- $data = set $data "pathElements" $path -}}
  {{- end -}}

  {{- if hasKey $data "query" -}}
    {{- /* Pick out the query parameters */ -}}
    {{- $data = set $data "parameters" (splitList "&" $data.query) -}}
  {{- else -}}
    {{- $data = set $data "parameters" list -}}
  {{- end -}}

  {{- $data = set $data "url" $url -}}

  {{- /* Return the nice result */ -}}
  {{- $data | toYaml -}}
{{- end -}}

{{- define "arkcase.dev.compute" -}}
  {{- $ctx := . -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The parameter must be the root context (. or $)" -}}
  {{- end -}}

  {{- /* Get the global map, if defined */ -}}
  {{- $global := $ctx.Values.global | default dict -}}
  {{- if not (kindIs "map" $global) -}}
    {{- $global = dict -}}
  {{- end -}}

  {{- $result := dict -}}
  {{- if and $global.dev (kindIs "map" $global.dev) -}}
    {{- $dev := $global.dev -}}
    {{- $enabled := (or (not (hasKey $dev "enabled")) (not (empty (include "arkcase.toBoolean" $dev.enabled)))) -}}
    {{- if $enabled -}}
      {{- $result = set $result "enabled" $enabled -}}
      {{- if and $dev.war (kindIs "string" $dev.war) -}}
        {{- $war := $dev.war | toString -}}
        {{- $file := (hasPrefix "file://" $war) -}}
        {{- if or (hasPrefix "path://" $war) (hasPrefix "file://" $war) -}}
          {{- $war = (include "arkcase.tools.parseUrl" $war | fromYaml) -}}
          {{- $path := $war.path -}}
          {{- if not $path -}}
            {{- fail (printf "The value for global.dev.war must contain a path: [%s]" $war) -}}
          {{- end -}}
          {{- $war = $path -}}
        {{- end -}}
        {{- $result = set $result "war" (dict "file" $file "path" (include "arkcase.tools.normalizePath" $war)) -}}
      {{- else if $dev.war -}}
        {{- fail (printf "The value for global.dev.war must be a string (%s)" (kindOf $dev.war)) -}}
      {{- end -}}

      {{- if and $dev.conf (kindIs "string" $dev.conf) -}}
        {{- $conf := $dev.conf | toString -}}
        {{- $file := (hasPrefix "file://" $conf) -}}
        {{- if or (hasPrefix "path://" $conf) (hasPrefix "file://" $conf) -}}
          {{- $conf = (include "arkcase.tools.parseUrl" $conf | fromYaml) -}}
          {{- $path := $conf.path -}}
          {{- if not $path -}}
            {{- fail (printf "The value for global.dev.conf must contain a path: [%s]" $conf) -}}
          {{- end -}}
          {{- $conf = $path -}}
        {{- end -}}
        {{- $result = set $result "conf" (dict "file" $file "path" (include "arkcase.tools.normalizePath" $conf)) -}}
      {{- else if $dev.conf -}}
        {{- fail (printf "The value for global.dev.conf must be a string (%s)" (kindOf $dev.conf)) -}}
      {{- end -}}

      {{- $debug := $dev.debug -}}
      {{- if and $debug (kindIs "map" $debug) -}}
        {{- $enabled := or (not (hasKey $debug "enabled")) (not (empty (include "arkcase.toBoolean" $debug.enabled))) -}}
        {{- if $enabled -}}
          {{- $jdb := 0 -}}
          {{- if hasKey $debug "port" -}}
            {{- $jdb = ($debug.port | default "0" | toString | atoi) -}}
            {{- if or (lt $jdb 0) (gt $jdb 65535) -}}
              {{- fail (printf "The debug port number [%s] is not valid" ($debug.port | toString)) -}}
            {{- end -}}
          {{- else -}}
            {{- $jdb = 8888 -}}
          {{- end -}}
          {{- $suspend := and (hasKey $debug "suspend") (not (empty (include "arkcase.toBoolean" $debug.suspend))) | ternary "y" "n" -}}
          {{- $flags := dict -}}
          {{- range $k, $v := (omit $debug "port" "suspend" "enabled") -}}
            {{- $flags = set $flags $k (not (empty (include "arkcase.toBoolean" $v))) -}}
          {{- end -}}
          {{- $debug = dict "enabled" $enabled "jdb" $jdb "suspend" $suspend "flags" $flags -}}
        {{- else -}}
          {{- $debug = dict -}}
        {{- end -}}
      {{- else -}}
        {{- $debug = dict -}}
      {{- end -}}
      {{- $result = set $result "debug" $debug -}}
    {{- end -}}
  {{- end -}}
  {{- $result | toYaml -}}
{{- end -}}

{{- define "arkcase.dev" -}}
  {{- $ctx := . -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The parameter must be the root context (. or $)" -}}
  {{- end -}}

  {{- $cacheKey := "DevelopmentMode" -}}
  {{- $masterCache := dict -}}
  {{- $result := dict -}}
  {{- if (hasKey $ctx $cacheKey) -}}
    {{- $result = (get $ctx $cacheKey | toYaml) -}}
  {{- else -}}
    {{- $result = (include "arkcase.dev.compute" $ctx) -}}
    {{- $ctx = set $ctx $cacheKey ($result | fromYaml) -}}
  {{- end -}}
  {{- $result -}}
{{- end -}}

{{- /* Get the mode of operation value that should be used for everything */ -}}
{{- define "arkcase.deployment.mode" -}}
  {{- $ctx := . -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The parameter must be the root context (. or $)" -}}
  {{- end -}}

  {{- /* For now, default to production mode */ -}}
  {{- $value := "production" -}}
  {{- $valueSet := false -}}

  {{- /* Get the global map, if defined */ -}}
  {{- $global := $ctx.Values.global | default dict -}}
  {{- if not (kindIs "map" $global) -}}
    {{- $global = dict -}}
  {{- end -}}

  {{- if $global -}}
    {{- /* Get the explicitly set value, if any */ -}}
    {{- if and (hasKey $global "mode") $global.mode -}}
      {{- $m := ($global.mode | toString | trim | lower) -}}
      {{- $valueSet = true -}}
      {{- if or (eq $m "development") (eq $m "develop") (eq $m "devel") (eq $m "dev") -}}
        {{- $value = "development" -}}
      {{- else if or (eq $m "production") (eq $m "prod") -}}
        {{- $value = "production" -}}
      {{- else -}}
        {{- fail (printf "Unknown deployment mode [%s] (.Values.global.mode) - must be either 'development' (or 'develop', or 'devel' or 'dev') or 'production' (or 'prod')" $m) -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}

  {{- /* If the value isn't explicitly set, which would take priority, we then */ -}}
  {{- /* check to see if the development settings are enabled. If they are, then */ -}}
  {{- /* we treat this as the value being explicitly set. */ -}}
  {{- if not $valueSet -}}
    {{- $valueSet = (not (empty (include "arkcase.dev" $ctx | fromYaml))) -}}
    {{- if $valueSet -}}
      {{- $value = "development" -}}
    {{- end -}}
  {{- end -}}

  {{- dict "value" $value "set" $valueSet | toYaml -}}
{{- end -}}

{{- define "arkcase.enterprise.compute" -}}
  {{- $ctx := . -}}

  {{- /* For now, default to the community edition */ -}}
  {{- $enterprise := false -}}

  {{- $global := ($ctx.Values.global | default dict) -}}
  {{- $globalSet := hasKey $global "enterprise" -}}

  {{- if $globalSet -}}
    {{- $enterprise = $global.enterprise -}}
  {{- else -}}
    {{- /* The value is not explicitly set, so try to deduce it */ -}}
    {{- if and $ctx.Values.licenses $global.licenses -}}
      {{- $licenseNames := $ctx.Values.licenses -}}
      {{- $licenseValues := ($global.licenses | default dict) -}}
      {{- if not (kindIs "map" $licenseValues) -}}
        {{- $licenseValues = dict -}}
      {{- end -}}
      {{- if (kindIs "string" $licenseNames) -}}
        {{- $licenseNames = (splitList "," $licenseNames | compact) -}}
      {{- else if (kindIs "map" $licenseNames) -}}
        {{- $licenseNames = (keys $licenseNames | sortAlpha) -}}
      {{- end -}}
      {{- range $l := $licenseNames -}}
        {{- if not $enterprise -}}
          {{- $l = ($l | toString) -}}
          {{- if and $l (hasKey $licenseValues $l) (get $licenseValues $l) -}}
            {{- $enterprise = true -}}
          {{- end -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}

  {{- /* Sanitize to a boolean value */ -}}
  {{- $enterprise = (kindIs "bool" $enterprise) | ternary $enterprise (eq "true" ($enterprise | toString | lower)) -}}

  {{- /* Output the result */ -}}
  {{- $enterprise | ternary "true" "" -}}
{{- end -}}

{{- define "arkcase.enterprise" -}}
  {{- $ctx := . -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The parameter must be the root context (. or $)" -}}
  {{- end -}}

  {{- $cacheKey := "EnterpriseMode" -}}
  {{- $masterCache := dict -}}
  {{- if (hasKey $ctx $cacheKey) -}}
    {{- $masterCache = get $ctx $cacheKey -}}
    {{- if and $masterCache (not (kindIs "map" $masterCache)) -}}
      {{- $masterCache = dict -}}
    {{- end -}}
  {{- end -}}
  {{- $ctx = set $ctx $cacheKey $masterCache -}}

  {{- $cacheKey = (include "common.fullname" $ctx) -}}
  {{- $result := "" -}}
  {{- if not (hasKey $masterCache $cacheKey) -}}
    {{- $result = (include "arkcase.enterprise.compute" $ctx) -}}
    {{- $masterCache = set $masterCache $cacheKey $result -}}
  {{- else -}}
    {{- $result = get $masterCache $cacheKey -}}
  {{- end -}}
  {{- $result -}}
{{- end -}}

{{ define "arkcase.tools.xmlAtt" -}}
{{- . -}}
{{- end -}}
