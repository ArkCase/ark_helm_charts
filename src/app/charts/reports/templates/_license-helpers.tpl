{{- define "__arkcase.pentaho.licenses.compute" -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The parameter must be the root context ($ or .)" -}}
  {{- end -}} 

  {{- $result := dict -}}
  {{- $licenses := (include "arkcase.license" (dict "ctx" $ctx "name" "pentaho") | fromYaml) -}}
  {{- if and $licenses $licenses.data -}}
    {{- $licenses = $licenses.data -}}
    {{- if not (kindIs "slice" $licenses) -}}
      {{- fail (printf "Please make sure the pentaho licenses in global.licenses.pentaho is an array of files, not a %s" (kindOf $licenses)) -}}
    {{- end -}}
    {{- range $pos, $license := $licenses -}}
      {{- $result = set $result (printf "pentaho_license_%d.lic" $pos) $license -}}
    {{- end -}}
  {{- end -}}

  {{- /* Always make sure that if portal/FOIA mode is active, we have EE licenses */ -}}
  {{- $portal := (include "arkcase.portal" $ | fromYaml) -}}
  {{- if and $portal (not $result) -}}
    {{- fail "Portal mode requires Pentaho Enterprise licenses, please add this information" -}}
  {{- end -}}
  {{- $result | toYaml -}}
{{- end -}}

{{- define "arkcase.pentaho.licenses" -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The parameter must be the root context ($ or .)" -}}
  {{- end -}} 
    
  {{- $args :=
    dict  
      "ctx" $ctx
      "template" "__arkcase.pentaho.licenses.compute"
  -}}
  {{- include "__arkcase.tools.getCachedValue" $args -}}
{{- end -}}

{{- define "arkcase.pentaho.license.secrets" -}}
  {{- $licenses := (include "arkcase.pentaho.licenses" . | fromYaml) -}}
  {{- if $licenses }}
#
# Apply licenses
#
    {{- range $key, $value := $licenses }}
{{ $key }}: |- {{- $value | nindent 2 }}
    {{- end }}
  {{- end }}
{{- end -}}

{{- define "arkcase.pentaho.license.secret.name" -}}
  {{ $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "Must include the root context as the only parameter" -}}
  {{- end -}}
  {{- printf "%s-%s-licenses" $.Release.Name (include "arkcase.subsystem.name" $) -}}
{{- end -}}

{{- define "arkcase.pentaho.license.volumeMounts" -}}
  {{- $ctx := $ -}}
  {{- $path := "/app/init/licenses" -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{ $ctx = $.ctx -}}
    {{- if not (include "arkcase.isRootContext" $ctx) -}}
      {{- fail "Must include the root context as the 'ctx' parameter, or the only parameter" -}}
    {{- end -}}
    {{- $path = (hasKey $ "path" | ternary ($.path | default "" | toString) "" | default $path) -}}
  {{- end }}
  {{- $licenses := (include "arkcase.pentaho.licenses" $ctx | fromYaml) -}}
  {{- if $licenses -}}
# License mounts begin
    {{- range $key, $value := $licenses }}
- name: "pentaho-licenses"
  mountPath: {{ printf "%s/%s" $path $key | quote }}
  subPath: {{ $key | quote }}
  readOnly: true
    {{- end }}
# License mounts end
  {{- end -}}
{{- end -}}

{{- define "arkcase.pentaho.license.volume" -}}
  {{ $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "Must include the root context as the only parameter" -}}
  {{- end -}}
  {{- $licenses := (include "arkcase.pentaho.licenses" $ctx | fromYaml) -}}
  {{- if $licenses -}}
# License volume begins
- name: "pentaho-licenses"
  secret:
    optional: false
    secretName: {{ include "arkcase.pentaho.license.secret.name" $ctx | quote }}
    defaultMode: 0444
# License volume ends
  {{- end -}}
{{- end -}}
