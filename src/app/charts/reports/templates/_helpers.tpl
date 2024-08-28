{{- define "arkcase.pentaho.jcr.fileSystem" -}}
  {{- $ctx := $.ctx -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The 'ctx' parameter given must be the root context (. or $)" -}}
  {{- end -}}
  {{- $prefix := required "Must provide the 'prefix' parameter" $.prefix -}}
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

{{- define "arkcase.pentaho.serverUrl" -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The 'ctx' parameter given must be the root context (. or $)" -}}
  {{- end -}}

  {{- $serverUrl := "https://reports:8443/pentaho" -}}
  {{- $baseUrl := (include "arkcase.tools.conf" (dict "ctx" $ctx "value" "baseUrl") | toString) -}}
  {{- if $baseUrl -}}
    {{- $baseUrl = ((include "arkcase.tools.parseUrl" $baseUrl) | fromYaml) -}}
    {{- if (ne "https" ($baseUrl.scheme | lower)) -}}
      {{- fail (printf "The baseUrl must be an https:// URL - [%s]" $baseUrl) -}}
    {{- end -}}

    {{- $ingress := ($ctx.Values.global.ingress | default dict) -}}
    {{- $ingress = (kindIs "map" $ingress) | ternary $ingress dict -}}
    {{- $enabled := or (not (hasKey $ingress "enabled")) (not (empty (include "arkcase.toBoolean" $ingress.enabled))) -}}
    {{- $dev := (include "arkcase.dev" $ | fromYaml) -}}
    {{- if and $enabled $dev $ingress.reports -}}
      {{- $serverUrl = (printf "%s://%s/pentaho" $baseUrl.scheme $baseUrl.host) -}}
    {{- end -}}
  {{- end -}}
  {{- $serverUrl -}}
{{- end -}}

{{- define "arkcase.pentaho.jdbc-urls" -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The 'ctx' parameter given must be the root context (. or $)" -}}
  {{- end -}}

  {{- $result := list -}}
  {{- $db := (include "arkcase.db.info" $ctx | fromYaml) -}}
  {{- range $schema := (list "arkcase" "hibernate" "jackrabbit" "quartz") -}}
    {{- $prefix := (printf "REPORTS_JDBC_%s" ($schema | upper)) -}}
    {{- $replacement := (printf "$(%s_" $prefix) -}}

    {{- $name := "" -}}
    {{- $value := "" -}}

    {{- $name = (printf "%s_DIALECT" $prefix) -}}
    {{- $value = ($db.dialect | default "" | toString | upper | replace "$(PREFIX_" $replacement) -}}
    {{- $result = append $result (dict "name" $name "value" $value) -}}

    {{- $name = (printf "%s_DBTYPE" $prefix) -}}
    {{- $value = ($db.databaseType | default "" | toString | upper | replace "$(PREFIX_" $replacement) -}}
    {{- $result = append $result (dict "name" $name "value" $value) -}}

    {{- $name = (printf "%s_URL" $prefix) -}}
    {{- $value = ($db.jdbc.url | default "" | toString | replace "$(PREFIX_" $replacement) -}}
    {{- $result = append $result (dict "name" $name "value" $value) -}}

    {{- $name = (printf "%s_DRIVER" $prefix) -}}
    {{- $value = ($db.jdbc.driver | default "" | toString | replace "$(PREFIX_" $replacement) -}}
    {{- $result = append $result (dict "name" $name "value" $value) -}}

    {{- $value = ($db.validationQuery | default "" | toString | replace "$(PREFIX_" $replacement) -}}
    {{- if $value -}}
      {{- $name = (printf "%s_VALIDATION_QUERY" $prefix) -}}
      {{- $result = append $result (dict "name" $name "value" $value) -}}
    {{- end -}}
  {{- end -}}
  {{- if $result -}}
    {{- $result | toYaml -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.pentaho.acm3ds" -}}
acm3DataSource
{{- end -}}
