{{- define "arkcase.alfresco.licenses" -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The parameter must be the root context ($ or .)" -}}
  {{- end -}}

  {{- $key := "PentahoLicenses" -}}
  {{- $masterCache := dict -}}
  {{- if (hasKey $ $key) -}}
    {{- $masterCache = get $ $key -}}
    {{- if and $masterCache (not (kindIs "map" $masterCache)) -}}
      {{- $masterCache = dict -}}
    {{- end -}}
  {{- end -}}
  {{- $crap := set $ $key $masterCache -}}

  {{- $chartName := (include "arkcase.fullname" $) -}}
  {{- if not (hasKey $masterCache $chartName) -}}
    {{- $result := dict -}}
    {{- $licenses := (include "arkcase.license" (dict "ctx" $ctx "name" "alfresco") | fromYaml) -}}
    {{- if and $licenses $licenses.data -}}
      {{- $licenses = $licenses.data -}}
      {{- if not (kindIs "string" $licenses) -}}
        {{- fail (printf "Please make sure the alfresco licenses in global.licenses.alfresco is a string (base-64 encoded), not a %s" (kindOf $licenses)) -}}
      {{- end -}}
      {{- $licenses = list $licenses -}}
      {{- $pos := 0 -}}
      {{- range $license := $licenses -}}
        {{- $result = set $result (printf "alfresco_license_%d.lic" $pos) $license -}}
        {{- $pos = add $pos 1 -}}
      {{- end -}}
    {{- end -}}
    {{- if not $result -}}
      {{- $result = dict -}}
    {{- end -}}
    {{- $masterCache = set $masterCache $chartName $result -}}
  {{- end -}}
  {{- get $masterCache $chartName | toYaml -}}
{{- end -}}

{{- define "arkcase.alfresco.license.secrets" -}}
  {{- $licenses := (include "arkcase.alfresco.licenses" $ | fromYaml) -}}
  {{- if $licenses }}
#
# Apply licenses
#
    {{- range $key, $value := $licenses }}
{{ $key }}: |- {{- $value | nindent 2 }}
    {{- end }}
  {{- end }}
{{- end -}}

{{- define "arkcase.alfresco.license.volumeMounts" -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- $ctx = $.ctx -}}
    {{- if not (include "arkcase.isRootContext" $ctx) -}}
      {{- fail "The parameter must be the root context ($ or .)" -}}
    {{- end -}}
  {{- end -}}

  {{- $licenses := (include "arkcase.alfresco.licenses" $ctx | fromYaml) -}}
  {{- if $licenses -}}
    {{- $volume := "secrets" -}}
    {{- if and (hasKey . "volume") .volume -}}
      {{- $volume = .volume -}}
    {{- end -}}
    {{- $path := "/usr/local/tomcat/shared/classes/alfresco/extension/license" -}}
    {{- if and (hasKey . "path") .path -}}
      {{- $path = .path -}}
    {{- end -}}
# License mounts begin
    {{- range $key, $value := $licenses }}
- name: {{ $volume | quote }}
  mountPath: "{{ $path }}/{{ $key }}"
  subPath: {{ $key | quote }}
  readOnly: true
    {{- end }}
# License mounts end
  {{- end -}}
{{- end -}}

{{- define "arkcase.alfresco.license.volumes" -}}
  {{- $licenses := (include "arkcase.alfresco.licenses" $ | fromYaml) -}}
  {{- if $licenses -}}
# License entries begin
{{- range $key, $value := $licenses }}
- key:  &license {{ $key | quote }}
  path: *license
{{- end }}
# License entries end
  {{- end -}}
{{- end -}}
