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

    {{- $name = (printf "%s_TYPE" $prefix) -}}
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

{{- /* We use a specific, static value to ensure the same name is used all over */ -}}
{{- define "arkcase.pentaho.acm3ds" -}}
acm3DataSource
{{- end -}}

{{- define "__arkcase.pentaho.extraDataSources.compute" -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The parameter given must be the root context (. or $)" -}}
  {{- end -}}

  {{- $subsysName := (include "arkcase.subsystem.name" $ctx) -}}

  {{- /* global.subsys.reports.settings.dataSources ... */ -}}
  {{- $dataSources := (dig "subsys" $subsysName "settings" "dataSources" dict ($ctx.Values.global | default dict)) -}}
  {{- if not (kindIs "map" $dataSources) -}}
    {{- $dataSources = dict -}}
  {{- end -}}

  {{-
    $reserved := (
      list
        (include "arkcase.pentaho.acm3ds" $ctx)
        "Hibernate"
        "Audit"
        "Quartz"
        "PDI_Operations_Mart"
        "pentaho_operations_mart"
        "live_logging_info"
        "jackrabbit"
    )
  -}}

  {{- $regex := "[^a-zA-Z0-9_]" -}}
  {{- $result := dict -}}
  {{- range $name, $info := $dataSources -}}
    {{- $ds := dict "name" $name -}}

    {{- /* Allow for the datasources to be disabled */ -}}
    {{- if not (include "arkcase.toBoolean" (hasKey $info "enabled" | ternary $info.enabled true | toString)) -}}
      {{- continue -}}
    {{- end -}}

    {{- if (has $name $reserved) -}}
      {{- fail (printf "The data source name [%s] conflicts with one of the reserved data source names: %s" $name $reserved) -}}
    {{- end -}}

    {{- $ds = set $ds "var" (regexReplaceAllLiteral $regex $name "_" | snakecase | upper) -}}

    {{- if not (kindIs "map" $info) -}}
      {{- fail (printf "The dataSource definition [%s] must be a map describing the connection." $name) -}}
    {{- end -}}

    {{- if not (hasKey $info "secret") -}}
      {{- fail (printf "The dataSource definition [%s] does not contain a secret name." $name) -}}
    {{- end -}}
    {{- $secret := ($info.secret | default "" | toString) -}}
    {{- if not (include "arkcase.tools.hostnamePart" $secret) -}}
      {{- fail (printf "The dataSource definition [%s] contains an invalid secret name: [%s]" $name $secret) -}}
    {{- end -}}
    {{- $ds = set $ds "secret" $secret -}}

    {{- if not (hasKey $info "dialect") -}}
      {{- fail (printf "The dataSource definition [%s] does not contain a database dialect." $name) -}}
    {{- end -}}
    {{- $dialect := ($info.dialect | default "" | toString) -}}
    {{- $db := (include "arkcase.db.info" (dict "ctx" $ctx "dialect" $dialect)) -}}
    {{- /* No need to parse the YAML, the template will explode if a bad dialect is given */ -}}
    {{- $ds = set $ds "dialect" $dialect -}}

    {{- $mappings := ($info.mappings | default dict) -}}
    {{- if not (kindIs "map" $mappings) -}}
      {{- $mappings = dict -}}
    {{- end -}}
    {{- $ds = set $ds "mappings" (pick $mappings "endpoint" "port" "database" "username" "password") -}}

    {{- $result = set $result $name $ds -}}
  {{- end -}}

  {{- $result | toYaml -}}
{{- end -}}

{{- define "arkcase.pentaho.extraDataSources" -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The parameter must be the root context ($ or .)" -}}
  {{- end -}}

  {{- $args :=
    dict
      "ctx" $ctx
      "template" "__arkcase.pentaho.extraDataSources.compute"
  -}}
  {{- include "__arkcase.tools.getCachedValue" $args -}}
{{- end -}}

{{- define "arkcase.pentaho.extraDataSources.context-xml" -}}
  {{- $customDataSources := (include "arkcase.pentaho.extraDataSources" $ | fromYaml) -}}
  {{- range $dataSourceName := (keys $customDataSources | sortAlpha) }}
    {{- $ds := get $customDataSources $dataSourceName }}
<Resource name="jdbc/{{ $dataSourceName }}" auth="Container" type="javax.sql.DataSource"
          factory="org.pentaho.di.core.database.util.DecryptingDataSourceFactory"
          driverClassName="${REPORTS_EXTRA_JDBC_{{ $ds.var }}_DRIVER}"
          initialSize="0"
          maxActive="20"
          maxIdle="5"
          maxWait="10000"
          minIdle="0"
          password="${REPORTS_EXTRA_JDBC_{{ $ds.var }}_PASSWORD}"
          testOnBorrow="true"
          url="${REPORTS_EXTRA_JDBC_{{ $ds.var }}_URL}"
          username="${REPORTS_EXTRA_JDBC_{{ $ds.var }}_USERNAME}"
          validationQuery="${REPORTS_EXTRA_JDBC_{{ $ds.var }}_VALIDATION_QUERY}"
          />
  {{- end }}
{{- end -}}

{{- define "arkcase.pentaho.extraDataSources.env" -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The 'ctx' parameter given must be the root context (. or $)" -}}
  {{- end -}}

  {{- $result := list -}}
  {{- $customDataSources := (include "arkcase.pentaho.extraDataSources" $ | fromYaml) -}}
  {{- range $dataSourceName := (keys $customDataSources | sortAlpha) }}
    {{- $ds := get $customDataSources $dataSourceName -}}

    {{- $prefix := (printf "REPORTS_EXTRA_JDBC_%s" $ds.var) -}}
    {{- $replacement := (printf "$(%s_" $prefix) -}}

    {{- $name := "" -}}
    {{- $key := "" -}}
    {{- $value := "" -}}

    {{- $secretKeyRef := (dict "name" $ds.secret "optional" false) -}}

    {{- $mappings := $ds.mappings -}}

    {{- /* These go straight to the target secret */ -}}
    {{- $name = (printf "%s_HOST" $prefix) -}}
    {{- $key = "endpoint" -}}
    {{- $key = (hasKey $mappings $key | ternary (get $mappings $key) $key | default $key | toString) -}}
    {{- $value = (dict "secretKeyRef" (merge (dict "key" $key) $secretKeyRef)) -}}
    {{- $result = append $result (dict "name" $name "valueFrom" $value) -}}

    {{- $name = (printf "%s_PORT" $prefix) -}}
    {{- $key = "port" -}}
    {{- $key = (hasKey $mappings $key | ternary (get $mappings $key) $key | default $key | toString) -}}
    {{- $value = (dict "secretKeyRef" (merge (dict "key" $key) $secretKeyRef)) -}}
    {{- $result = append $result (dict "name" $name "valueFrom" $value) -}}

    {{- $name = (printf "%s_DATABASE" $prefix) -}}
    {{- $key = "database" -}}
    {{- $key = (hasKey $mappings $key | ternary (get $mappings $key) $key | default $key | toString) -}}
    {{- $value = (dict "secretKeyRef" (merge (dict "key" $key) $secretKeyRef)) -}}
    {{- $result = append $result (dict "name" $name "valueFrom" $value) -}}

    {{- $name = (printf "%s_USERNAME" $prefix) -}}
    {{- $key = "username" -}}
    {{- $key = (hasKey $mappings $key | ternary (get $mappings $key) $key | default $key | toString) -}}
    {{- $value = (dict "secretKeyRef" (merge (dict "key" $key) $secretKeyRef)) -}}
    {{- $result = append $result (dict "name" $name "valueFrom" $value) -}}

    {{- $name = (printf "%s_PASSWORD" $prefix) -}}
    {{- $key = "password" -}}
    {{- $key = (hasKey $mappings $key | ternary (get $mappings $key) $key | default $key | toString) -}}
    {{- $value = (dict "secretKeyRef" (merge (dict "key" $key) $secretKeyRef)) -}}
    {{- $result = append $result (dict "name" $name "valueFrom" $value) -}}

    {{- /* These are rendered from the DB config */ -}}
    {{- $db := (include "arkcase.db.info" (dict "ctx" $ctx "dialect" $ds.dialect) | fromYaml) -}}

    {{- $name = (printf "%s_DIALECT" $prefix) -}}
    {{- $value = ($db.dialect | default "" | toString | upper | replace "$(PREFIX_" $replacement) -}}
    {{- $result = append $result (dict "name" $name "value" $value) -}}

    {{- $name = (printf "%s_TYPE" $prefix) -}}
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
