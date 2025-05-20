{{- define "arkcase.acme.env" -}}
  {{- if not (include "arkcase.isRootContext" $) -}}
    {{- fail "The parameter given must be the root context (. or $)" -}}
  {{- end -}}
- name: SSL_DIR
  value: "/.ssl"
- name: &acmeUrlVar {{ include "arkcase.acme.urlVariable" $ | quote }}
  valueFrom:
    secretKeyRef:
      name: &acmeSecret {{ include "arkcase.acme.sharedSecret" $ | quote }}
      key: *acmeUrlVar
- name: ACME_SERVICE_NAME
  value: {{ include "arkcase.service.name" $ | quote }}
{{- end -}}

{{- define "arkcase.acme.sharedSecret" -}}
  {{- if not (include "arkcase.isRootContext" $) -}}
    {{- fail "The parameter given must be the root context (. or $)" -}}
  {{- end -}}
  {{- printf "%s-acme-shared" $.Release.Name -}}
{{- end -}}

{{- define "arkcase.acme.urlVariable" -}}
ACME_URL
{{- end -}}

{{- define "arkcase.acme.passwordVariable" -}}
ACME_CLIENT_PASSWORD
{{- end -}}

{{- define "arkcase.acme.volumeMount" -}}
  {{- if not (include "arkcase.isRootContext" $) -}}
    {{- fail "The parameter given should be the root context (. or $)" -}}
  {{- end -}}
- name: &acmePasswordVol "acme-password"
  mountPath: "/.acme.password"
  subPath: &acmePassword {{ include "arkcase.acme.passwordVariable" $ | quote }}
  readOnly: true
{{- end -}}

{{- define "arkcase.acme.volumeMount-shared" -}}
  {{- include "arkcase.acme.volumeMount" $ | nindent 0 }}
- name: "acme-ssl-vol"
  mountPath: "/.ssl"
{{- end -}}

{{- define "arkcase.acme.volume" -}}
  {{- if not (include "arkcase.isRootContext" $) -}}
    {{- fail "The parameter given should be the root context (. or $)" -}}
  {{- end -}}
- name: *acmePasswordVol
  secret:
    optional: false
    secretName: {{ include "arkcase.acme.sharedSecret" $ | quote }}
    defaultMode: 0444
    items:
      - key: *acmePassword
        path: *acmePassword
{{- end -}}

{{- define "arkcase.acme.volume-shared" -}}
  {{- include "arkcase.acme.volume" $ | nindent 0 }}
# The shared certificates volume is laughably tiny
- name: "acme-ssl-vol"
  emptyDir:
    medium: "Memory"
    sizeLimit: 4Mi
{{- end -}}
