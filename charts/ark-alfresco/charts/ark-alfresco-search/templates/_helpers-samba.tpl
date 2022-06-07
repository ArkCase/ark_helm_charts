{{/*
Compute the Samba dc=XXX,dc=XXX from a given domain name
*/}}
{{- define "common.samba.dc" -}}
{{- $parts := splitList "." (. | upper) -}}
{{- $dc := "" -}}
{{- $sep := "" -}}
{{- range $parts -}}
{{- $dc = (printf "%s%sdc=%s" $dc $sep .) -}}
{{- if eq $sep "" -}}
{{- $sep = "," -}}
{{- end -}}
{{- end -}}
{{- print $dc -}}
{{- end -}}

{{/*
Compute the Samba REALM name from a given domain name
*/}}
{{- define "common.samba.realm" -}}
{{- $parts := splitList "." (. | upper) -}}
{{- print (index $parts 0) -}}
{{- end -}}
