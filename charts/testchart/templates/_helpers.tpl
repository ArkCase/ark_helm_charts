{{- /*
Outputs "true" if the given parameter is a string that matches an IPv4 address (4 dot-separated octets between 0 and 255), a list (slice) of IP addresses, or a comma-separated string of IP addresses. If any of the strings submitted is not an IP address, template processing will be halted.

usage: ( include "arkcase.tools.mustIp" "some.ip.to.check" )
       ( include "arkcase.tools.mustIp" (list "some.ip.to.check" "another.ip.to.check" ...) )
       ( include "arkcase.tools.mustIp" "some.ip.to.check,another.ip.to.check" )
result: either "true" or template processing will be halted
*/ -}}
{{- define "arkcase.tools.mustIp" -}}
  {{- $param := (default list .) -}}
  {{- $result := (include "arkcase.tools.isIp" $param) -}}
  {{- if $result -}}
    {{- $result -}}
  {{- else -}}
    {{- fail (printf "One of the values in %s is not an IP address" $param) -}}
  {{- end -}}
{{- end -}}

{{- /*
Outputs "true" if the given parameter is a string that matches an IPv4 address (4 dot-separated octets between 0 and 255), a list (slice) of IP addresses, or a comma-separated string of IP addresses. If any of the strings submitted is not an IP address, the empty string will be output.

usage: ( include "arkcase.tools.isIp" "some.ip.to.check" )
       ( include "arkcase.tools.isIp" (list "some.ip.to.check" "another.ip.to.check" ...) )
       ( include "arkcase.tools.isIp" "some.ip.to.check,another.ip.to.check" )
result: either "" or "true"
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
    {{- $addx := (toString .) -}}
    {{- if and (not $fail) (eq (upper $addx) (lower $addx)) -}}
      {{- /* Second test: is it a set of 4 dot-separated numbers? */ -}}
      {{- $octets := splitList "." $addx }}
      {{- if eq ( $octets | len ) 4 }}
        {{- range $, $octet := $octets }}
          {{- if (not (regexMatch "^[0-9]{1,3}$" $octet)) -}}
            {{- $fail = (eq 1 1) -}}
          {{- else -}}
            {{- $octet = (int $octet) -}}
            {{- if or (lt $octet 0) (gt $octet 255) -}}
              {{- $fail = (eq 1 1) -}}
            {{- end -}}
          {{- end -}}
        {{- end -}}
      {{- end }}
    {{- else if (not $fail) -}}
      {{- $fail = (eq 1 1) -}}
    {{- end -}}
  {{- end -}}
  {{- if not $fail -}}
    {{- true -}}
  {{- end -}}
{{- end -}}
