{{- define "arkcase.analytics.external" -}}
  {{- $hostname := (include "arkcase.tools.conf" (dict "ctx" $ "value" "analytics.hostname" "detailed" true) | fromYaml) -}}
  {{- if and $hostname $hostname.global -}}
    {{- true -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.analytics.compute" -}}
  {{- $ctx := . -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The parameter given must be the root context (. or $)" -}}
  {{- end -}}

  {{- $local := (($ctx.Values.configuration).analytics | default dict) -}}

  {{- $global := (($ctx.Values.global).conf).analytics -}}
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
      {{- $global = set $global "analytics" dict -}}
    {{- end -}}
    {{- $global = $global.analytics -}}
  {{- end -}}

  {{- $conf := deepCopy $local | merge $global -}}

  {{- /* Make sure there's a hostname */ -}}
  {{- if not (hasKey $conf "hostname") -}}
    {{- fail "Must provide the server name in the 'hostname' configuration value" -}}
  {{- end -}}
  {{- if not (kindIs "string" $conf.hostname) -}}
    {{- fail "The 'hostname' parameter must be a string" -}}
  {{- end -}}
  {{- if not (include "arkcase.tools.checkHostname" $conf.hostname) -}}
    {{- fail (printf "The hostname '%s' is not a valid RFC-1123 hostname" $conf.hostname) -}}
  {{- end -}}

  {{- /* Make sure there's a valid port */ -}}
  {{- if not (hasKey $conf "port") -}}
    {{- fail "Must provide the port number in the 'port' configuration value" -}}
  {{- end -}}
  {{- $port := ($conf.port | default "" | toString) -}}
  {{- if not (regexMatch "^[1-9][0-9]*" $port) -}}
    {{- fail (printf "The port number [%s] is not valid" ($port | toString)) -}}
  {{- end -}}
  {{- $port = atoi $port -}}
  {{- if or (lt $port 1) (gt $port 65536) -}}
    {{- fail (printf "The port number [%d] is not in the acceptable range of [1..65535]" $port) -}}
  {{- end -}}
  {{- $conf = set $conf "port" $port -}}

  {{- /* Make sure there's a valid port */ -}}
  {{- if not (hasKey $conf "browser") -}}
    {{- $conf = set $conf "browser" 7474 -}}
  {{- end -}}
  {{- $port = ($conf.browser | default "" | toString) -}}
  {{- if not (regexMatch "^[1-9][0-9]*" $port) -}}
    {{- fail (printf "The browser port number [%s] is not valid" ($port | toString)) -}}
  {{- end -}}
  {{- $port = atoi $port -}}
  {{- if or (lt $port 1) (gt $port 65536) -}}
    {{- fail (printf "The browser port number [%d] is not in the acceptable range of [1..65535]" $port) -}}
  {{- end -}}
  {{- $conf = set $conf "browser" $port -}}

  {{- /* Make sure we remove the rest of the crud */ -}}
  {{- $conf = pick $conf "hostname" "database" "username" "password" "port" "browser" "routing" "ssl" "jdbcFlags" -}}

  {{- $jdbcDriver := "" -}}
  {{- if (hasKey $conf "driver") -}}
    {{- $jdbcDriver = $conf.driver -}}
  {{- end -}}
  {{- if or (not $jdbcDriver) (not (kindIs "string" $jdbcDriver)) -}}
    {{- $jdbcDriver = "org.neo4j.jdbc.Driver" -}}
  {{- end -}}

  {{- if (hasKey $conf "username") -}}
    {{- $conf = set $conf "username" $conf.username -}}
  {{- end -}}
  {{- if or (not $conf.username) (not (kindIs "string" $conf.username)) -}}
    {{- $conf = set $conf "username" "neo4j" -}}
  {{- end -}}

  {{- if (hasKey $conf "database") -}}
    {{- $conf = set $conf "database" $conf.database -}}
  {{- end -}}
  {{- if or (not $conf.database) (not (kindIs "string" $conf.database)) -}}
    {{- $conf = set $conf "database" "neo4j" -}}
  {{- end -}}

  {{- if (hasKey $conf "password") -}}
    {{- $conf = set $conf "password" $conf.password -}}
  {{- end -}}
  {{- if or (not $conf.password) (not (kindIs "string" $conf.password)) -}}
    {{- fail "Must provide a password to access the Neo4J instance with" -}}
  {{- end -}}

  {{- $conf = set $conf "ssl" (not (empty (include "arkcase.toBoolean" $conf.ssl))) -}}

  {{- $jdbcFlags := $conf.jdbcFlags | default dict -}}
  {{- $flags := list -}}
  {{- if $jdbcFlags -}}

    {{- /* If it's a string, it must be the parameters to add at the end of the URL */ -}}
    {{- if (kindIs "string" $jdbcFlags) -}}
      {{- $jdbcFlags = splitList "&" $jdbcFlags -}}
    {{- end -}}

    {{- /* The same parameters, but in list form */ -}}
    {{- if (kindIs "slice" $jdbcFlags) -}}
      {{- /* Parse the query string ... split on all instances of &, decode and re-encode all values */ -}}
      {{- range $kv := $jdbcFlags -}}
        {{- if regexMatch "^[^=]+=.*$" $kv -}}
          {{- $key := regexReplaceAll "^([^=]+)=.*$" $kv "${1}" -}}
          {{- $val := regexReplaceAll "^[^=]+=(.*)$" $kv "${1}" -}}
          {{- $flags = append $flags (printf "%s=%s" (urlquery $key) (urlquery $val)) -}}
        {{- else -}}
          {{- $flags = append $flags (urlquery $kv) -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}

    {{- /* The parameters as a map */ -}}
    {{- if (kindIs "map" $jdbcFlags) -}}
      {{- $nullKind := (kindOf (get $conf (printf ":%s:%s:" (uuidv4 | toString) (randAlphaNum 32)))) -}}
      {{- $flags := list -}}
      {{- range $k, $v := $jdbcFlags -}}
        {{- if (empty $v) -}}
          {{- if or (kindIs "map" $v) (kindIs "slice" $v) -}}
            {{- /* If the value is an empty map or list, it's a value-less key */ -}}
            {{- $flags = append $flags $k -}}
            {{- /* This assignment avoids double-values */ -}}
            {{- $k = "" -}}
          {{- else if not (kindIs "string" $v) -}}
            {{- /* Check to see if it's a null-value */ -}}
            {{- if (kindIs $nullKind $v) -}}
              {{- $v = "" -}}
            {{- else -}}
              {{- $v = (toString $v) -}}
            {{- end -}}
          {{- end -}}
        {{- else if not (kindIs "string" $v) -}}
          {{- /* If it's a non-empty value that isn't a string, toString! */ -}}
          {{- $v = (toString $v) -}}
        {{- end -}}
        {{- if $k -}}
          {{- $flags = append $flags (printf "%s=%s" (urlquery $k) (urlquery $v)) -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}

    {{- /* Now join it all */ -}}
  {{- end -}}

  {{- /* If we're given a routing policy explicitly, this supersedes the one(s) in the flags */ -}}
  {{- if and $conf.routing (kindIs "string" $conf.routing) -}}
    {{- $newFlags := list (printf "routing:policy=%s" (urlquery $conf.routing)) -}}
    {{- range $kv := $flags -}}
      {{- if (not (regexMatch "^routing:[^=]+=" $kv)) -}}
        {{- $newFlags = append $newFlags $kv -}}
      {{- end -}}
    {{- end -}}
    {{- $flags = $newFlags -}}
  {{- else -}}
    {{- $conf = unset $conf "routing" -}}
  {{- end -}}

  {{- if not $conf.ssl -}}
    {{- $flags = append $flags "nossl" -}}
  {{- end -}}

  {{- /* Finally, render the JDBC flags */ -}}
  {{- $jdbcFlags = join "&" $flags -}}
  {{- if $jdbcFlags -}}
    {{- $jdbcFlags = (printf "?%s" $jdbcFlags) -}}
  {{- end -}}

  {{-
    $conf = set $conf "jdbc" (
      dict
        "driver" $jdbcDriver
        "url"    (printf "jdbc:neo4j:bolt%s://%s:%d%s" ((not (empty $conf.routing)) | ternary "+routing" "") $conf.hostname $conf.port $jdbcFlags)
    )
  -}}

  {{- /* Output the result */ -}}
  {{- $conf | toYaml -}}
{{- end -}}

{{- define "arkcase.analytics" -}}
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

  {{- $cacheKey := "AnalyticsInfo" -}}
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
    {{- $yamlResult = (include "arkcase.analytics.compute" $ctx) -}}
    {{- $masterCache = set $masterCache $chartName ($yamlResult | fromYaml) -}}
  {{- else -}}
    {{- $yamlResult = get $masterCache $chartName | toYaml -}}
  {{- end -}}
  {{- $yamlResult -}}
{{- end -}}
