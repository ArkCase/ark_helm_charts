{{- define "arkcase.alfresco.license.secret" -}}
  {{- printf "%s-licenses" (include "arkcase.basename" $) -}}
{{- end -}}

{{- define "__arkcase.alfresco.licenses.compute" -}}
  {{- $ctx := $ -}}
  {{- $result := dict -}}
  {{- $licenses := (include "arkcase.license" (dict "ctx" $ctx "name" "alfresco") | fromYaml) -}}
  {{- if and $licenses $licenses.data -}}
    {{- $licenses = $licenses.data -}}
    {{- if not (kindIs "string" $licenses) -}}
      {{- fail (printf "Please make sure the alfresco licenses in global.licenses.alfresco is a string (base-64 encoded), not a %s" (kindOf $licenses)) -}}
    {{- end -}}
    {{- range $pos, $license := (list $licenses) -}}
      {{- $result = set $result (printf "alfresco_license_%d.lic" $pos) $license -}}
    {{- end -}}
  {{- end -}}
  {{- $result | toYaml -}}
{{- end -}}

{{- define "arkcase.alfresco.licenses" -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The parameter must be the root context ($ or .)" -}}
  {{- end -}}

  {{- $args :=
    dict
      "ctx" $ctx
      "template" "__arkcase.alfresco.licenses.compute"
  -}}
  {{- include "__arkcase.tools.getCachedValue" $args -}}
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
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- $ctx = $.ctx -}}
    {{- if not (include "arkcase.isRootContext" $ctx) -}}
      {{- fail "The parameter must be the root context ($ or .)" -}}
    {{- end -}}
  {{- end -}}

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
