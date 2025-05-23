{{- define "arkcase.rdbms.external" -}}
  {{- include "arkcase.subsystem.external" $ -}}
{{- end -}}

{{- define "arkcase.rdbms.type" -}}
  {{- get (include "arkcase.db.info" $ | fromYaml) "name" -}}
{{- end -}}

{{- define "arkcase.rdbms.ports" -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "Incorrect context given - submit the root context as the only parameter" -}}
  {{- end -}}
  {{- $name := (include "arkcase.rdbms.type" $ctx) -}}
  {{- $services := ($ctx.Values.service | default dict) -}}
  {{- if hasKey $services $name -}}
    {{- include "arkcase.subsystem.ports" (dict "ctx" $ctx "name" $name) -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.rdbms.service" -}}
  {{- $name := (include "arkcase.rdbms.type" $) -}}
  {{- $services := ($.Values.service | default dict) -}}
  {{- if hasKey $services $name -}}
    {{- include "arkcase.subsystem.service" (dict "ctx" $ "partname" $name) -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.rdbms.render" -}}
  {{- $ctx := $ -}}
  {{- $name := "" -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- $ctx = $.ctx -}}
    {{- if not (include "arkcase.isRootContext" $ctx) -}}
      {{- fail "Incorrect context given - either submit the root context as the only parameter, or a 'ctx' parameter pointing to it" -}}
    {{- end -}}
    {{- $name = $.name -}}
  {{- end -}}
  {{- $render := true -}}
  {{- $render = and $render (not (empty (include "arkcase.subsystem.enabled" $ctx))) -}}
  {{- $render = and $render (empty (include "arkcase.subsystem.external" $ctx)) -}}
  {{- $render = and $render (or (empty $name) (eq $name (include "arkcase.rdbms.type" $ctx))) -}}
  {{- $render | ternary "true" "" -}}
{{- end -}}
