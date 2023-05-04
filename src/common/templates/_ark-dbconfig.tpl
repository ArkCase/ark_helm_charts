{{- define "arkcase.db.external" -}}
  {{- $hostname := (include "arkcase.tools.conf" (dict "ctx" $ "value" "rdbms.hostname" "detailed" true) | fromYaml) -}}
  {{- if and $hostname $hostname.global -}}
    {{- true -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.db.info.compute" -}}
  {{- $ctx := . -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The parameter given must be the root context (. or $)" -}}
  {{- end -}}

  {{- $local := (($ctx.Values.configuration).db | default dict) -}}

  {{- $global := (($ctx.Values.global).conf).rdbms -}}
  {{- if not $global -}}
    {{- /* This small trick helps the init dependencies to not be wasteful */ -}}
    {{- /* because as we "alter" the main map, we also allow initDependencies */ -}}
    {{- /* to only look at the port(s) we're actually interested in for this */ -}}
    {{- /* specific dialect as-configured */ -}}
    {{- $global = $ctx.Values -}}

    {{- if or (not (hasKey $global "global")) (not (kindIs "map" $global.global)) -}}
      {{- $global = set $global "global" dict -}}
    {{- end -}}
    {{- $global = $ctx.Values.global -}}

    {{- if or (not (hasKey $global "conf")) (not (kindIs "map" $global.conf)) -}}
      {{- $global = set $global "conf" dict -}}
    {{- end -}}
    {{- $global = $global.conf -}}

    {{- if or (not (hasKey $global "rdbms")) (not (kindIs "map" $global.rdbms)) -}}
      {{- $global = set $global "rdbms" dict -}}
    {{- end -}}
    {{- $global = $global.rdbms -}}
  {{- end -}}

  {{- $dialect := coalesce $global.dialect $local.dialect -}}
  {{- if not $dialect -}}
    {{- fail "Must provide the name of the database dialect to use in global.conf.rdbms.dialect" -}}
  {{- end -}}

  {{- if not (kindIs "string" $dialect) -}}
    {{- $dialect = toString $dialect -}}
  {{- end -}}
  {{- $dialect = lower $dialect -}}

  {{- /* Step one: load the common database configurations */ -}}
  {{- $dbInfo := (.Files.Get "dbinfo.yaml" | fromYaml ) -}}
  {{- range $key, $db := $dbInfo -}}
    {{- if not (hasKey $db "scripts") -}}
      {{- $db = set $db "scripts" $db.dialect -}}
    {{- end -}}
    {{- if hasKey $db "aliases" -}}
      {{- range $alias := $db.aliases -}}
        {{- $dbInfo = set $dbInfo $alias $db -}}
      {{- end -}}
    {{- end -}}
    {{- $db = set $db "name" $key -}}
    {{- $dbInfo = set $dbInfo $key $db -}}
  {{- end -}}

  {{- if not (hasKey $dbInfo $dialect) -}}
    {{- fail (printf "Unsupported database type '%s' - must be one of %s" $dialect (keys $dbInfo | sortAlpha)) -}}
  {{- end -}}

  {{- /* Step two: merge in the server and schema definitions */ -}}
  {{- $dbInfo = get $dbInfo $dialect -}}
  {{- $dbConf := deepCopy $local | merge $global -}}

  {{- /* Make sure there's a hostname */ -}}
  {{- if not (hasKey $dbConf "hostname") -}}
    {{- fail "Must provide the server name in the 'hostname' configuration value" -}}
  {{- end -}}
  {{- if not (kindIs "string" $dbConf.hostname) -}}
    {{- fail "The 'hostname' parameter must be a string" -}}
  {{- end -}}
  {{- if not (include "arkcase.tools.checkHostname" $dbConf.hostname) -}}
    {{- fail (printf "The hostname '%s' is not a valid RFC-1123 hostname" $dbConf.hostname) -}}
  {{- end -}}

  {{- /* Now we can merge things */ -}}
  {{- $dbConf = merge $dbConf (omit $dbInfo "aliases") -}}

  {{- /* Make sure there's a valid port */ -}}
  {{- if not (hasKey $dbConf "port") -}}
    {{- fail "Must provide the port number in the 'port' configuration value" -}}
  {{- end -}}
  {{- $port := ($dbConf.port | default "" | toString) -}}
  {{- if not (regexMatch "^[1-9][0-9]*" $port) -}}
    {{- fail (printf "The port number [%s] is not valid" ($port | toString)) -}}
  {{- end -}}
  {{- $port = atoi $port -}}
  {{- if or (lt $port 1) (gt $port 65536) -}}
    {{- fail (printf "The port number [%d] is not in the acceptable range of [1..65535]" $port) -}}
  {{- end -}}

  {{- $dbConf = set $dbConf "port" $port -}}

  {{- $debug := list -}}

  {{- $common := omit $dbConf "schema" -}}
  {{- $schemata := get $dbConf "schema" -}}
  {{- if and $schemata (kindIs "map" $schemata) -}}
    {{- $newSchemata := dict -}}
    {{- range $name, $d := $schemata -}}
      {{- if not $name -}}
        {{- fail "The schema symbolic name may not be the empty string" -}}
      {{- end -}}
      {{- $data := dict -}}
      {{- if and $d (kindIs "map" $d) -}}
        {{- /* Sanitize the data */ -}}
        {{- $data = merge (deepCopy $d) $common -}}
      {{- end -}}

      {{- /* Apply default values, in case things weren't properly declared */ -}}
      {{- if or (not (hasKey $data "database")) (not (kindIs "string" $data.database)) (empty $data.database) -}}
        {{- $data = set $data "database" $name -}}
      {{- end -}}
      {{- if or (not (hasKey $data "username")) (not (kindIs "string" $data.username)) (empty $data.username) -}}
        {{- $data = set $data "username" $data.database -}}
      {{- end -}}
      {{- if or (not (hasKey $data "password")) (not (kindIs "string" $data.password)) (empty $data.password) -}}
        {{- $data = set $data "password" (sha1sum $data.username | lower) -}}
      {{- end -}}

      {{- /* Compute the JDBC URL */ -}}
      {{- $jdbc := $data.jdbc -}}
      {{- if and $jdbc (kindIs "map" $jdbc) -}}
        {{- $instance := ($data.instance | default "") -}}
        {{- if and (($dbInfo.jdbc).instance).required (not $instance) -}}
          {{- fail (printf "Database schema configuration for [%s] lacks the required instance name" $name) -}}
        {{- end -}}
        {{- if and $instance (($dbInfo.jdbc).instance).format -}}
          {{- $instance = ((($dbInfo.jdbc).instance).format | replace "${INSTANCE}" $instance) -}}
        {{- end -}}

        {{- $jdbc = set $jdbc "url"
          (
            $dbInfo.jdbc.format
            | replace "${HOSTNAME}" ($data.hostname | toString)
            | replace "${PORT}" ($data.port | toString)
            | replace "${DATABASE}" ($data.database | toString)
            | replace "${INSTANCE}" ($instance | toString)
            | replace "${URL_PARAMETERS}" ($data.urlParameters | toString)
          )
        -}}

        {{- $data = set $data "jdbc" $jdbc -}}
      {{- else -}}
        {{- $data = omit $data "jdbc" -}}
      {{- end -}}

      {{- /* Re-place the sanitized schema */ -}}
      {{- $newSchemata = set $newSchemata $name (deepCopy $data) -}}
    {{- end -}}
    {{- $schemata = $newSchemata -}}
  {{- else -}}
    {{- $schemata = dict -}}
  {{- end -}}
  {{- set $dbConf "schema" $schemata | toYaml -}}
{{- end -}}

{{- define "arkcase.db.info" -}}
  {{- $ctx := . -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The parameter given must be the root context (. or $)" -}}
  {{- end -}}

  {{- /* First things first: do we have any global overrides? */ -}}
  {{- $global := $ctx.Values.global -}}
  {{- if or (not $global) (not (kindIs "map" $global)) -}}
    {{- $global = dict -}}
  {{- end -}}

  {{- /* Now get the local values */ -}}
  {{- $local := $ctx.Values.configuration -}}
  {{- if or (not $local) (not (kindIs "map" $local)) -}}
    {{- $local = dict -}}
  {{- end -}}

  {{- /* The keys on this map are the images in the local repository */ -}}
  {{- $chart := $ctx.Chart.Name -}}
  {{- $data := dict "local" $local "global" $global -}}

  {{- $cacheKey := "DBInfo" -}}
  {{- $masterCache := dict -}}
  {{- if (hasKey $ctx $cacheKey) -}}
    {{- $masterCache = get $ctx $cacheKey -}}
    {{- if and $masterCache (not (kindIs "map" $masterCache)) -}}
      {{- $masterCache = dict -}}
    {{- end -}}
  {{- end -}}
  {{- $ctx = set $ctx $cacheKey $masterCache -}}

  {{- /* We do not use arkcase.fullname b/c we don't want to deal with partnames */ -}}
  {{- $chartName := (include "common.fullname" $ctx) -}}
  {{- $yamlResult := dict -}}
  {{- if not (hasKey $masterCache $chartName) -}}
    {{- $yamlResult = (include "arkcase.db.info.compute" $ctx) -}}
    {{- $masterCache = set $masterCache $chartName ($yamlResult | fromYaml) -}}
  {{- else -}}
    {{- $yamlResult = get $masterCache $chartName | toYaml -}}
  {{- end -}}
  {{- $yamlResult -}}
{{- end -}}

{{- define "arkcase.db.schema" -}}
  {{- $ctx := .ctx -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The 'ctx' parameter given must be the root context (. or $)" -}}
  {{- end -}}

  {{- $schema := .schema -}}
  {{- if or (not $schema) (not (kindIs "string" $schema)) -}}
    {{- fail "The 'schema' parameter must be a string" -}}
  {{- end -}}

  {{- $db := (include "arkcase.db.info" $ctx | fromYaml) -}}
  {{- $schemata := $db.schema -}}
  {{- if not $schemata -}}
    {{- fail "No schemas have been defined in the configuration, cannot continue" -}}
  {{- else if not (hasKey $schemata $schema) -}}
    {{- fail (printf "No schema configuration '%s' was found, only %s" $schema (keys $schemata | sortAlpha)) -}}
  {{- end -}}
  {{- get $schemata $schema | toYaml -}}
{{- end -}}
