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

{{- define "arkcase.labels.service" -}}
  {{- include "arkcase.labels.standard" . }}
app.kubernetes.io/service-support: "true"
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

  {{- include "arkcase.labels.standard" . }}
  {{- if $ctx.Chart.AppVersion }}
app.kubernetes.io/version: {{ $ctx.Chart.AppVersion | quote }}
  {{- end }}
app: {{ $ctx.Chart.Name | quote }}
version: {{ $ctx.Chart.AppVersion | quote }}
{{- end -}}

{{- define "arkcase.selectorLabels" -}}
  {{- include "arkcase.labels.matchLabels" . -}}
{{- end -}}

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

  {{- include "arkcase.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ $ctx.Release.Service | quote }}
helm.sh/chart: {{ include "common.names.chart" $ctx | quote }}
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

app.kubernetes.io/instance: {{ $ctx.Release.Name | quote }}
app.kubernetes.io/name: {{ include "common.names.name" $ctx | quote }}
  {{- if $partname }}
app.kubernetes.io/part: {{ $partname | quote }}
  {{- end }}
{{- end -}}

{{- define "arkcase.labels.matchLabels.service" -}}
  {{- include "arkcase.labels.matchLabels" . }}
app.kubernetes.io/service-support: "true"
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

{{- define "arkcase.tools.validEmail" -}}
  {{- $value := . -}}
  {{- $result := "" -}}
  {{- /* Make sure it's a non-empty string */ -}}
  {{- if and $value (kindIs "string" $value) -}}
    {{- /* Make sure it's made up of two parts split by an ampersand (i.e. user@domain) */ -}}
    {{- $parts := ($value | splitList "@") -}}
    {{- if (eq 2 (len $parts)) -}}
      {{- /* Validate the hostname */ -}}
      {{- if (include "arkcase.tools.isSingleHostname" (last $parts)) -}}
        {{- /* Validate the username */ -}}
        {{- if regexMatch "^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+$" (first $parts) -}}
          {{- $result = $value -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
  {{- end }}
  {{- $result -}}
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

{{- define "arkcase.tools.singleHostname" -}}
  {{- $param := (toString (default "" .)) -}}
  {{- if (include "arkcase.tools.isSingleHostname" $param) -}}
    {{- trim $param -}}
  {{- end -}}
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

  {{- $found := false -}}
  {{- $current := $ctx -}}
  {{- $currentKey := list -}}
  {{- $parts := (splitList "." $name) -}}
  {{- $failed := "" -}}
  {{- range $parts -}}
    {{- $found = false -}}
    {{- if not $failed -}}
      {{- if not (hasKey $current .) -}}
        {{- $failed = (printf "Failed to find the name [%s] - got as far as [%s], which is a %s" $name ($currentKey | join ".") (kindOf $current)) -}}
      {{- else -}}
        {{- $next := get $current . -}}
        {{- if or (kindIs "map" $next) (eq (len $currentKey) (sub (len $parts) 1)) -}}
          {{- /* If this is the last element, then it's OK for it to not be a map */ -}}
          {{- $currentKey = (append $currentKey .) -}}
          {{- $current = $next -}}
          {{- $found = true -}}
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
    {{- $found = false -}}
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
    {{- $value = dict "value" $value "found" $found "type" (kindOf $value) "name" .name "search" (join "." $currentKey) | toYaml -}}
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

{{- define "arkcase.tools.checkNumericPort" -}}
  {{- $value := . -}}
  {{- if kindIs "string" $value -}}
    {{- $value = (regexMatch "^[1-9][0-9]*$" $value) | ternary ($value | atoi | int64) 0 -}}
  {{- else if or (kindIs "int" $value) (kindIs "int64" $value) (kindIs "float64" $value) -}}
    {{- $value = ($value | int64) -}}
  {{- else -}}
    {{- $value = -1 -}}
  {{- end -}}
  {{- (and (ge $value 1) (le $value 65535)) | ternary $value "" -}}
{{- end -}}

{{- /*
Check that the given value is either a numeric port (1-65535) or a potentially valid port name (per /etc/services), and
return either the value if correct, or the empty string if not.
*/ -}}
{{- define "arkcase.tools.checkPort" -}}
  {{- $value := . -}}
  {{- $numeric := (include "arkcase.tools.checkNumericPort" $value) -}}
  {{- $result := "" -}}
  {{- if $numeric -}}
    {{- $result = $numeric -}}
  {{- else if and (kindIs "string" $value) (regexMatch "^[^\\s]+$" $value) -}}
    {{- /* Might be an /etc/services port */ -}}
    {{- $result = $value -}}
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

{{- define "arkcase.tools.global" -}}
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

  {{- $result := (include "arkcase.tools.get" (dict "ctx" $ctx "name" (printf "Values.global.%s" $value)) | fromYaml) -}}
  {{- if $debug -}}
    {{- fail (dict "result" $result "global" (dict "conf" ($ctx.Values.global | default dict)) | toYaml | nindent 0) -}}
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
    {{- if not $result -}}
      {{- $key := (empty $value) | ternary . (printf "%s.%s" . $value ) -}}
      {{- if $debug -}}
        {{- $searched = append $searched (printf "Values.%s" $key) -}}
      {{- end -}}
      {{- $r := (include "arkcase.tools.get" (dict "ctx" $ctx "name" (printf "Values.%s" $key)) | fromYaml) -}}
      {{- if and $r $r.found -}}
        {{- $result = set $r "global" (hasPrefix "global.conf" $key) -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
  {{- range (list "found" "global") -}}
    {{- if not (hasKey $result .) -}}
      {{- $result = set $result . false -}}
    {{- end -}}
  {{- end -}}
  {{- if $debug -}}
    {{- fail (dict "result" $result "searched" $searched "global" (dict "conf" (($ctx.Values.global).conf | default dict)) "configuration" ($ctx.Values.configuration | default dict) | toYaml | nindent 0) -}}
  {{- end -}}
  {{- if .detailed -}}
    {{- $result | toYaml -}}
  {{- else if (hasKey $result "value") -}}
    {{- $v := $result.value -}}
    {{- if or (kindIs "map" $v) (kindIs "slice" $v) -}}
      {{- $v = (toYaml $v) -}}
    {{- end -}}
    {{- $v -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.tools.normalizeDots" -}}
  {{- splitList "." $ | compact | join "." -}}
{{- end -}}

{{- define "arkcase.tools.parseUrl" -}}
  {{- $url := . -}}
  {{- $data := urlParse $url -}}

  {{- if hasKey $data "host" -}}
    {{- /* Host may be of the form (host)?(:port)? */ -}}
    {{- $hostInfo := split ":" $data.host -}}

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
    {{- $data = set $data "hostPort" (printf "%s:%d" $data.hostname $data.port) -}}
  {{- end -}}

  {{- if hasKey $data "path" -}}
    {{- $normalized := (include "arkcase.tools.normalizePath" $data.path) -}}
    {{- $path := (splitList "/" $normalized | compact) -}}
    {{- $context := "" -}}
    {{- if $path -}}
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
      {{- $result = set $result "enabled" true -}}

      {{- /* Handle the custom WAR files */ -}}
      {{- if and $dev.wars (kindIs "map" $dev.wars) -}}
        {{- $wars := dict -}}
        {{- range $k, $v := $dev.wars -}}
          {{- $war := $v | toString -}}
          {{- $file := (hasPrefix "file:/" $war) -}}
          {{- if or (hasPrefix "path:/" $war) (hasPrefix "file:/" $war) -}}
            {{- $path := (regexReplaceAll "^(path|file):" $war "") -}}
            {{- if not $path -}}
              {{- fail (printf "The value for global.dev.wars.%s must contain a path: [%s]" $k $war) -}}
            {{- end -}}
            {{- $war = $path -}}
          {{- end -}}
          {{- $war = (include "arkcase.tools.normalizePath" $war) -}}
          {{- if not (isAbs $war) -}}
            {{- fail (printf "The value for global.dev.wars.%s must be an absolute path: [%s]" $k $war) -}}
          {{- end -}}
          {{- $wars = set $wars $k (dict "file" $file "path" $war) -}}
        {{- end -}}
        {{- $result = set $result "wars" $wars -}}
      {{- else if $dev.wars -}}
        {{- fail (printf "The value for global.dev.wars must be a map (%s)" (kindOf $dev.war)) -}}
      {{- end -}}

      {{- if and $dev.conf (kindIs "string" $dev.conf) -}}
        {{- $conf := $dev.conf | toString -}}
        {{- $file := (hasPrefix "file:/" $conf) -}}
        {{- if or (hasPrefix "path:/" $conf) (hasPrefix "file:/" $conf) -}}
          {{- $path := (regexReplaceAll "^(path|file):" $conf "") -}}
          {{- if not $path -}}
            {{- fail (printf "The value for global.dev.conf must contain a path: [%s]" $conf) -}}
          {{- end -}}
          {{- $conf = $path -}}
        {{- end -}}
        {{- $conf = (include "arkcase.tools.normalizePath" $conf) -}}
        {{- if not (isAbs $conf) -}}
          {{- fail (printf "The value for global.dev.conf must be an absolute path: [%s]" $conf) -}}
        {{- end -}}
        {{- $result = set $result "conf" (dict "file" $file "path" $conf) -}}
      {{- else if $dev.conf -}}
        {{- fail (printf "The value for global.dev.conf must be a string (%s)" (kindOf $dev.conf)) -}}
      {{- end -}}

      {{- $uid := 1000 -}}
      {{- if hasKey $dev "uid" -}}
        {{- $uid := ($dev.uid | toString) -}}
        {{- if (not (regexMatch "^[1-9][0-9]*$" $uid)) -}}
          {{- fail (printf "The value for global.dev.uid must be a positive number (%s)" $uid) -}}
        {{- end -}}
        {{- $uid = atoi $uid -}}
      {{- end -}}
      {{- $result = set $result "uid" $uid -}}

      {{- $gid := 1000 -}}
      {{- if hasKey $dev "gid" -}}
        {{- $gid = ($dev.gid | toString) -}}
        {{- if (not (regexMatch "^[1-9][0-9]*$" $gid)) -}}
          {{- fail (printf "The value for global.dev.gid must be a positive number (%s)" $gid) -}}
        {{- end -}}
        {{- $gid = atoi $gid -}}
      {{- end -}}
      {{- $result = set $result "gid" $gid -}}

      {{- $resources := true -}}
      {{- if (hasKey $dev "resources") -}}
        {{- $resources = (not (empty (include "arkcase.toBoolean" ($dev.resources | toString)))) -}}
      {{- end -}}
      {{- $result = set $result "resources" $resources -}}

      {{- $debug := $dev.debug -}}
      {{- if and $debug (kindIs "map" $debug) -}}
        {{- $enabled := or (not (hasKey $debug "enabled")) (not (empty (include "arkcase.toBoolean" $debug.enabled))) -}}
        {{- if $enabled -}}
          {{- $suspend := and (hasKey $debug "suspend") (not (empty (include "arkcase.toBoolean" $debug.suspend))) | ternary "y" "n" -}}
          {{- $flags := dict -}}
          {{- range $k, $v := (omit $debug "port" "suspend" "enabled") -}}
            {{- $flags = set $flags $k (not (empty (include "arkcase.toBoolean" $v))) -}}
          {{- end -}}
          {{- $debug = dict "enabled" $enabled "suspend" $suspend "flags" $flags -}}
        {{- else -}}
          {{- $debug = dict -}}
        {{- end -}}
      {{- else -}}
        {{- $debug = dict -}}
      {{- end -}}
      {{- $result = set $result "debug" $debug -}}

      {{- /* Copy all the other keys verbatim */ -}}
      {{- $result = merge $result (omit $dev "enabled" "war" "conf" "debug" "uid" "gid" "resources") -}}
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

{{- define "arkcase.xmlUnescape" -}}
  {{- $t := (empty $) | ternary "" ($ | toString) -}}
  {{-
    $t | 
      replace "&lt;" "<" |
      replace "&gt;" ">" |
      replace "&quot;" "\"" |
      replace "&apos;" "'" |
      replace "&amp;" "&"
  -}}
{{- end -}}

{{- define "arkcase.xmlEscape" -}}
  {{- $t := (empty $) | ternary "" ($ | toString) -}}
  {{-
    $t | 
      replace "&" "&amp;" |
      replace "<" "&lt;" |
      replace ">" "&gt;" |
      replace "\"" "&quot;" |
      replace "'" "&apos;"
  -}}
{{- end -}}

{{- define "arkcase.securityContext" -}}
  {{- $ctx := . -}}
  {{- $container := "" -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- $ctx = .ctx -}}
    {{- if not (include "arkcase.isRootContext" $ctx) -}}
      {{- fail "Must send the root context as either the only parameter, or the 'ctx' parameter" -}}
    {{- end -}}
    {{- $container = .container -}}
    {{- if or (not $container) (not (kindIs "string" $container)) -}}
      {{- fail "The container name must be a non-empty string" -}}
    {{- end -}}
  {{- end -}}
  {{- $part := (include "arkcase.part.name" $) -}}

  {{- $result := dict -}}

  {{- $securityContext := $ctx.Values.securityContext | default dict -}}
  {{- if not (kindIs "map" $securityContext) -}}
    {{- $securityContext = dict -}}
  {{- end -}}

  {{- if and $part (hasKey $securityContext $part) -}}
    {{- $securityContext = get $securityContext $part -}}
    {{- if or (not $securityContext) (not (kindIs "map" $securityContext)) -}}
      {{- $securityContext = dict -}}
    {{- end -}}
  {{- end -}}

  {{- if $container -}}
    {{- /* If a container name was given, this must be for a container */ -}}
    {{- if (hasKey $securityContext $container) -}}
      {{- $securityContext = get $securityContext $container -}}
      {{- if or (not $securityContext) (not (kindIs "map" $securityContext)) -}}
        {{- $securityContext = dict -}}
      {{- end -}}
      {{-
        $result = pick $securityContext
          "allowPrivilegeEscalation"
          "capabilities"
          "privileged"
          "procMount"
          "readOnlyRootFilesystem"
          "runAsGroup"
          "runAsNonRoot"
          "runAsUser"
          "seLinuxOptions"
          "seccompProfile"
          "windowsOptions"
      -}}
    {{- end -}}

    {{- /* Only apply the patched development IDs if and only if it's a container and we've been asked to do so */ -}}
    {{- if (include "arkcase.toBoolean" .useDevId) -}}
      {{- $dev := (include "arkcase.dev" $ctx | fromYaml) -}}
      {{- if $dev -}}
        {{- if (hasKey $dev "uid") -}}
          {{- $uid := get $dev "uid" -}}
          {{- if (regexMatch "^(0|[1-9][0-9]*)$" ($uid | toString)) -}}
            {{- $result = set $result "runAsUser" ($uid | toString | atoi) -}}
          {{- end -}}
        {{- end -}}
        {{- if (hasKey $dev "gid") -}}
          {{- $gid := get $dev "gid" -}}
          {{- if (regexMatch "^(0|[1-9][0-9]*)$" ($gid | toString)) -}}
            {{- $result = set $result "runAsGroup" ($gid | toString | atoi) -}}
          {{- end -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
  {{- else -}}
    {{- /* If a container name wasn't given, this must be for a pod */ -}}
    {{-
      $result = pick $securityContext
        "fsGroup"
        "fsGroupChangePolicy"
        "runAsGroup"
        "runAsNonRoot"
        "runAsUser"
        "seLinuxOptions"
        "seccompProfile"
        "supplementalGroups"
        "sysctls"
        "windowsOptions"
    -}}
  {{- end -}}


  {{- $result | toYaml -}}
{{- end -}}
