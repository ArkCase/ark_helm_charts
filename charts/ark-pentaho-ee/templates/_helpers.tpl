{{- define "arkcase.pentaho.datasource.params" -}}
  {{- $ctx := . -}}
  {{- if or (not $ctx) (not (kindIs "map" $ctx)) -}}
    {{- $ctx = dict -}}
  {{- end -}}
{{- /* This isn't indented to make it easier to render it properly */ -}}
{{- range $key, $value := $ctx -}}
{{ $key }}="{{ $value }}"
{{ end -}}
{{- /* End unindented block */ -}}
{{- end -}}

{{- define "arkcase.pentaho.db.info" -}}
  {{- $db := (required "Must configure the value for configuration.db.dialect" ((.Values.configuration).db).dialect) -}}
  {{- if not $db -}}
    {{- fail "Must provide the name of the database to use in configuration.db.dialect" -}}
  {{- end -}}
  {{- if not (kindIs "string" $db) -}}
    {{- $db = toString $db -}}
  {{- end -}}
  {{- $db = lower $db -}}

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

  {{- if not (hasKey $dbInfo $db) -}}
    {{- fail (printf "Unsupported database type '%s' - must be one of %s" $db (keys $dbInfo | sortAlpha)) -}}
  {{- end -}}

  {{- get $dbInfo $db | toYaml -}}
{{- end -}}

{{- define "arkcase.pentaho.db.dialect" -}}
  {{- get ((include "arkcase.pentaho.db.info" .) | fromYaml) "dialect" -}}
{{- end -}}

{{- define "arkcase.pentaho.db.scripts" -}}
  {{- get ((include "arkcase.pentaho.db.info" .) | fromYaml) "scripts" -}}
{{- end -}}

{{- define "arkcase.pentaho.quartz.delegateClass" -}}
  {{- get ((include "arkcase.pentaho.db.info" .) | fromYaml) "quartz" -}}
{{- end -}}

{{- define "arkcase.pentaho.jcr.fileSystem" -}}
  {{- $ctx := required "Must provide the 'ctx' parameter" .ctx -}}
  {{- if not (kindIs "map" $ctx) -}}
    {{- fail "The 'ctx' parameter must be the root map (i.e. $ or .)" -}}
  {{- end -}}
  {{- $prefix := required "Must provide the 'prefix' parameter" .prefix -}}
  {{- if not (kindIs "string" $prefix) -}}
    {{- fail "The 'prefix' parameter must be a string" -}}
  {{- end -}}
  {{- $dbInfo := ((include "arkcase.pentaho.db.info" $ctx) | fromYaml) -}}
  {{- $fsClass := "Db" -}}
  {{- $schema := coalesce $dbInfo.jcr $dbInfo.jdbc.type -}}
  {{- if eq $schema "oracle" -}}
    {{- $fsClass = "Oracle" -}}
  {{- else if eq $schema "mssql" -}}
    {{- $fsClass = "MSSql" -}}
  {{- end -}}
<FileSystem class="{{ printf "org.apache.jackrabbit.core.fs.db.%sFileSystem" $fsClass }}">
  <param name="driver" value="javax.naming.InitialContext"/>
  <param name="url" value="java:comp/env/jdbc/jackrabbit"/>
  <param name="schema" value="{{ $schema }}"/>
  <param name="schemaObjectPrefix" value="{{ $prefix }}"/>
</FileSystem>
{{- end -}}

{{- define "arkcase.pentaho.jcr.dataStore" -}}
  {{- $ctx := required "Must provide the 'ctx' parameter" .ctx -}}
  {{- if not (kindIs "map" $ctx) -}}
    {{- fail "The 'ctx' parameter must be the root map (i.e. $ or .)" -}}
  {{- end -}}
  {{- $prefix := required "Must provide the 'prefix' parameter" .prefix -}}
  {{- if not (kindIs "string" $prefix) -}}
    {{- fail "The 'prefix' parameter must be a string" -}}
  {{- end -}}
  {{- $dbInfo := ((include "arkcase.pentaho.db.info" $ctx) | fromYaml) -}}
  {{- $schema := coalesce $dbInfo.jcr $dbInfo.jdbc.type -}}
<DataStore class="org.apache.jackrabbit.core.data.db.DbDataStore">
  <param name="driver" value="javax.naming.InitialContext"/>
  <param name="url" value="java:comp/env/jdbc/jackrabbit"/>
  <param name="databaseType" value="{{ $schema }}"/>
  <param name="minRecordLength" value="1024"/>
  <param name="maxConnections" value="3"/>
  <param name="copyWhenReading" value="true"/>
  <param name="tablePrefix" value=""/>
  <param name="schemaObjectPrefix" value="{{ $prefix }}"/>
</DataStore>
{{- end -}}

{{- define "arkcase.pentaho.jcr.persistenceManager" -}}
  {{- $ctx := required "Must provide the 'ctx' parameter" .ctx -}}
  {{- if not (kindIs "map" $ctx) -}}
    {{- fail "The 'ctx' parameter must be the root map (i.e. $ or .)" -}}
  {{- end -}}
  {{- $prefix := required "Must provide the 'prefix' parameter" .prefix -}}
  {{- if not (kindIs "string" $prefix) -}}
    {{- fail "The 'prefix' parameter must be a string" -}}
  {{- end -}}
  {{- $dbInfo := ((include "arkcase.pentaho.db.info" $ctx) | fromYaml) -}}
  {{- $pmClass := "Db" -}}
  {{- $schema := coalesce $dbInfo.jcr $dbInfo.jdbc.type -}}
  {{- if eq $schema "oracle" -}}
    {{- $pmClass = "Oracle" -}}
  {{- else if eq $schema "mssql" -}}
    {{- $pmClass = "MSSql" -}}
  {{- else if eq $schema "mysql" -}}
    {{- $pmClass = "MySql" -}}
  {{- else if eq $schema "postgresql" -}}
    {{- $pmClass = "PostgreSQL" -}}
  {{- else -}}
    {{- fail (printf "Unrecognized JCR schema type '%s'" $schema) -}}
  {{- end -}}
