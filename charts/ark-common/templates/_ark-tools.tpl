{{- /*
Outputs "true" if the given parameter matches an IPv4 address (4 dot-separated octets between 0 and 255), or the empty string if not.

usage: ( include "arkcase.tools.isIp" "some.ip.to.check" )
result: either "" or "true"
*/ -}}
{{- define "arkcase.tools.isIp" -}}
  {{- $addx := . -}}
  {{- if (eq (upper $addx) ($addx)) -}}
    {{- /* Second test: is it a set of 4 dot-separated numbers? */ -}}
    {{- $octets := splitList "." $addx }}
    {{- $fail := (eq 1 0) -}}
    {{- if eq ( $octets | len ) 4 }}
      {{- range $, $octet := $octets }}
        {{- if or ($fail) (not (regexMatch "^[0-9]{1,3}$" $octet)) -}}
          {{- $fail = (eq 1 1) -}}
        {{- else -}}
          {{- $octet = (int $octet) -}}
          {{- if or (lt $octet 0) (gt $octet 255) -}}
            {{- $fail = (eq 1 1) -}}
          {{- end -}}
        {{- end -}}
      {{- end -}}
    {{- end }}
    {{- if not $fail -}}
      {{- true -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{/*
Sanitize the given domain name by removing consecutive dots, and leading and trailing dots. The name must comply with RFC-1123 requirements (only A-Z, a-z, 0-9, the dots, and the dash (-) are allowed. This template will fail if the given name does not meet those requirements.

usage: ( include "arkcase.tools.sanitizeDomain" "....some.domain......com....." )
result: "some.domain.com" (may fail() if the domain is not valid per RFC-1123)
*/}}
{{- define "arkcase.tools.sanitizeDomain" -}}
  {{- /* Remove consecutive dots */ -}}
  {{- $name := (regexReplaceAll "[.]+" . ".") -}}
  {{- /* Remove leading and trailing dots */ -}}
  {{- $name = (regexReplaceAll "^[.]?(.*?)[.]?$" $name "${1}") -}}
  {{- if (not (regexMatch "^[a-zA-Z0-9-.]+$" $name)) -}}
    {{- fail (printf "The domain name [%s] is not valid per DNS rules (RFC-1123)" .) -}}
  {{- end -}}
  {{- $name -}}
{{- end -}}

{{/*
Compute the Samba dc=XXX,dc=XXX from a given domain name

usage: ( include "arkcase.tools.samba.dc" "some.domain.com" )
result: "DC=some,DC=domain,DC=com"
*/}}
{{- define "arkcase.tools.samba.dc" -}}
  {{- $parts := splitList "." (include "arkcase.tools.sanitizeDomain" . | upper) -}}
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
  {{- $parts := splitList "." (include "arkcase.tools.sanitizeDomain" . | upper) -}}
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
