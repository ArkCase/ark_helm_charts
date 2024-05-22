{{- define "arkcase.alfresco.license.secret" -}}
  {{- printf "%s-licenses" (include "arkcase.basename" $) -}}
{{- end -}}

{{- define "arkcase.alfresco.licenses" -}}
  {{- if not (include "arkcase.isRootContext" $) -}}
    {{- fail "The parameter must be the root context ($ or .)" -}}
  {{- end -}}

  {{- $key := "AlfrescoLicense" -}}
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
    {{- if (($.Values.global).licenses).alfresco -}}
      {{- $licenses := $.Values.global.licenses.alfresco -}}
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

{{- define "arkcase.alfresco.license.volumeMounts" -}}
  {{ $ctx := (hasKey $ "ctx" | ternary $.ctx $) -}}
  {{- $licenses := (include "arkcase.alfresco.licenses" $ctx | fromYaml) -}}
  {{- if $licenses -}}
    {{- $volume := (get $ "volume") | default "alfresco-licenses" -}}
    {{- $path := (get $ "path") | default "/usr/local/tomcat/shared/classes/alfresco/extension/license" -}}
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

{{- define "arkcase.alfresco.license.volume" -}}
  {{ $ctx := (hasKey $ "ctx" | ternary $.ctx $) -}}
  {{- $licenses := (include "arkcase.alfresco.licenses" $ctx | fromYaml) -}}
  {{- if $licenses -}}
    {{- $volume := (get $ "volume") | default "alfresco-licenses" -}}
# License volume begins
- name: {{ $volume | quote }}
  secret:
    optional: false
    secretName: {{ include "arkcase.alfresco.license.secret" $ctx | quote }}
    defaultMode: 0444
# License volume ends
  {{- end -}}
{{- end -}}
