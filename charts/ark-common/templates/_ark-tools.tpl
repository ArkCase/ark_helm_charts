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
Render the image name taking into account the registry, repository, image name, and tag.
*/ -}}
{{- define "arkcase.tools.image" -}}
  {{- $ctx := . -}}
  {{- $registryName := "" -}}
  {{- $repositoryName := "" -}}
  {{- $tag := "" -}}
  {{- $explicit := false -}}
  {{- if not (include "arkcase.isRootContext" .) -}}
    {{- $ctx = .ctx -}}
    {{- if not (include "arkcase.isRootContext" $ctx) -}}
      {{- fail "The given 'ctx' parameter is not the root context" -}}
    {{- end -}}
    {{- $registryName = .registry -}}
    {{- $repositoryName = .repository -}}
    {{- if (hasKey . "tag") -}}
      {{- /* Make sure we use the tag given here - empty tags = "latest" */ -}}
      {{- $tag = (coalesce .tag $ctx.Chart.AppVersion "latest") -}}
    {{- end -}}
    {{- $explicit = true -}}
  {{- end -}}
  {{- $image := (required "No image information was found in the Values object" $ctx.Values.image) -}}
  {{- $partname := include "arkcase.part.name" $ctx -}}
  {{- if $partname -}}
    {{- if not (hasKey $image $partname) -}}
      {{- fail (printf "No image information found for part '%s'" $partname) -}}
    {{- end -}}
    {{- $image = merge (get $image $partname) (pick $image "registry" "repository" "tag" "pullPolicy") -}}
  {{- end -}}
  {{- $global := (default dict $ctx.Values.global) -}}
  {{- if or (hasKey $global "imageRegistry") ($global.imageRegistry) -}}
    {{- /* Global registry trumps everything */ -}}
    {{- $registryName = $global.imageRegistry -}}
  {{- else if and (not $registryName) (or (not $explicit) (not (hasKey . "registry"))) -}}
    {{- /* If we don't yet have a registry name, and we weren't given one explicitly, then use the "default" */ -}}
    {{- $registryName = $image.registry -}}
  {{- end -}}
  {{- if not $repositoryName -}}
    {{- $repositoryName = (required "No repository (image) name was given" $image.repository) -}}
  {{- end -}}
  {{- if not $tag -}}
    {{- $tag = (toString (coalesce $image.tag $ctx.Chart.AppVersion "latest")) -}}
  {{- end -}}
  {{- if $registryName -}}
    {{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
  {{- else -}}
    {{- printf "%s:%s" $repositoryName $tag -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.tools.subimage" -}}
  {{- if or (not (hasKey . "ctx")) (not (kindIs "map" .ctx)) (empty .ctx) -}}
    {{- fail "The 'ctx' parameter is required and must be a non-empty map" -}}
  {{- end -}}
  {{- $ctx := .ctx -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "You must supply the 'ctx' parameter, pointing to the root context that contains 'Values' et al." -}}
  {{- end -}}
  {{- if or (not (hasKey . "name")) (not (kindIs "string" .name)) (empty .name) -}}
    {{- fail "The 'name' parameter is required and must be a non-empty string" -}}
  {{- end -}}
  {{- $name := .name | trim -}}
  {{- if or (not (hasKey . "image")) (not (kindIs "string" .image)) (empty .image) -}}
    {{- fail "The 'image' parameter is required and must be a non-empty string" -}}
  {{- end -}}
  {{- $image := .image | trim -}}

  {{- $imageMap := (coalesce $ctx.Values.image dict) -}}
  {{- $subimageMap := dict -}}
  {{- if and (hasKey $imageMap $name) -}}
    {{- $subimageMap = get $imageMap $name -}}
  {{- end -}}
  {{- if not (and (kindIs "map" $subimageMap) (not (empty $subimageMap))) -}}
    {{- $subimageMap = dict -}}
  {{- end -}}

  {{- $registry := "" -}}
  {{- if and (hasKey $subimageMap "registry") (kindIs "string" $subimageMap.registry) (not (empty $subimageMap.registry)) -}}
    {{- $registry = $subimageMap.registry -}}
  {{- else -}}
    {{- $registry = ($ctx.Values.image).registry -}}
  {{- end -}}

  {{- $repository := "" -}}
  {{- if and (hasKey $subimageMap "repository") (kindIs "string" $subimageMap.repository) (not (empty $subimageMap.repository)) -}}
    {{- $repository = $subimageMap.repository -}}
  {{- else -}}
    {{- $repository = $image -}}
  {{- end -}}

  {{- $tag := "" -}}
  {{- if and (hasKey $subimageMap "tag") (kindIs "string" $subimageMap.tag) (not (empty $subimageMap.tag)) -}}
    {{- $tag = $subimageMap.tag -}}
  {{- else -}}
    {{- $tag = "latest" -}}
  {{- end -}}

  {{- $params := dict "ctx" $ctx "registry" $registry "repository" $repository "tag" $tag -}}

  {{- include "arkcase.tools.image" $params -}}
{{- end -}}

{{- /*
Render the image registry name taking into account global values as well
*/ -}}
{{- define "arkcase.tools.imageRegistry" -}}
  {{- $image := (required "No image information was found in the Values object" .Values.image) -}}
  {{- $global := (default dict .Values.global) -}}
  {{- $registryName := $image.registry -}}
  {{- if $global -}}
    {{- if $global.imageRegistry -}}
      {{- $registryName = $global.imageRegistry -}}
    {{- end -}}
  {{- end -}}
  {{- $registryName -}}
{{- end -}}

{{- /*
Render the image pull policy taking into account the global value as well
*/ -}}
{{- define "arkcase.tools.imagePullPolicy" -}}
  {{- $partname := (include "arkcase.part.name" .) -}}
  {{- $image := (required "No image information was found in the Values object" .Values.image) -}}
  {{- if $partname -}}
    {{- if not (hasKey $image $partname) -}}
      {{- fail (printf "No image information found for part '%s'" $partname) -}}
    {{- end -}}
    {{- $image = merge (get $image $partname) (pick $image "registry" "repository" "tag" "pullPolicy") -}}
  {{- end -}}
  {{- $global := (default dict .Values.global) -}}
  {{- $tag := (toString (default "" $image.tag)) -}}
  {{- $pullPolicy := (toString (default "" $image.pullPolicy)) -}}
  {{- if (empty $pullPolicy) -}}
    {{- if or (empty $tag) (eq $tag "latest") -}}
      {{- $pullPolicy = "Always" -}}
    {{- else -}}
      {{- $pullPolicy = "IfNotPresent" -}}
    {{- end -}}
  {{- end -}}
  {{- $pullPolicy -}}
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

{{- define "arkcase.tools.ldap" -}}
  {{- if not (kindIs "map" .) -}}
    {{- fail "The parameter must be a map" -}}
  {{- end -}}
  {{- if not (hasKey . "ctx") -}}
    {{- fail "Must provide the root context as the 'ctx' parameter value" -}}
  {{- end -}}
  {{- $ctx := .ctx -}}
  {{- if not (kindIs "map" $ctx) -}}
    {{- fail "The context given ('ctx' parameter) must be a map" -}}
  {{- end -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The context given (either the parameter map, or the 'ctx' value within) is not the top-level context" -}}
  {{- end -}}

  {{- if not .value -}}
    {{- fail "Must provide a 'value' parameter to indicate which value to fetch" -}}
  {{- end -}}

  {{- $ldap := ($ctx.Values.configuration).ldap -}}
  {{- if $ldap -}}
    {{- include "arkcase.tools.get" (dict "ctx" $ldap "name" (.value | toString)) -}}
  {{- end -}}
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
