{{- define "arkcase.db.info" -}}
  {{- $db := (required "Must configure the value for configuration.db.dialect" ((.Values.configuration).db).dialect) -}}
  {{- if not $db -}}
    {{- fail "Must provide the name of the database to use in configuration.db.dialect" -}}
  {{- end -}}
  {{- if not (kindIs "string" $db) -}}
    {{- $db = toString $db -}}
  {{- end -}}
  {{- $db = lower $db -}}

  {{- $dbInfo := .Files.Get "dbinfo.yaml" -}}
  {{- if not $dbInfo -}}
    {{- fail "No database configuration file found (dbinfo.yaml) - cannot continue" -}}
  {{- end -}}
  {{- $dbInfo = ($dbInfo | fromYaml ) -}}
  {{- range $key, $db := $dbInfo -}}
    {{- if hasKey $db "aliases" -}}
      {{- range $alias := $db.aliases -}}
        {{- $dbInfo = set $dbInfo $alias $db -}}
      {{- end -}}
    {{- end -}}
    {{- $dbInfo = set $dbInfo $key $db -}}
  {{- end -}}

  {{- if not (hasKey $dbInfo $db) -}}
    {{- fail (printf "Unsupported database type '%s' - must be one of %s" $db (keys $dbInfo | sortAlpha)) -}}
  {{- end -}}

  {{- get $dbInfo $db | toYaml -}}
{{- end -}}

