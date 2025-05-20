{{- define "arkcase.core.conf.secret" -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The parameter must be the root context ($ or .)" -}}
  {{- end -}}
  {{- printf "%s-%s-conf" $ctx.Release.Name (include "arkcase.subsystem.name" $ctx) -}}
{{- end -}}

{{- define "arkcase.core.conf.env" -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The parameter must be the root context ($ or .)" -}}
  {{- end -}}
  {{- $secret := (include "arkcase.core.conf.secret" $ctx) -}}
- name: ARKCASE_JDBC_DRIVER
  valueFrom:
    secretKeyRef:
      name: &confSecret {{ $secret | quote }}
      key: "jdbcDriver"
      optional: false
- name: ARKCASE_JDBC_URL
  valueFrom:
    secretKeyRef:
      name: *confSecret
      key: "jdbcUrl"
      optional: false
{{- end -}}
