{{- define "__arkcase.subsystem-access.expand-vars.default-case-upper" -}}
  {{- $ | toString | upper -}}
{{- end -}}

{{- define "__arkcase.subsystem-access.expand-vars.default-case-lower" -}}
  {{- $ | toString | lower -}}
{{- end -}}

{{- define "__arkcase.subsystem-access.expand-vars.default-case" -}}
  {{- $ | toString -}}
{{- end -}}

{{- define "__arkcase.subsystem-access.expand-vars" -}}
  {{- $str := $.str -}}
  {{- $params := $.params -}}
  {{- $regex := ($.regex | default "") -}}
  {{- $replace := ($.replace | default "") -}}
  {{- $hasRegex := (not (empty $regex)) -}}

  {{- $caseTemplate := "__arkcase.subsystem-access.expand-vars.default-case" -}}
  {{- $defaultCase := ($.defaultCase | toString | lower) -}}
  {{- if (regexMatch "^[ul]$" $defaultCase) -}}
    {{- $caseTemplate = (printf "%s-%s" $caseTemplate (eq "u" $defaultCase | ternary "upper" "lower"))  -}}
  {{- end -}}

  {{- range $v := (list "subsys" "conn" "type" "key" "rand-ascii" "rand-alpha-num") -}}

    {{- $value := "" -}}
    {{- if hasPrefix "rand-" $v -}}
      {{- if eq $v "rand-ascii" -}}
        {{- $value = (randAscii 64) -}}
      {{- end -}}
      {{- if eq $v "rand-alpha-num" -}}
        {{- $value = (randAlphaNum 64) -}}
      {{- end -}}
    {{- else -}}
      {{- if not (hasKey $params $v) -}}
        {{- continue -}}
      {{- end -}}
      {{- $value = (get $params $v) -}}
    {{- end -}}

    {{- if not $value -}}
      {{- continue -}}
    {{- end -}}

    {{- $safe := ($hasRegex | ternary (mustRegexReplaceAll $regex $value $replace) $value) -}}
    {{- $str = $str | replace (printf "${%s:l}" $v) ($safe | lower) -}}
    {{- $str = $str | replace (printf "${%s}"   $v) (include $caseTemplate $safe) -}}
    {{- $str = $str | replace (printf "${%s:u}" $v) ($safe | upper) -}}

  {{- end -}}

  {{- $str -}}
{{- end -}}

{{- define "__arkcase.subsystem-access.extract-params" -}}
  {{- $ctx := $ -}}
  {{- $checkParams := false -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- $ctx = $.ctx -}}
    {{- if not (include "arkcase.isRootContext" $ctx) -}}
      {{- fail "Must provide the root context ($ or .) as either the only parameter, or the 'ctx' parameter" -}}
    {{- end -}}
    {{- $checkParams = true -}}
  {{- end -}}
  {{- $thisSubsys := (include "arkcase.subsystem.name" $ctx) -}}
  {{- $subsys := $thisSubsys -}}
  {{- $conn := "" -}}
  {{- /* Only consider the parameters if we weren't sent only the root context */ -}}
  {{- if $checkParams -}}
    {{- $subsys = ((hasKey $ "subsys") | ternary ($.subsys | default "" | toString) $subsys) | default $subsys -}}
    {{- $conn = ((hasKey $ "conn") | ternary ($.conn | default "" | toString) $conn) | default $conn -}}
  {{- end -}}

  {{- $result := dict "ctxIsRoot" (not $checkParams) "release" $ctx.Release.Name "subsys" $subsys "conn" $conn "local" (eq $subsys $thisSubsys) -}}
  {{- $result = set $result "radix" (printf "%s-%s-%s" $result.release $result.subsys $result.conn) -}}
  {{- $result | toYaml -}}
{{- end -}}

{{- define "__arkcase.subsystem-access.sanitize-mappings" -}}
  {{- $mappedKeys := $ -}}
  {{- $result := dict -}}
  {{- if and $mappedKeys (kindIs "map" $mappedKeys) -}}
    {{- $regex := "^[a-zA-Z0-9_.-]+$" -}}
    {{- range $k, $v := $mappedKeys -}}
      {{- if or (not $k) (not $v) -}}
        {{- continue -}}
      {{- end -}}
      {{- $v = ($v | toString) -}}
      {{- if not (regexMatch $regex $k) -}}
        {{- fail (printf "Invalid source key [%s] (mapped into [%s]) in mappings section - must match /%s/" $k $v $regex) -}}
      {{- end -}}
      {{- if not (regexMatch $regex $v) -}}
        {{- fail (printf "Invalid target key [%s] (mapped from [%s]) in mappings section - must match /%s/" $v $k $regex) -}}
      {{- end -}}
      {{- $result = set $result $k $v -}}
    {{- end -}}
  {{- end -}}
  {{- $result | toYaml -}}
{{- end -}}

