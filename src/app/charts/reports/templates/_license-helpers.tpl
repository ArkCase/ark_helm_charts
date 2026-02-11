{{- define "__arkcase.pentaho.volume.name" -}}
pentaho-license
{{- end -}}

{{- define "__arkcase.pentaho.license.path" -}}
/app/pentaho/.pentaho/license.bin
{{- end -}}

{{- define "__arkcase.pentaho.license.compute" -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The parameter must be the root context ($ or .)" -}}
  {{- end -}} 

  {{- $result := dict -}}
  {{- $license := (include "arkcase.license" (dict "ctx" $ctx "name" "pentaho") | fromYaml) -}}
  {{- if and $license $license.data -}}
    {{- $license = $license.data -}}
    {{- if not (kindIs "map" $license) -}}
      {{- fail (printf "Please make sure the pentaho license in global.licenses.pentaho is dict (map), not a %s" (kindOf $license)) -}}
    {{- end -}}

    {{- $result = set $result "file" ($license.file | default "" | toString | trim) -}}
    {{- if not $result.file -}}
      {{- fail "Pentaho license server access is not supported - you must provide a non-blank license file" -}}
    {{- end -}}

    {{- $result = set $result "host" ($license.host | default "" | toString) -}}
    {{- if not $result.host -}}
      {{- fail "Pentaho license server access is not supported - you must provide a direct host ID specification to match the given license file (sha256sum = %s)" ($result.file | b64dec | sha256sum) -}}
    {{- end -}}

    {{- $result = set $result "path" ($license.path | default (include "__arkcase.pentaho.license.path" $ctx) | toString) -}}
    {{- $result = set $result "type" ($license.type | default "NODE_UNLOCKED" | toString | trim) -}}
  {{- end -}}

  {{- /* Always make sure that if portal/FOIA mode is active, we have EE licenses */ -}}
  {{- $portal := (include "arkcase.portal" $ | fromYaml) -}}
  {{- if and $portal (not $result) -}}
    {{- fail "Portal mode requires Pentaho Enterprise licensing, please add this information" -}}
  {{- end -}}
  {{- $result | toYaml -}}
{{- end -}}

{{- define "arkcase.pentaho.license" -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The parameter must be the root context ($ or .)" -}}
  {{- end -}} 
    
  {{- $args :=
    dict  
      "ctx" $ctx
      "template" "__arkcase.pentaho.license.compute"
  -}}
  {{- include "__arkcase.tools.getCachedValue" $args -}}
{{- end -}}

{{- define "arkcase.pentaho.license.secret.name" -}}
  {{ $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "Must include the root context as the only parameter" -}}
  {{- end -}}
  {{- printf "%s-%s-license" $.Release.Name (include "arkcase.subsystem.name" $) -}}
{{- end -}}

{{- define "arkcase.pentaho.license.volumeMount" -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "Must include the root context as the only parameter" -}}
  {{- end }}
  {{- $license := (include "arkcase.pentaho.license" $ctx | fromYaml) -}}
  {{- if $license }}
# License mount begins
- name: {{ include "__arkcase.pentaho.volume.name" $ctx | quote }}
  mountPath: {{ $license.path | quote }}
  subPath: "file"
  readOnly: true
# License mount ends
  {{- end }}
{{- end -}}

{{- define "arkcase.pentaho.license.volume" -}}
  {{ $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "Must include the root context as the only parameter" -}}
  {{- end -}}
  {{- $license := (include "arkcase.pentaho.license" $ctx | fromYaml) -}}
  {{- if $license }}
# License volume begins
- name: {{ include "__arkcase.pentaho.volume.name" $ctx | quote }}
  secret:
    optional: false
    secretName: {{ include "arkcase.pentaho.license.secret.name" $ctx | quote }}
    defaultMode: 0444
# License volume ends
  {{- end }}
{{- end -}}

{{- define "arkcase.pentaho.license.env" -}}
  {{ $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "Must include the root context as the only parameter" -}}
  {{- end -}}
  {{- $license := (include "arkcase.pentaho.license" $ctx | fromYaml) -}}
  {{- if $license }}
# License environment begins
- name: "PENTAHO_LICENSE_FILE"
  valueFrom:
    secretKeyRef:
      name: &license-secret {{ include "arkcase.pentaho.license.secret.name" $ctx | quote }}
      key: "path"
      optional: false
- name: "PENTAHO_LICENSE_HOST"
  valueFrom:
    secretKeyRef:
      name: *license-secret
      key: "host"
      optional: false
- name: "PENTAHO_LICENSE_TYPE"
  valueFrom:
    secretKeyRef:
      name: *license-secret
      key: "type"
      optional: false
# License environment ends
  {{- end }}
{{- end -}}
