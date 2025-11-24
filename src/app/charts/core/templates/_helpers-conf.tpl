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
# - name: ARKCASE_JDBC_SCHEMA
#   valueFrom:
#     secretKeyRef:
#       name: *confSecret
#       key: "jdbcSchema"
#       optional: false
- name: ARKCASE_JDBC_WORKFLOW_DB_TYPE
  valueFrom:
    secretKeyRef:
      name: *confSecret
      key: "jdbcWorkflowDbType"
      optional: false
- name: ARKCASE_JDBC_PLATFORM
  valueFrom:
    secretKeyRef:
      name: *confSecret
      key: "jdbcPlatform"
      optional: false
- name: ARKCASE_JDBC_QUARTZ_DELEGATE
  valueFrom:
    secretKeyRef:
      name: *confSecret
      key: "jdbcQuartzDelegate"
      optional: false
{{- end -}}
