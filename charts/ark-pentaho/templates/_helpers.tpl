{{- define "arkcase.pentaho.jcr.fileSystem" -}}
  {{- $ctx := required "Must provide the 'ctx' parameter" .ctx -}}
  {{- if not (kindIs "map" $ctx) -}}
    {{- fail "The 'ctx' parameter must be the root map (i.e. $ or .)" -}}
  {{- end -}}
  {{- $prefix := required "Must provide the 'prefix' parameter" .prefix -}}
  {{- if not (kindIs "string" $prefix) -}}
    {{- fail "The 'prefix' parameter must be a string" -}}
  {{- end -}}
  {{- $dbInfo := ((include "arkcase.db.info" $ctx) | fromYaml) -}}
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
  {{- $dbInfo := ((include "arkcase.db.info" $ctx) | fromYaml) -}}
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
  {{- $dbInfo := ((include "arkcase.db.info" $ctx) | fromYaml) -}}
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
    {{- $dbInfo := ((include "arkcase.db.info" $ctx) | fromYaml) -}}
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
