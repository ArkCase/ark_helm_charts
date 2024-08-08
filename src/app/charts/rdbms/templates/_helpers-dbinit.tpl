{{- define "arkcase.initDatabase.container" -}}
  {{- $ctx := $.ctx -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "You must supply the 'ctx' parameter, pointing to the root context that contains 'Values' et al." -}}
  {{- end -}}

  {{- /* Check our parameters */ -}}
  {{- $dbType := $.db | toString | trim | required "The 'db' parameter must be present, a string-value, and non-empty" -}}
  {{- $volume := $.volume | toString | trim | required "The 'volume' parameter must be present, a string value, and non-empty" -}}
  {{- $shell := (not (empty (include "arkcase.toBoolean" $.shell))) -}}
  {{- $scriptSources := ($.scriptSources | default "" | toString) -}}
  {{- $containerName := ($.name | default "init-database" | toString | trim) -}}

- name: {{ $containerName | quote }}
  {{- include "arkcase.image" (dict "ctx" $ctx "name" "dbinit" "repository" "arkcase/dbinit") | nindent 2 }}
  env: {{- include "arkcase.tools.baseEnv" $ctx | nindent 4 }}
    {{- include "arkcase.subsystem-access.env" $ctx | nindent 4 }}
    - name: INIT_DB_TYPE
      value: {{ $dbType | quote }}
    - name: INIT_DB_CONF
      value: "/dbinit-config.yaml"
    - name: INIT_DB_STORE
      value: &initDbStorePath "/dbinit"
    - name: INIT_DB_SECRETS
      value: &dbInitSecretsMount "/dbsecrets"
    - name: INIT_DB_SHELL
      value: {{ $shell | quote }}
    {{- if $scriptSources }}
    - name: INIT_DB_SHELL_SOURCES
      value: {{ $scriptSources | quote }}
    {{- end }}
  volumeMounts:
    # This volume mount is required b/c this is where we'll put the rendered initialization scripts
    # that the DB container is expected to execute during startup
    - name: {{  $volume | quote  }}
      mountPath: *initDbStorePath
    {{- include "arkcase.file-resource.volumeMount" (dict "ctx" $ctx "mountPath" "/dbinit-config.yaml") | nindent 4 }}
{{- end -}}
