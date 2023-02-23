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

  {{- $mysql := dict "dialect" "mysql5" "jcr" "mysql" "scripts" "mysql" "quartz" "StdJDBCDelegate" -}}
  {{- $oracle := dict "dialect" "oracle10g" "jcr" "oracle" "scripts" "oracle10g" "quartz" "oracle.OracleDelegate" -}}
  {{- $oracle12 := set (omit $oracle "scripts") "scripts" "oracle12c" -}}
  {{- $postgresql := dict "dialect" "postgresql" "jcr" "postgresql" "scripts" "postgresql" "quartz" "PostgreSQLDelegate" -}}
  {{- $sqlserver := dict "dialect" "sqlserver" "jcr" "mssql" "scripts" "sqlserver" "quartz" "MSSQLDelegate" -}}

  {{- /* Now create a map for all the allowed aliases */ -}}
  {{- /* We could do something more complicated above, but it would be much slower and this is enough for now */ -}}
  {{- $mappings := dict "mariadb" $mysql "mysql" $mysql "mysql5" $mysql "mysql8" $mysql "postgresql" $postgresql "psql" $postgresql "orcl" $oracle "orcl10g" $oracle "oracle" $oracle "orcl12" $oracle12 "orcl12c" $oracle12 "oracle12" $oracle12 "oracle12c" $oracle12 "sqlserver" $sqlserver "mssql" $sqlserver -}}

  {{- if not (hasKey $mappings $db) -}}
    {{- fail (printf "Unsupported database type '%s' - must be one of %s" $db (keys $mappings | sortAlpha)) -}}
  {{- end -}}

  {{- get $mappings $db | toYaml -}}
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
  {{- $schema := get $dbInfo "jcr" -}}
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
  {{- $schema := get $dbInfo "jcr" -}}
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
  {{- $schema := get $dbInfo "jcr" -}}
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
