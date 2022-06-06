{{- define "arkcase.tools.isAllIp" -}}
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