{{- define "__arkcase.subsystem-access.sanitize-external" -}}
  {{- $external := $ -}}
  {{- if or (not $external) (not (kindIs "map" $external)) -}}
    {{- $external = dict -}}
  {{- end -}}

  {{- /* If the credential configuration is disabled, treat it as such */ -}}
  {{- if and (hasKey $external "enabled") (not (include "arkcase.toBoolean" $external.enabled)) -}}
    {{- $external = dict -}}
  {{- end -}}

  {{- $result := dict -}}
  {{- if $external -}}
    {{- $mappings := (include "__arkcase.subsystem-access.sanitize-mappings" $external.mappings | fromYaml) -}}

    {{- $connection := get $external "connection" -}}
    {{- range $k, $c := $connection -}}
      {{- if not $k -}}
        {{- fail (printf "Invalid empty-string connection name: %s" ($ | toYaml | nindent 0)) -}}
      {{- end -}}
      {{- $c = (include "__arkcase.subsystem-access.sanitize-connection" (dict "c" $c "m" $mappings) | fromYaml) -}}
      {{- if $c -}}
        {{- $result = set $result $k $c -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}

  {{- $result | toYaml -}}
{{- end -}}

{{- define "__arkcase.subsystem-access.sanitize-connection" -}}
  {{- $connection := $.c -}}
  {{- if or (not $connection) (not (kindIs "map" $connection)) -}}
    {{- $connection = dict -}}
  {{- end -}}
  {{- $connection = pick $connection "source" "inherit-mappings" "mappings" -}}

  {{- $result := dict -}}
  {{- if $connection -}}
    {{- $inheritMappings := ((hasKey $connection "inherit-mappings") | ternary (include "arkcase.toBoolean" (get $connection "inherit-mappings")) (true | toString) | empty | not) -}}
    {{- $sharedMappings := dict -}}
    {{- if and $inheritMappings $.m (kindIs "map" $.m) -}}
      {{- $sharedMappings = $.m -}}
    {{- end -}}

    {{- $reference := "" -}}
    {{- if (hasKey $connection "source") -}}
      {{- $reference = get $connection "source" -}}
      {{- if not (include "arkcase.tools.hostnamePart" $reference) -}}
        {{- fail (printf "Invalid connection secret name [%s]" $reference) -}}
      {{- end -}}
    {{- end -}}

    {{- if $reference -}}
      {{- /* We only tack the connection info if there actually is a target */ -}}
      {{- $result = merge $result (dict "source" $reference) -}}
    {{- end -}}

    {{- $mappings := (include "__arkcase.subsystem-access.sanitize-mappings" $connection.mappings | fromYaml) -}}

    {{- /* Add the shared mappings, if desired, without overwriting */ -}}
    {{- /* We don't sanitize the shared mappings b/c they were already sanitized before we were called */ -}} 
    {{- $mappings = (merge $mappings $sharedMappings) -}}
   
    {{- if $mappings -}}
      {{- $result = set $result "mappings" $mappings -}}
    {{- end -}}
  {{- end -}}

  {{- $result | toYaml -}}
{{- end -}}

{{- define "__arkcase.subsystem-access.sanitize-settings" -}}
  {{- $settings := $ -}}
  {{- if or (not $settings) (not (kindIs "map" $settings)) -}}
    {{- $settings = dict -}}
  {{- end -}}
  {{- $settings | toYaml -}}
{{- end -}}

{{- define "__arkcase.subsystem-access.conf.render" -}}
  {{- $params := (include "__arkcase.subsystem-access.extract-params" $ | fromYaml) -}}
  {{- $ctx := ($params.ctxIsRoot | ternary $ $.ctx) -}}

  {{- /* Gather up the configurations for the given subsystem */ -}}
  {{- $conf := dict -}}

  {{- $global := (($ctx.Values.global).conf | default dict) -}}
  {{- if (hasKey $global $params.subsys) -}}
    {{- $global = get $global $params.subsys -}}
    {{- if and $global (kindIs "map" $global) -}}
      {{- $conf = $global -}}
    {{- end -}}
  {{- end -}}

  {{- /* If this is being called for the local subsystem, we can add our internal configurations as well */ -}}
  {{- if $params.local -}}
    {{- $localConfig := ($ctx.Values.configuration | default dict) -}}
    {{- if and $localConfig (kindIs "map" $localConfig) -}}
      {{- $conf = merge $conf (dict "settings" $localConfig) -}}
    {{- end -}}
  {{- end -}}

  {{- $result := dict -}}

  {{- $settings := (include "__arkcase.subsystem-access.sanitize-settings" $conf.settings | fromYaml) -}}
  {{- if $settings -}}
    {{- $result = set $result "settings" $settings -}}
  {{- end -}}

  {{- $external := (include "__arkcase.subsystem-access.sanitize-external" $conf.external | fromYaml) -}}
  {{- if $external -}}
    {{- $result = set $result "external" $external -}}
  {{- end -}}

  {{- $result | toYaml -}}
{{- end -}}

{{- define "arkcase.subsystem.conf" -}}
  {{- include "arkcase.subsystem-access.conf" $ -}}
{{- end -}}

{{- define "arkcase.subsystem-access.conf" -}}
  {{- $params := (include "__arkcase.subsystem-access.extract-params" $ | fromYaml) -}}
  {{- $ctx := ($params.ctxIsRoot | ternary $ $.ctx) -}}

  {{- $cacheKey := "ArkCase-ConfigResources" -}}
  {{- $masterCache := dict -}}
  {{- if (hasKey $ctx $cacheKey) -}}
    {{- $masterCache = get $ctx $cacheKey -}}
    {{- if and $masterCache (not (kindIs "map" $masterCache)) -}}
      {{- $masterCache = dict -}}
    {{- end -}}
  {{- end -}}
  {{- $ctx = set $ctx $cacheKey $masterCache -}}

  {{- $masterKey := (printf "%s-%s" $params.release $params.subsys) -}}
  {{- $yamlResult := dict -}}
  {{- if not (hasKey $masterCache $masterKey) -}}
    {{- $yamlResult = (include "__arkcase.subsystem-access.conf.render" $) -}}
    {{- $masterCache = set $masterCache $masterKey ($yamlResult | fromYaml) -}}
  {{- else -}}
    {{- $yamlResult = get $masterCache $masterKey | toYaml -}}
  {{- end -}}
  {{- $yamlResult -}}
{{- end -}}

{{- define "arkcase.subsystem-access.external.conn" -}}
  {{- $params := (include "__arkcase.subsystem-access.extract-params" $ | fromYaml) -}}
  {{- $ctx := ($params.ctxIsRoot | ternary $ $.ctx) -}}
  {{- $args := (dict "ctx" $ctx "type" "conn" "subsys" $params.subsys) -}}

  {{- $conf := (include "arkcase.subsystem-access.conf" $args | fromYaml) -}}
  {{- $conf = ($conf.connection | default dict) -}}
  {{- if not $params.conn -}}
    {{- $defaultConn := $conf.default | default "main" -}}
    {{- $params = merge (dict "conn" $defaultConn "radix" (printf "%s%s" $params.radix $defaultConn)) $params -}}
  {{- end -}}
  {{- $conf = (get $conf $params.conn | default dict) -}}

  {{- (empty $conf) | ternary "" "true" -}}
{{- end -}}

{{- define "arkcase.subsystem-access.external.admin" -}}
  {{- $params := (include "__arkcase.subsystem-access.extract-params" $ | fromYaml) -}}
  {{- $ctx := ($params.ctxIsRoot | ternary $ $.ctx) -}}
  {{- $args := (dict "ctx" $ctx "type" "cred-admin" "subsys" $params.subsys) -}}

  {{- $conf := (include "arkcase.subsystem-access.conf" $args | fromYaml) -}}
  {{- $conf = ($conf.connection | default dict) -}}
  {{- if not $params.conn -}}
    {{- $defaultConn := $conf.default | default "main" -}}
    {{- $params = merge (dict "conn" $defaultConn "radix" (printf "%s%s" $params.radix $defaultConn)) $params -}}
  {{- end -}}
  {{- $conf = (get $conf $params.conn | default dict) -}}

  {{- $creds := ((get ($conf.credentials | default dict) "admin") | default dict) -}}
  {{- (empty $creds) | ternary "" "true" -}}
{{- end -}}

{{- define "arkcase.subsystem-access.external.cred" -}}
  {{- $params := (include "__arkcase.subsystem-access.extract-params" $ | fromYaml) -}}
  {{- $ctx := ($params.ctxIsRoot | ternary $ $.ctx) -}}
  {{- $type := "access" -}}
  {{- if not $params.ctxIsRoot -}}
    {{- $type = ($.type | default $type | toString) -}}
  {{- end -}}
  {{- $regex := "^[a-z0-9]+(-[a-z0-9]+)*$" -}}
  {{- if (not (regexMatch $regex $type)) -}}
    {{- fail (printf "Invalid resource type [%s] for subsystem [%s], connection [%s] - must match /%s/" $type $params.subsys $params.conn $regex) -}}
  {{- end -}}
  {{- if not (hasPrefix "cred-" $type) -}}
    {{- $type = (printf "%s%s" "cred-" $type) -}}
  {{- end -}}
  {{- $args := (dict "ctx" $ctx "type" $type "subsys" $params.subsys) -}}

  {{- $conf := (include "arkcase.subsystem-access.conf" $args | fromYaml) -}}
  {{- $conf = ($conf.connection | default dict) -}}
  {{- if not $params.conn -}}
    {{- $defaultConn := $conf.default | default "main" -}}
    {{- $params = merge (dict "conn" $defaultConn "radix" (printf "%s%s" $params.radix $defaultConn)) $params -}}
  {{- end -}}
  {{- $conf = (get $conf $params.conn | default dict) -}}

  {{- $creds := ((get ($conf.credentials | default dict) (trimPrefix "cred-" $type)) | default dict) -}}
  {{- (empty $creds) | ternary "" "true" -}}
{{- end -}}

{{- define "__arkcase.subsystem-access.name" -}}
  {{- $params := (include "__arkcase.subsystem-access.extract-params" $ | fromYaml) -}}
  {{- $ctx := ($params.ctxIsRoot | ternary $ $.ctx) -}}

  {{- if not (hasKey $ "type") -}}
    {{- fail "Must provide a 'type' to render the name for" -}}
  {{- end -}}
  {{- $type := ($.type | default $.type | toString) -}}

  {{- $regex := "^[a-z0-9]+(-[a-z0-9]+)*$" -}}
  {{- if (not (regexMatch $regex $type)) -}}
    {{- fail (printf "Invalid resource type [%s] for subsystem [%s], connection [%s] - must match /%s/" $type $params.subsys $params.conn $regex) -}}
  {{- end -}}

  {{- $conf := (include "arkcase.subsystem-access.conf" $ | fromYaml) -}}
  {{- $conf = ($conf.connection | default dict) -}}
  {{- if not $params.conn -}}
    {{- $defaultConn := $conf.default | default "main" -}}
    {{- $params = merge (dict "conn" $defaultConn "radix" (printf "%s%s" $params.radix $defaultConn)) $params -}}
  {{- end -}}
  {{- printf "%s-%s" $params.radix $type -}}
{{- end -}}

{{- /* Params: subsys? */ -}}
{{- define "arkcase.subsystem-access.name.conn" -}}
  {{- $params := (include "__arkcase.subsystem-access.extract-params" $ | fromYaml) -}}
  {{- $ctx := ($params.ctxIsRoot | ternary $ $.ctx) -}}
  {{- include "__arkcase.subsystem-access.name" (dict "ctx" $ctx "type" "conn" "subsys" $params.subsys "conn" $params.conn) -}}
{{- end -}}

{{- /* Params: subsys?, type? */ -}}
{{- define "arkcase.subsystem-access.name.cred" -}}
  {{- $params := (include "__arkcase.subsystem-access.extract-params" $ | fromYaml) -}}
  {{- $ctx := ($params.ctxIsRoot | ternary $ $.ctx) -}}
  {{- $type := "access" -}}
  {{- if not $params.ctxIsRoot -}}
    {{- $type = ($.type | default $type | toString) -}}
  {{- end -}}
  {{- $regex := "^[a-z0-9]+(-[a-z0-9]+)*$" -}}
  {{- if (not (regexMatch $regex $type)) -}}
    {{- fail (printf "Invalid resource type [%s] for subsystem [%s], connection [%s] - must match /%s/" $type $params.subsys $params.conn $regex) -}}
  {{- end -}}
  {{- if not (hasPrefix "cred-" $type) -}}
    {{- $type = (printf "%s%s" "cred-" $type) -}}
  {{- end -}}
  {{- include "__arkcase.subsystem-access.name" (dict "ctx" $ctx "type" $type "subsys" $params.subsys "conn" $params.conn) -}}
{{- end -}}

{{- define "arkcase.subsystem-access.name.admin" -}}
  {{- $params := (include "__arkcase.subsystem-access.extract-params" $ | fromYaml) -}}
  {{- $ctx := ($params.ctxIsRoot | ternary $ $.ctx) -}}
  {{- include "__arkcase.subsystem-access.name" (dict "ctx" $ctx "type" "cred-admin" "subsys" $params.subsys "conn" $params.conn) -}}
{{- end -}}

{{- /* Params: subsys?, conn?, type?, key, name?, optional? */ -}}
{{- define "__arkcase.subsystem-access.env" -}}
  {{- $params := (include "__arkcase.subsystem-access.extract-params" $ | fromYaml) -}}
  {{- if or $params.ctxIsRoot (not (hasKey $ "key")) -}}
    {{- fail "Must provide a 'key' parameter" -}}
  {{- end -}}
  {{- $ctx := $.ctx -}}

  {{- $conf := (include "arkcase.subsystem-access.conf" $ | fromYaml) -}}
  {{- $conf = ($conf.connection | default dict) -}}
  {{- if not $params.conn -}}
    {{- $defaultConn := $conf.default | default "main" -}}
    {{- $params = merge (dict "conn" $defaultConn "radix" (printf "%s%s" $params.radix $defaultConn)) $params -}}
  {{- end -}}
  {{- $conf = (get $conf $params.conn | default dict) -}}

  {{- $type := "access" -}}
  {{- if not $params.ctxIsRoot -}}
    {{- $type = ($.type | default $type | toString) -}}
  {{- end -}}

  {{- $key := $.key -}}
  {{- $regex := "^[a-zA-Z0-9_.-]+$" -}}
  {{- if not (regexMatch $regex $key) -}}
    {{- fail (printf "Invalid key [%s] from the configuration resource of type %s for subsystem %s, connection [%s] - must match /%s/" $key $params.type $params.subsys $params.conn $regex) -}}
  {{- end -}}

  {{- $envVarName := "" -}}
  {{- if (hasKey $ "name") -}}
    {{- $vars := (dict "subsys" $params.subsys "conn" $params.conn "type" $type "key" $key "defaultCase" "u") -}}
    {{- $envVarName = (include "__arkcase.subsystem-access.expand-vars" (dict "str" $.name "params" $vars "regex" "[-.]" "replace" "_" "defaultCase" "u")) -}}
    {{- $regex := "^[a-zA-Z0-9_]+$" -}}
    {{- if not (regexMatch $regex $envVarName) -}}
      {{- fail (printf "Invalid envvar name [%s] (final result = [%s]) for the key %s from the configuration resource of type %s for subsystem %s, connection [%s] - must match /%s/" $.name $envVarName $key $params.type $params.subsys $params.conn $regex) -}}
    {{- end -}}
  {{- else -}}
    {{- $envVarName = "arkcase" -}}
    {{- if not $params.local -}}
      {{- $envVarName = (printf "%s_%s_%s" $envVarName $params.subsys $params.conn) -}}
    {{- end -}}
    {{- $envVarName = (printf "%s_%s_%s" $envVarName $type $key | upper) -}}
    {{- $envVarName = regexReplaceAll "[-.]" $envVarName "_" -}}
  {{- end -}}

  {{- $sourceName := "" -}}
  {{- $sourceNameTemplate := "" -}}

  {{- if (hasPrefix "cred-" $type) -}}
    {{- $conf = (get ($conf.credentials | default dict) (trimPrefix "cred-" $type) | default dict) -}}
    {{- $sourceName = $conf.source -}}
    {{- if not $sourceName -}}
      {{- $sourceNameTemplate = "arkcase.subsystem-access.name.cred" -}}
    {{- end -}}
  {{- else -}}
    {{- $sourceName = $conf.source -}}
    {{- if not $sourceName -}}
      {{- $sourceNameTemplate = "arkcase.subsystem-access.name.conn" -}}
    {{- end -}}
  {{- end -}}

  {{- if $sourceNameTemplate -}}
    {{- $sourceName = (include $sourceNameTemplate $) -}}
  {{- end -}}

  {{- if contains "nil" $sourceName -}}
    {{- fail (dict "sourceName" $sourceName "template" $sourceNameTemplate "params" $params "conf" $conf "$" (omit $ "ctx") | toYaml | nindent 0) -}}
  {{- end -}}

  {{- $configMap := (eq $conf.configMap true) -}}

  {{- $optional := (not (empty (include "arkcase.toBoolean" ($.optional | default false)))) -}}

  {{- /* Now we try to find any mappings for this key */ -}}
  {{- $mappings := (get $conf "mappings" | default dict) -}}
  {{- $sourceKey := (hasKey $mappings $key | ternary (get $mappings $key) $key) -}}
- name: {{ $envVarName | quote }}
  valueFrom:
    {{ $configMap | ternary "configMap" "secret" }}KeyRef:
      name: {{ $sourceName | quote }}
      key: {{ $sourceKey | quote }}
      optional: {{ $optional }}
{{- end }}

{{- define "arkcase.subsystem-access.env.conn" -}}
  {{- $params := (include "__arkcase.subsystem-access.extract-params" $ | fromYaml) -}}
  {{- $ctx := ($params.ctxIsRoot | ternary $ $.ctx) -}}
  {{- if or $params.ctxIsRoot (not (hasKey $ "key")) -}}
    {{- fail "Must provide a 'key' parameter" -}}
  {{- end -}}
  {{- $args := merge (dict "ctx" $ctx "type" "conn" "subsys" $params.subsys "conn" $params.conn) (pick $ "key" "name" "optional") -}}
  {{- include "__arkcase.subsystem-access.env" $args }}
{{- end -}}

{{- define "arkcase.subsystem-access.env.admin" -}}
  {{- $params := (include "__arkcase.subsystem-access.extract-params" $ | fromYaml) -}}
  {{- $ctx := ($params.ctxIsRoot | ternary $ $.ctx) -}}
  {{- if or $params.ctxIsRoot (not (hasKey $ "key")) -}}
    {{- fail "Must provide a 'key' parameter" -}}
  {{- end -}}
  {{- $args := merge (dict "ctx" $ctx "type" "cred-admin" "subsys" $params.subsys "conn" $params.conn) (pick $ "key" "name" "optional") -}}
  {{- include "__arkcase.subsystem-access.env" $args }}
{{- end -}}

{{- define "arkcase.subsystem-access.env.cred" -}}
  {{- $params := (include "__arkcase.subsystem-access.extract-params" $ | fromYaml) -}}
  {{- $ctx := ($params.ctxIsRoot | ternary $ $.ctx) -}}
  {{- if or $params.ctxIsRoot (not (hasKey $ "key")) -}}
    {{- fail "Must provide a 'key' parameter" -}}
  {{- end -}}
  {{- $type := "access" -}}
  {{- if not $params.ctxIsRoot -}}
    {{- $type = ($.type | default $type | toString) -}}
  {{- end -}}
  {{- $regex := "^[a-z0-9]+(-[a-z0-9]+)*$" -}}
  {{- if (not (regexMatch $regex $type)) -}}
    {{- fail (printf "Invalid resource type [%s] for subsystem [%s], connection [%s] - must match /%s/" $type $params.subsys $params.conn $regex) -}}
  {{- end -}}
  {{- if not (hasPrefix "cred-" $type) -}}
    {{- $type = (printf "%s%s" "cred-" $type) -}}
  {{- end -}}
  {{- $args := merge (dict "ctx" $ctx "type" $type "subsys" $params.subsys "conn" $params.conn) (pick $ "key" "name" "optional") -}}
  {{- include "__arkcase.subsystem-access.env" $args }}
{{- end -}}

{{- define "__arkcase.subsystem-access.volumeMount" -}}
  {{- $params := (include "__arkcase.subsystem-access.extract-params" $ | fromYaml) -}}
  {{- $ctx := ($params.ctxIsRoot | ternary $ $.ctx) -}}
  {{- if or $params.ctxIsRoot (not (hasKey $ "key")) -}}
    {{- fail "Must provide a 'key' parameter" -}}
  {{- end -}}

  {{- $conf := (include "arkcase.subsystem-access.conf" $ | fromYaml) -}}
  {{- $conf = ($conf.connection | default dict) -}}
  {{- if not $params.conn -}}
    {{- $defaultConn := $conf.default | default "main" -}}
    {{- $params = merge (dict "conn" $defaultConn "radix" (printf "%s%s" $params.radix $defaultConn)) $params -}}
  {{- end -}}
  {{- $conf = (get $conf $params.conn | default dict) -}}

  {{- $type := "access" -}}
  {{- if not $params.ctxIsRoot -}}
    {{- $type = ($.type | default $type | toString) -}}
  {{- end -}}

  {{- $key := $.key -}}
  {{- $regex := "^[a-zA-Z0-9_.-]+$" -}}
  {{- if not (regexMatch $regex $key) -}}
    {{- fail (printf "Invalid key [%s] from the configuration resource of type %s for subsystem %s, connection [%s] - must match /%s/" $key $params.type $params.subsys $params.conn $regex) -}}
  {{- end -}}

  {{- $volumeNameTemplate := "" -}}
  {{- if (hasPrefix "cred-" $type) -}}
    {{- $conf = (get ($conf.credentials | default dict) (trimPrefix "cred-" $type) | default dict) -}}
    {{- $volumeNameTemplate = "arkcase.subsystem-access.name.cred" -}}
  {{- else -}}
    {{- $volumeNameTemplate = "arkcase.subsystem-access.name.conn" -}}
  {{- end -}}

  {{- $volumeName := (printf "vol-%s" (include $volumeNameTemplate $)) -}}

  {{- /* Now we try to find any mappings for this key */ -}}
  {{- $mappings := (get $conf "mappings" | default dict) -}}
  {{- $sourceKey := (hasKey $mappings $key | ternary (get $mappings $key) $key) -}}

  {{- $mountPath := $.mountPath -}}
  {{- if not (hasKey $ "mountPath") -}}
    {{- $mountPath = (printf "/srv/arkcase/%s/%s/%s/%s" ($params.local | ternary "local" $params.subsys) $params.conn $type $key) -}}
  {{- end -}}

  {{- if not (regexMatch "/[^/].*" $mountPath) -}}
    {{- fail (printf "Invalid mount path [%s] - must be an absolute file path" $mountPath) -}}
  {{- end -}}
- name: {{ $volumeName | quote }}
  mountPath: {{ $mountPath | quote }}
  subPath: {{ $sourceKey | quote }}
  readOnly: true
{{- end }}

{{- define "arkcase.subsystem-access.volumeMount.conn" -}}
  {{- $params := (include "__arkcase.subsystem-access.extract-params" $ | fromYaml) -}}
  {{- $ctx := ($params.ctxIsRoot | ternary $ $.ctx) -}}
  {{- if or $params.ctxIsRoot (not (hasKey $ "key")) -}}
    {{- fail "Must provide a 'key' parameter" -}}
  {{- end -}}
  {{- $args := merge (dict "ctx" $ctx "type" "conn" "subsys" $params.subsys "conn" $params.conn) (pick $ "key" "mountPath") -}}
  {{- include "__arkcase.subsystem-access.volumeMount" $args }}
{{- end -}}

{{- define "arkcase.subsystem-access.volumeMount.admin" -}}
  {{- $params := (include "__arkcase.subsystem-access.extract-params" $ | fromYaml) -}}
  {{- $ctx := ($params.ctxIsRoot | ternary $ $.ctx) -}}
  {{- if or $params.ctxIsRoot (not (hasKey $ "key")) -}}
    {{- fail "Must provide a 'key' parameter" -}}
  {{- end -}}
  {{- $args := merge (dict "ctx" $ctx "type" "cred-admin" "subsys" $params.subsys "conn" $params.conn) (pick $ "key" "mountPath") -}}
  {{- include "__arkcase.subsystem-access.volumeMount" $args }}
{{- end -}}

{{- define "arkcase.subsystem-access.volumeMount.cred" -}}
  {{- $params := (include "__arkcase.subsystem-access.extract-params" $ | fromYaml) -}}
  {{- $ctx := ($params.ctxIsRoot | ternary $ $.ctx) -}}
  {{- if or $params.ctxIsRoot (not (hasKey $ "key")) -}}
    {{- fail "Must provide a 'key' parameter" -}}
  {{- end -}}
  {{- $type := "access" -}}
  {{- if not $params.ctxIsRoot -}}
    {{- $type = ($.type | default $type | toString) -}}
  {{- end -}}
  {{- $regex := "^[a-z0-9]+(-[a-z0-9]+)*$" -}}
  {{- if (not (regexMatch $regex $type)) -}}
    {{- fail (printf "Invalid resource type [%s] for subsystem [%s], connection [%s] - must match /%s/" $type $params.subsys $params.conn $regex) -}}
  {{- end -}}
  {{- if not (hasPrefix "cred-" $type) -}}
    {{- $type = (printf "%s%s" "cred-" $type) -}}
  {{- end -}}
  {{- $args := merge (dict "ctx" $ctx "type" $type "subsys" $params.subsys "conn" $params.conn) (pick $ "key" "mountPath") -}}
  {{- include "__arkcase.subsystem-access.volumeMount" $args }}
{{- end -}}

{{- define "__arkcase.subsystem-access.volume" -}}
  {{- $params := (include "__arkcase.subsystem-access.extract-params" $ | fromYaml) -}}
  {{- $ctx := ($params.ctxIsRoot | ternary $ $.ctx) -}}

  {{- $conf := (include "arkcase.subsystem-access.conf" $ | fromYaml) -}}
  {{- $conf = ($conf.connection | default dict) -}}
  {{- if not $params.conn -}}
    {{- $defaultConn := $conf.default | default "main" -}}
    {{- $params = merge (dict "conn" $defaultConn "radix" (printf "%s%s" $params.radix $defaultConn)) $params -}}
  {{- end -}}
  {{- $conf = (get $conf $params.conn | default dict) -}}

  {{- $type := "access" -}}
  {{- if not $params.ctxIsRoot -}}
    {{- $type = ($.type | default $type | toString) -}}
  {{- end -}}

  {{- $volumeNameTemplate := "" -}}
  {{- if (hasPrefix "cred-" $type) -}}
    {{- $conf = (get ($conf.credentials | default dict) (trimPrefix "cred-" $type) | default dict) -}}
    {{- $volumeNameTemplate = "arkcase.subsystem-access.name.cred" -}}
  {{- else -}}
    {{- $volumeNameTemplate = "arkcase.subsystem-access.name.conn" -}}
  {{- end -}}

  {{- $volumeName := (include $volumeNameTemplate $) -}}
  {{- $sourceName := $conf.source | default $volumeName -}}
  {{- $volumeName = (printf "vol-%s" $volumeName) -}}

  {{- $configMap := (eq $conf.configMap true) -}}
  {{- $optional := (not (empty (include "arkcase.toBoolean" ($.optional | default false)))) -}}
- name: {{ $volumeName | quote }}
  {{ $configMap | ternary "configMap" "secret" }}:
    {{ $configMap | ternary "name" "secretName" }}: {{ $sourceName | quote }}
    defaultMode: 0444
    optional: {{ $optional }}
{{- end }}

{{- define "arkcase.subsystem-access.volume.conn" -}}
  {{- $params := (include "__arkcase.subsystem-access.extract-params" $ | fromYaml) -}}
  {{- $ctx := ($params.ctxIsRoot | ternary $ $.ctx) -}}
  {{- $args := merge (dict "ctx" $ctx "type" "conn" "subsys" $params.subsys "conn" $params.conn) (pick $ "optional") -}}
  {{- include "__arkcase.subsystem-access.volume" $args }}
{{- end -}}

{{- define "arkcase.subsystem-access.volume.admin" -}}
  {{- $params := (include "__arkcase.subsystem-access.extract-params" $ | fromYaml) -}}
  {{- $ctx := ($params.ctxIsRoot | ternary $ $.ctx) -}}
  {{- $args := merge (dict "ctx" $ctx "type" "cred-admin" "subsys" $params.subsys "conn" $params.conn) (pick $ "optional") -}}
  {{- include "__arkcase.subsystem-access.volume" $args }}
{{- end -}}

{{- define "arkcase.subsystem-access.volume.cred" -}}
  {{- $params := (include "__arkcase.subsystem-access.extract-params" $ | fromYaml) -}}
  {{- $ctx := ($params.ctxIsRoot | ternary $ $.ctx) -}}
  {{- $args := merge (dict "ctx" $ctx "type" "cred-admin" "subsys" $params.subsys "conn" $params.conn) (pick $ "optional") -}}
  {{- $type := "access" -}}
  {{- if not $params.ctxIsRoot -}}
    {{- $type = ($.type | default $type | toString) -}}
  {{- end -}}
  {{- $regex := "^[a-z0-9]+(-[a-z0-9]+)*$" -}}
  {{- if (not (regexMatch $regex $type)) -}}
    {{- fail (printf "Invalid resource type [%s] for subsystem [%s], connection [%s] - must match /%s/" $type $params.subsys $params.conn $regex) -}}
  {{- end -}}
  {{- if not (hasPrefix "cred-" $type) -}}
    {{- $type = (printf "%s%s" "cred-" $type) -}}
  {{- end -}}
  {{- $args := merge (dict "ctx" $ctx "type" $type "subsys" $params.subsys "conn" $params.conn) (pick $ "optional") -}}
  {{- include "__arkcase.subsystem-access.volume" $args }}
{{- end -}}

{{- define "__arkcase.subsystem-access.all.render.sanitize-propValue" -}}
  {{- $propValue := $ -}}
  {{- $result := dict -}}
  {{- if (kindIs "bool" $propValue) -}}
    {{- /* Make a map consistent with the boolean value */ -}}
    {{- $result = (dict "env" $propValue "path" $propValue) -}}
  {{- else if (kindIs "map" $propValue) -}}
    {{- /* This map must only contain "env" and "path" keys - the caller will make sense of them */ -}}
    {{- $result = pick $propValue "env" "path" -}}
  {{- else if (kindIs "string" $propValue) -}}
    {{- /* It's a string ... convert it to a map */ -}}
    {{- if (regexMatch "^(env|path|all|true|false)$" ($propValue | lower)) -}}
      {{- /* Abbreviation to generate a map with default names */ -}}
      {{- $result = ($propValue | lower) -}}
      {{- if (eq "all" $propValue) -}}
        {{- $result = (dict "env" true "path" true) -}}
      {{- else if (has $propValue (list "env" "path")) -}}
        {{- $result = dict $propValue true -}}
      {{- else -}}
        {{- /* Like above, make a map consistent with the boolean value */ -}}
        {{- $bool := (not (empty (include "arkcase.toBoolean" ($propValue | lower)))) -}}
        {{- $result = (dict "env" $bool "path" $bool) -}}
      {{- end -}}
    {{- else -}}
      {{- /* The string is either an envvar name or a path */ -}}
      {{- if (regexMatch "^[a-zA-Z_][a-zA-Z0-9_]*$" $propValue) -}}
        {{- $result = (dict "env" $propValue) -}}
      {{- else if (regexMatch "^/[^/]+(/[^/]+)*$" $propValue) -}}
        {{- $result = (dict "path" $propValue) -}}
      {{- end -}}
    {{- end -}}
  {{- else -}}
    {{- /* For any unsupported type, output nothing and the caller will do the complaining */ -}}
  {{- end -}}

  {{- if $result -}}
    {{- $result | toYaml -}}
  {{- end -}}
{{- end -}}

{{- define "__arkcase.subsystem-access.all.render" -}}
  {{- $ctx := $ -}}

  {{- /* In case we've only been asked to produce the stuff for a given subsystem */ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- $ctx = $.ctx -}}
    {{- if not (include "arkcase.isRootContext" $ctx) -}}
      {{- fail "Must provide the root context ($ or .) as either the 'ctx' parameter, or the only parameter" -}}
    {{- end -}}
  {{- end -}}

  {{- $resultEnv := dict -}}
  {{- $resultMnt := dict -}}
  {{- $resultVol := dict -}}

  {{- $accessConfig := ($ctx.Files.Get "subsys-deps.yaml" | fromYaml | default dict) -}}
  {{- $consumes := ($accessConfig.consumes | default dict) -}}
  {{- range $subsys := (keys $consumes | sortAlpha) -}}
    {{- $subsysData := get $consumes $subsys -}}

    {{- /* If there's nothing to consume from this subsystem, skip it */ -}}
    {{- if or (not $subsysData) (not (kindIs "map" $subsysData)) -}}
      {{- continue -}}
    {{- end -}}

    {{- $currentEnv := list -}}
    {{- $currentMnt := list -}}
    {{- $currentVol := list -}}

    {{- $params := (dict "ctx" $ctx "subsys" $subsys) -}}

    {{- range $conn := (keys $subsysData | sortAlpha) -}}
      {{- $connData := get $subsysData $conn -}}

      {{- /* If there's nothing to consume from this subsystem connection, skip it */ -}}
      {{- if or (not $connData) (not (kindIs "map" $connData)) -}}
        {{- continue -}}
      {{- end -}}

      {{- $params = (set $params "conn" $conn) -}}
      {{- $connVolume := false -}}

      {{- /* $connData is the set of properties */ -}}
      {{- range $connProp := (keys $connData | sortAlpha) -}}
        {{- $connPropValue := (get $connData $connProp) -}}
        {{- if not $connPropValue -}}
          {{- continue -}}
        {{- end -}}

        {{- $params = (set $params "key" $connProp) -}}

        {{- $newPropValue := (include "__arkcase.subsystem-access.all.render.sanitize-propValue" $connPropValue) -}}
        {{- if not $newPropValue -}}
          {{- fail (printf "Invalid property value specification for subsystem %s, connection %s, property %s: %s" $subsys $conn $connProp ($connPropValue | toYaml | nindent 0)) -}}
        {{- end -}}
        {{- $connPropValue = ($newPropValue | fromYaml) -}}

        {{- if $connPropValue.env -}}
          {{- $p2 := dict -}}
          {{- $env := $connPropValue.env -}}
          {{- if (kindIs "string" $env) -}}
            {{- if not (regexMatch "^[a-zA-Z_][a-zA-Z0-9_]*$" $env) -}}
              {{- fail (printf "Invalid environment variable name: [%s] for subsystem %s, connection %s, property %s" $env $subsys $conn $connProp) -}}
            {{- end -}}
            {{- $p2 = set $p2 "name" $env -}}
          {{- end -}}
          {{- $currentEnv = concat $currentEnv (include "arkcase.subsystem-access.env.cred" (merge $p2 $params) | fromYamlArray) -}}
        {{- end -}}

        {{- if $connPropValue.path -}}
          {{- $p2 := dict -}}
          {{- $path := $connPropValue.path -}}
          {{- if (kindIs "string" $path) -}}
            {{- if not (regexMatch "^/[^/]+(/[^/]+)*$" $path) -}}
              {{- fail (printf "Invalid path specification: [%s] for subsystem %s, connection %s, property %s" $path $subsys $conn $connProp) -}}
            {{- end -}}
            {{- $p2 = set $p2 "mountPath" $path -}}
          {{- end -}}
          {{- $currentMnt = concat $currentMnt (include "arkcase.subsystem-access.volumeMount.cred" (merge $p2 $params) | fromYamlArray) -}}
          {{- $connVolume = true -}}
        {{- end -}}
      {{- end -}}

      {{- $params = omit $params "key" -}}
      {{- if $connVolume -}}
        {{- $currentVol = concat $currentVol (include "arkcase.subsystem-access.volume.cred" $params | fromYamlArray) -}}
      {{- end -}}
    {{- end -}}

    {{- if $currentEnv -}}
      {{- $resultEnv = set $resultEnv $subsys $currentEnv -}}
    {{- end -}}

    {{- if $currentMnt -}}
      {{- $resultMnt = set $resultMnt $subsys $currentMnt -}}
    {{- end -}}

    {{- if $currentVol -}}
      {{- $resultVol = set $resultVol $subsys $currentVol -}}
    {{- end -}}
  {{- end -}}
  {{- dict "env" $resultEnv "mnt" $resultMnt "vol" $resultVol | toYaml -}}
{{- end -}}

{{- define "__arkcase.subsystem-access.all.cached" -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The parameter given must be the root context (. or $)" -}}
  {{- end -}}

  {{- $cacheKey := "ArkCase-Subsystem-Access-References" -}}
  {{- $masterCache := dict -}}
  {{- if (hasKey $ctx $cacheKey) -}}
    {{- $masterCache = get $ctx $cacheKey -}}
    {{- if and $masterCache (not (kindIs "map" $masterCache)) -}}
      {{- $masterCache = dict -}}
    {{- end -}}
  {{- end -}}
  {{- $ctx = set $ctx $cacheKey $masterCache -}}

  {{- $masterKey := $ctx.Release.Name -}}
  {{- $yamlResult := dict -}}
  {{- if not (hasKey $masterCache $masterKey) -}}
    {{- $yamlResult = (include "__arkcase.subsystem-access.all.render" $ctx) -}}
    {{- $masterCache = set $masterCache $masterKey ($yamlResult | fromYaml) -}}
  {{- else -}}
    {{- $yamlResult = get $masterCache $masterKey | toYaml -}}
  {{- end -}}
  {{- $yamlResult -}}
{{- end -}}

{{- define "__arkcase.subsystem-access.all" -}}
  {{- $ctx := $.ctx -}}
  {{- $subsys := $.subsys -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- $subsys = $ctx.subsys -}}
    {{- $ctx = $ctx.ctx -}}
    {{- if not (include "arkcase.isRootContext" $ctx) -}}
      {{- fail "Must provide the root context ($ or .) as the 'ctx' parameter" -}}
    {{- end -}}
  {{- end -}}
  {{- $subsys = ($subsys | default "" | toString) -}}

  {{- if not (hasKey $ "render") -}}
    {{- fail "Must provide the type of entries to render" -}}
  {{- end -}}

  {{- $render := ($.render | toString | default "") -}}

  {{- $all := (include "__arkcase.subsystem-access.all.cached" $ctx | fromYaml) -}}
  {{- if not (hasKey $all $render) -}}
    {{- fail (printf "Invalid rendering type [%s] - must be one of %s" $render (keys $all | sortAlpha)) -}}
  {{- end -}}

  {{- $all = get $all $render -}}
  {{- if $all }}
    {{- if and $subsys (hasKey $all $subsys) }}
      {{- $all = pick $all $subsys }}
    {{- end }}
    {{- range $s := (keys $all | sortAlpha) }}
      {{- get $all $s | toYaml | nindent 0 }}
    {{- end }}
  {{- end }}
{{- end -}}

{{- define "arkcase.subsystem-access.all.env" -}}
  {{- include "__arkcase.subsystem-access.all" (dict "ctx" $ "render" "env") -}}
{{- end -}}

{{- define "arkcase.subsystem-access.all.volumeMount" -}}
  {{- include "__arkcase.subsystem-access.all" (dict "ctx" $ "render" "mnt") -}}
{{- end -}}

{{- define "arkcase.subsystem-access.all.volume" -}}
  {{- include "__arkcase.subsystem-access.all" (dict "ctx" $ "render" "vol") -}}
{{- end -}}
