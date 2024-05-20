{{- define "arkcase.rdbms.external" -}}
  {{- /* Due to some odd trickery being done in arkcase.db.info.compute, */ -}}
  {{- /* we may sometimes come to believe that a hostname we've been given */ -}}
  {{- /* refers to an external host. This bit of code sees through the mixup */ -}}
  {{- /* and only considers a hostname to be "external" if it's different from */ -}}
  {{- /* the default hostname in the chart's local configurations. */ -}}
  {{- $local := (include "arkcase.tools.get" (dict "ctx" $ "name" "Values.configuration.db.hostname") | fromYaml) -}}
  {{- $global := (include "arkcase.tools.get" (dict "ctx" $ "name" "Values.global.conf.rdbms.hostname") | fromYaml) -}}
  {{- if and $local $local.value -}}
    {{- $local = ($local.value | lower) -}}
  {{- else -}}
    {{- $local = "" -}}
  {{- end -}}
  {{- if and $global $global.value -}}
    {{- $global = ($global.value | lower) -}}
  {{- else -}}
    {{- $global = $local -}}
  {{- end -}}
  {{- if ne $local $global -}}
    {{- true -}}
  {{- end -}}
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
    {{- include "arkcase.subsystem.service" (dict "ctx" $ "subname" $name) -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.rdbms.render" -}}
  {{- $ctx := $ -}}
  {{- $name := "" -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- $ctx = .ctx -}}
    {{- if not (include "arkcase.isRootContext" $ctx) -}}
      {{- fail "Incorrect context given - either submit the root context as the only parameter, or a 'ctx' parameter pointing to it" -}}
    {{- end -}}
    {{- $name = .name -}}
  {{- end -}}
  {{- $render := true -}}
  {{- $render = and $render (not (empty (include "arkcase.subsystem.enabled" $ctx))) -}}
  {{- $render = and $render (empty (include "arkcase.rdbms.external" $ctx)) -}}
  {{- $render = and $render (or (empty $name) (eq $name (include "arkcase.rdbms.type" $ctx))) -}}
  {{- $render | ternary "true" "" -}}
{{- end -}}