{{- define "arkcase.jdbc.driver" -}}
  {{- if not (kindIs "map" .) -}}
    {{- fail "The parameter must be a map" -}}
  {{- end -}}
  {{- $ctx := . -}}
  {{- if hasKey . "ctx" -}}
    {{- $ctx = .ctx -}}
  {{- end -}}
  {{- if not (kindIs "map" $ctx) -}}
    {{- fail "The context given (either the parameter map, or the 'ctx' value within) must be a map" -}}
  {{- end -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The context given (either the parameter map, or the 'ctx' value within) is not the top-level context" -}}
  {{- end -}}

  {{- $dbInfo := ((include "arkcase.db.info" $ctx) | fromYaml) -}}
  {{- $dbInfo.jdbc.driver -}}
{{- end -}}

{{- define "arkcase.jdbc.param" -}}
  {{- if not (kindIs "map" .) -}}
    {{- fail "The parameter must be a map" -}}
  {{- end -}}
  {{- if not (hasKey . "ctx") -}}
    {{- fail "Must provide the root context as the 'ctx' parameter value" -}}
  {{- end -}}
  {{- $ctx := .ctx -}}
  {{- if not (kindIs "map" $ctx) -}}
    {{- fail "The context given ('ctx' parameter) must be a map" -}}
  {{- end -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The context given (either the parameter map, or the 'ctx' value within) is not the top-level context" -}}
  {{- end -}}

  {{- if not .param -}}
    {{- fail "Must provide a 'param' parameter to indicate which value to fetch" -}}
  {{- end -}}
  {{- $param := .param | toString -}}

  {{- $jdbc := (($ctx.Values.configuration).jdbc | default dict) -}}
  {{- if .target -}}
    {{- $target := .target | toString -}}
    {{- if not (hasKey $jdbc $target) -}}
      {{- fail (printf "No JDBC instance named '%s' - must be one of %s" $target (keys $jdbc | sortAlpha)) -}}
    {{- end -}}
    {{- $jdbc = get $jdbc $target -}}
  {{- end -}}

  {{- $value := "" -}}
  {{- if (hasKey $jdbc $param) -}}
    {{- $value = (get $jdbc $param) -}}
  {{- else if hasKey $ctx.Values.configuration.db $param -}}
    {{- $value = (get $ctx.Values.configuration.db $param) -}}
  {{- end -}}

  {{- $value -}}
{{- end -}}

{{- define "arkcase.jdbc.url" -}}
  {{- if not (kindIs "map" .) -}}
    {{- fail "The parameter must be a map" -}}
  {{- end -}}
  {{- $ctx := . -}}
  {{- $target := "" -}}
  {{- if (hasKey . "ctx") -}}
    {{- $ctx = .ctx -}}
    {{- if not (kindIs "map" $ctx) -}}
      {{- fail "The context given ('ctx' parameter) must be a map" -}}
    {{- end -}}
    {{- if (hasKey . "target") -}}
      {{- $target = .target -}}
    {{- end -}}
  {{- end -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The context given (either the parameter map, or the 'ctx' value within) is not the top-level context" -}}
  {{- end -}}

  {{- $param := (dict "ctx" $ctx) -}}
  {{- if $target -}}
    {{- $param = set $param "target" $target -}}
  {{- end -}}

  {{- $database := (include "arkcase.jdbc.param" (set $param "param" "database")) -}}
  {{- $instance := (include "arkcase.jdbc.param" (set $param "param" "instance")) -}}

  {{- $dbInfo := ((include "arkcase.db.info" $ctx) | fromYaml) -}}
  {{- $data := mustDeepCopy $ctx.Values.configuration.db -}}

  {{- if not (hasKey $data "hostname") -}}
    {{- fail "Must provide the server name in the 'hostname' parameter value" -}}
  {{- end -}}
  {{- if not (kindIs "string" $data.hostname) -}}
    {{- fail "The 'hostname' parameter must be a string" -}}
  {{- end -}}
  {{- if not ($data.hostname) -}}
    {{- fail "The 'hostname' parameter may not be an empty string" -}}
  {{- end -}}
  {{- /* TODO: Check that it's a valid hostname */ -}}

  {{- if and ($instance) ($dbInfo.jdbc.instance) -}}
    {{- $instance = ($dbInfo.jdbc.instance | replace "${INSTANCE}" $instance) -}}
  {{- end -}}

  {{- $format := $dbInfo.jdbc.format -}}
  {{- /* Output the result */ -}}
  {{-
    $format
      | replace "${HOSTNAME}" ($data.hostname | toString)
      | replace "${PORT}" ($data.port | toString)
      | replace "${DATABASE}" ($database | toString)
      | replace "${INSTANCE}" ($instance | toString)
  -}}
{{- end -}}

{{- define "arkcase.jdbc.username" -}}
  {{- if not (kindIs "map" .) -}}
    {{- fail "The parameter must be a map" -}}
  {{- end -}}
  {{- $ctx := . -}}
  {{- $target := "" -}}
  {{- if (hasKey . "ctx") -}}
    {{- $ctx = .ctx -}}
    {{- if not (kindIs "map" $ctx) -}}
      {{- fail "The context given ('ctx' parameter) must be a map" -}}
    {{- end -}}
    {{- if (hasKey . "target") -}}
      {{- $target = .target -}}
    {{- end -}}
  {{- end -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The context given (either the parameter map, or the 'ctx' value within) is not the top-level context" -}}
  {{- end -}}

  {{- $param := (dict "ctx" $ctx) -}}
  {{- if $target -}}
    {{- $param = set $param "target" $target -}}
  {{- end -}}

  {{- include "arkcase.jdbc.param" (set $param "param" "username") -}}
{{- end -}}

{{- define "arkcase.jdbc.password" -}}
  {{- if not (kindIs "map" .) -}}
    {{- fail "The parameter must be a map" -}}
  {{- end -}}
  {{- $ctx := . -}}
  {{- $target := "" -}}
  {{- if (hasKey . "ctx") -}}
    {{- $ctx = .ctx -}}
    {{- if not (kindIs "map" $ctx) -}}
      {{- fail "The context given ('ctx' parameter) must be a map" -}}
    {{- end -}}
    {{- if (hasKey . "target") -}}
      {{- $target = .target -}}
    {{- end -}}
  {{- end -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The context given (either the parameter map, or the 'ctx' value within) is not the top-level context" -}}
  {{- end -}}

  {{- $param := (dict "ctx" $ctx) -}}
  {{- if $target -}}
    {{- $param = set $param "target" $target -}}
  {{- end -}}

  {{- include "arkcase.jdbc.param" (set $param "param" "password") -}}
{{- end -}}
