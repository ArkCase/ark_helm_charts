{{- define "arkcase.pentaho.licenses" -}}
  {{- if not (include "arkcase.isRootContext" $) -}}
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
    {{- if (($.Values.global).licenses).pentaho -}}
      {{- $licenses := $.Values.global.licenses.pentaho -}}
      {{- if not (kindIs "slice" $licenses) -}}
        {{- fail (printf "Please make sure the pentaho licenses in global.licenses.pentaho is an array of files, not a %s" (kindOf $licenses)) -}}
      {{- end -}}
      {{- $pos := 0 -}}
      {{- range $license := $licenses -}}
        {{- $result = set $result (printf "pentaho_license_%d.lic" $pos) $license -}}
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

{{- define "arkcase.pentaho.license.volume.name" -}}
  {{ $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "Must include the root context as the only parameter" -}}
  {{- end -}}
  {{- printf "%s-licenses" (include "common.name" $) -}}
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
    {{- $volume := (include "arkcase.pentaho.license.volume.name" $ctx) -}}
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
    {{- $volume := (include "arkcase.pentaho.license.volume.name" $ctx) -}}
# License volume begins
- name: "pentaho-licenses"
  secret:
    optional: false
    secretName: {{ $volume | quote }}
    defaultMode: 0444
# License volume ends
  {{- end -}}
{{- end -}}