<PersistenceManager class="{{ printf "org.apache.jackrabbit.core.persistence.bundle.%sPersistenceManager" $pmClass }}">
  <param name="driver" value="javax.naming.InitialContext"/>
  <param name="url" value="java:comp/env/jdbc/jackrabbit"/>
  <param name="schema" value="{{ $schema }}"/>
  <param name="schemaObjectPrefix" value="{{ $prefix }}"/>
</PersistenceManager>
{{- end -}}

{{- define "arkcase.pentaho.jcr.journal" -}}
  {{- $ctx := required "Must provide the 'ctx' parameter" .ctx -}}
  {{- if not (kindIs "map" $ctx) -}}
    {{- fail "The 'ctx' parameter must be the root map (i.e. $ or .)" -}}
  {{- end -}}
  {{- $type := required "Must provide the 'type' parameter" .type -}}
  {{- if not (kindIs "string" $type) -}}
    {{- fail "The 'type' parameter must be a string" -}}
  {{- end -}}
  {{- $type = lower $type -}}
  {{- if or (eq $type "mem") (eq $type "memory") -}}
<Journal class="org.apache.jackrabbit.core.journal.MemoryJournal"/>
  {{- else -}}
    {{- $dbInfo := ((include "arkcase.pentaho.db.info" $ctx) | fromYaml) -}}
    {{- $schema := coalesce $dbInfo.jcr $dbInfo.jdbc.type -}}
<Journal class="org.apache.jackrabbit.core.journal.DatabaseJournal">
  <param name="revision" value="${rep.home}/revision.log" />
  <param name="driver" value="javax.naming.InitialContext"/>
  <param name="url" value="java:comp/env/jdbc/jackrabbit"/>
  <param name="schema" value="{{ $schema }}"/>
  <param name="schemaObjectPrefix" value="cl_j_"/>
  <param name="janitorEnabled" value="true"/>
  <param name="janitorSleep" value="86400"/>
  <param name="janitorFirstRunHourOfDay" value="3"/>
</Journal>
  {{- end -}}
{{- end -}}

{{- define "arkcase.pentaho.jdbc.driver" -}}
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
  {{- if or (not (hasKey $ctx "Values")) (not (hasKey $ctx "Chart")) (not (hasKey $ctx "Release")) -}}
    {{- fail "The context given (either the parameter map, or the 'ctx' value within) is not the top-level context" -}}
  {{- end -}}

  {{- $dbInfo := ((include "arkcase.pentaho.db.info" $ctx) | fromYaml) -}}
  {{- $dbInfo.jdbc.driver -}}
{{- end -}}

{{- define "arkcase.pentaho.jdbc.param" -}}
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
  {{- if or (not (hasKey $ctx "Values")) (not (hasKey $ctx "Chart")) (not (hasKey $ctx "Release")) -}}
    {{- fail "The context given (either the parameter map, or the 'ctx' value within) is not the top-level context" -}}
  {{- end -}}

  {{- if not .target -}}
    {{- fail "Must provide a 'target' parameter to indicate which parameter to fetch" -}}
  {{- end -}}
  {{- $target := .target | toString -}}

  {{- if not .param -}}
    {{- fail "Must provide a 'param' parameter to indicate which value to fetch" -}}
  {{- end -}}
  {{- $param := .param | toString -}}

  {{- $jdbc := $ctx.Values.configuration.jdbc -}}
  {{- if not (hasKey $jdbc $target) -}}
    {{- fail (printf "No JDBC instance named '%s' - must be one of %s" $target (keys $jdbc)) -}}
  {{- end -}}

  {{- $jdbc = get $jdbc $target -}}
  {{- $value := "" -}}
  {{- if (hasKey $jdbc $param) -}}
    {{- $value = (get $jdbc $param) -}}
  {{- else if hasKey $ctx.Values.configuration.db $param -}}
    {{- $value = (get $ctx.Values.configuration.db $param) -}}
  {{- end -}}

  {{- $value -}}
{{- end -}}

{{- define "arkcase.pentaho.jdbc.url" -}}
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
  {{- if or (not (hasKey $ctx "Values")) (not (hasKey $ctx "Chart")) (not (hasKey $ctx "Release")) -}}
    {{- fail "The context given (either the parameter map, or the 'ctx' value within) is not the top-level context" -}}
  {{- end -}}

  {{- $database := (include "arkcase.pentaho.jdbc.param" (set . "param" "database")) -}}
  {{- $instance := (include "arkcase.pentaho.jdbc.param" (set . "param" "instance")) -}}

  {{- $dbInfo := ((include "arkcase.pentaho.db.info" $ctx) | fromYaml) -}}
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

  {{- $port := coalesce $data.port $dbInfo.port -}}
  {{- if not $port -}}
    {{- fail (printf "There is no port specification for the database (%s)" $dbInfo.name) -}}
  {{- end -}}
  {{- $data = set $data "port" $port -}}

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

{{- define "arkcase.pentaho.jdbc.username" -}}
  {{- include "arkcase.pentaho.jdbc.param" (set . "param" "username") -}}
{{- end -}}

{{- define "arkcase.pentaho.jdbc.password" -}}
  {{- include "arkcase.pentaho.jdbc.param" (set . "param" "password") -}}
{{- end -}}
