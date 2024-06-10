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

{{- define "__arkcase.subsystem-access.sanitize-mapped-keys" -}}
  {{- $base := $ -}}
  {{- $key := "mapped-keys" -}}

  {{- $mappedKeys := get $base $key -}}
  {{- if or (not $mappedKeys) (not (kindIs "map" $mappedKeys)) -}}
    {{- $mappedKeys = dict -}}
  {{- end -}}

  {{- $result := dict -}}
  {{- if $mappedKeys -}}
    {{- $regex := "^[a-zA-Z0-9_.-]+$" -}}
    {{- range $k, $v := $mappedKeys -}}
      {{- if or (not $k) (not $v) -}}
        {{- continue -}}
      {{- end -}}
      {{- $v = ($v | toString) -}}
      {{- if not (regexMatch $regex $k) -}}
        {{- fail (printf "Invalid source key [%s] (mapped into [%s]) in mapped-keys section - must match /%s/" $k $v $regex) -}}
      {{- end -}}
      {{- if not (regexMatch $regex $v) -}}
        {{- fail (printf "Invalid target key [%s] (mapped from [%s]) in mapped-keys section - must match /%s/" $v $k $regex) -}}
      {{- end -}}
      {{- $result = set $result $k $v -}}
    {{- end -}}

    {{- if $result -}}
      {{- $result = dict $key $result -}}
    {{- end -}}
  {{- end -}}
  {{- $result | toYaml -}}
{{- end -}}

{{- define "__arkcase.subsystem-access.sanitize-credentials" -}}
  {{- $credentials := $ -}}
  {{- if or (not $credentials) (not (kindIs "map" $credentials)) -}}
    {{- $credentials = dict -}}
  {{- end -}}

  {{- if and (hasKey $credentials "enabled") (not (include "arkcase.toBoolean" $credentials.enabled)) -}}
    {{- $credentials = dict -}}
  {{- end -}}

  {{- $result := dict -}}
  {{- if $credentials -}}
    {{- /* Scan over each credential defined in the map, and sanitize it */ -}}
    {{- range $key, $creds := (omit $credentials "enabled") -}}

      {{- if not (include "arkcase.tools.hostnamePart" $key) -}}
        {{- fail (printf "Illegal credentials name [%s] must be an RFC-1123 hostname part (no dots!)" $key) -}}
      {{- end -}}

      {{- /* If it's empty, in any way, shape, or form, skip it */ -}}
      {{- if not $creds -}}
        {{- continue -}}
      {{- end -}}

      {{- if not (kindIs "map" $creds) -}}
        {{- $creds = (dict "secret" ($creds | toString)) -}}
      {{- end -}}

      {{- /* Skip disabled credentials */ -}}
      {{- $enabled := or (not (hasKey $creds "enabled")) (include "arkcase.toBoolean" $creds.enabled) -}}
      {{- if not $enabled -}}
        {{- continue -}}
      {{- end -}}

      {{- $reference := ((hasKey $creds "secret") | ternary $creds.secret "") -}}
      {{- if not $reference -}}
        {{- /* If the target secret is null or the empty string, ignore it */ -}}
        {{- continue -}}
      {{- end -}}

      {{- if not (include "arkcase.tools.hostnamePart" $reference) -}}
        {{- fail (printf "Invalid secret credentials reference [%s]" $reference) -}}
      {{- end -}}

      {{- /* These are the new credentials we will return */ -}}
      {{- $newCreds := (dict "source" $reference "configMap" false) -}}

      {{- /* The mapped keys are only of use if we have an alternative source */ -}}
      {{- $newCreds = merge $newCreds (include "__arkcase.subsystem-access.sanitize-mapped-keys" $creds | fromYaml) -}}

      {{- /* Stow the computed credentials */ -}}
      {{- $result = set $result $key $newCreds -}}
    {{- end -}}
  {{- end -}}
  {{- $result | toYaml -}}
{{- end -}}

{{- define "__arkcase.subsystem-access.sanitize-multi-connections" -}}
  {{- $connection := $ -}}
  {{- if or (not $connection) (not (kindIs "map" $connection)) -}}
    {{- $connection = dict -}}
  {{- end -}}

  {{- /* If the credential configuration is disabled, treat it as such */ -}}
  {{- if and (hasKey $connection "enabled") (not (include "arkcase.toBoolean" $connection.enabled)) -}}
    {{- $connection = dict -}}
  {{- end -}}

  {{- $result := dict -}}
  {{- if $connection -}}
    {{- $connection = omit $connection "enabled" -}}

    {{- $single := pick $connection "credentials" "mapped-keys" "secret" "configMap" -}}
    {{- $multiple := omit $connection "credentials" "mapped-keys" "secret" "configMap" -}}
    {{- if and $single $multiple -}}
      {{- fail (printf "Configuration fault: must either be a multi-connection configuration, or a single-connection configuration: %s" ($ | toYaml | nindent 0)) -}}
    {{- end -}}

    {{- if $single -}}
      {{- $single = (include "__arkcase.subsystem-access.sanitize-connection" $single | fromYaml) -}}
      {{- if $single -}}
        {{- $result = merge $result (dict "main" $single "default" "main") -}}
      {{- end -}}
    {{- else if $multiple -}}
      {{- $default := ((hasKey $multiple "default") | ternary (get $multiple "default" | toString) "" | default "main") -}}
      {{- $multiple = omit $multiple "default" -}}
      {{- if not (hasKey $multiple $default) -}}
        {{- fail (printf "Invalid multi-connection configuration: the default is set to '%s', but only these connections are configured: %s" $default (keys $multiple | sortAlpha)) -}}
      {{- end -}}
      {{- range $k, $c := $multiple -}}
        {{- if not $k -}}
          {{- fail (printf "Invalid empty-string connection name: %s" ($ | toYaml | nindent 0)) -}}
        {{- end -}}
        {{- $c = (include "__arkcase.subsystem-access.sanitize-connection" $c | fromYaml) -}}
        {{- if $c -}}
          {{- $result = set $result $k $c -}}
        {{- end -}}
      {{- end -}}
      {{- $result = set $result "default" $default -}}
    {{- end -}}
  {{- end -}}

  {{- $result | toYaml -}}
{{- end -}}

{{- define "__arkcase.subsystem-access.sanitize-connection" -}}
  {{- $connection := $ -}}
  {{- if or (not $connection) (not (kindIs "map" $connection)) -}}
    {{- $connection = dict -}}
  {{- end -}}

  {{- if and (hasKey $connection "enabled") (not (include "arkcase.toBoolean" $connection.enabled)) -}}
    {{- /* If the connection configuration is disabled, treat it as such */ -}}
    {{- $connection = dict -}}
  {{- end -}}

  {{- $result := dict -}}
  {{- if $connection -}}
    {{- $connection = omit $connection "enabled" -}}
    {{- $reference := "" -}}
    {{- $type := "" -}}
    {{- range (list "secret" "configMap") -}}
      {{- $type = . -}}
      {{- if (hasKey $connection $type) -}}
        {{- $v := get $connection $type -}}
        {{- if not (include "arkcase.tools.hostnamePart" $v) -}}
          {{- fail (printf "Invalid %s connection reference [%s]" $type $v) -}}
        {{- end -}}
        {{- $reference = $v -}}
        {{- break -}}
      {{- end -}}
    {{- end -}}

    {{- if $reference -}}
      {{- /* We only tack the connection info if there actually is a target */ -}}
      {{- $result = merge $result (dict "configMap" (eq "configMap" $type) "source" $reference) -}}
      {{- $result = merge $result (include "__arkcase.subsystem-access.sanitize-mapped-keys" $connection | fromYaml) -}}

      {{- $credentials := (include "__arkcase.subsystem-access.sanitize-credentials" $connection.credentials | fromYaml) -}}
      {{- if $credentials -}}
        {{- $result = set $result "credentials" $credentials -}}
      {{- end -}}
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

  {{- $connection := (include "__arkcase.subsystem-access.sanitize-multi-connections" $conf.connection | fromYaml) -}}
  {{- if $connection -}}
    {{- $result = set $result "connection" $connection -}}
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
  {{- $mappings := (get $conf "mapped-keys" | default dict) -}}
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
  {{- $mappings := (get $conf "mapped-keys" | default dict) -}}
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

{{- define "__arkcase.subsystem-access.all-render.sanitize-propValue" -}}
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

{{- define "__arkcase.subsystem-access.all-render" -}}
  {{- $ctx := $.ctx -}}

  {{- /* In case we've only been asked to produce the stuff for a given subsystem */ -}}
  {{- $wantedSubsys := "" -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- $ctx = $ctx.ctx -}}
    {{- if not (include "arkcase.isRootContext" $ctx) -}}
      {{- fail "Must provide the root context ($ or .) as the 'ctx' parameter" -}}
    {{- end -}}
    {{- if and (hasKey $ "subsys") -}}
      {{- $subsys := $.subsys -}}
      {{- if and (kindIs "string" $subsys) (not (empty $subsys)) -}}
        {{- $wantedSubsys = $subsys -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}

  {{- $renderValues := (list "env" "mnt" "vol") -}}
  {{- $render := ($.render | default "" | toString | lower) -}}
  {{- if not (has $render $renderValues) -}}
    {{- fail (printf "Render mode [%s] is not supported - must be one of %s (case-insensitive)" $.render $renderValues) -}}
  {{- end -}}

  {{- $accessConfig := ($ctx.Files.Get "subsys-deps.yaml" | fromYaml | default dict) -}}
  {{- range $subsys, $subsysData := ($accessConfig.consumes | default dict) }}

    {{- if and $wantedSubsys (ne $wantedSubsys $subsys) -}}
      {{- continue -}}
    {{- end -}}

    {{- $params := (dict "ctx" $ctx "subsys" $subsys) }}

    {{- range $conn, $connData := ($subsysData | default dict) }}

      {{- if not $connData }}
        {{- continue }}
      {{- end }}

      {{- $params = (set $params "conn" $conn) }}
      {{- $connVolume := false }}

      {{- range $connProp, $connPropValue := ($connData.properties | default dict) }}

        {{- if not $connPropValue }}
          {{- continue }}
        {{- end }}

        {{- $params = (set $params "key" $connProp) }}

        {{- $newPropValue := (include "__arkcase.subsystem-access.all-render.sanitize-propValue" $connPropValue) }}
        {{- if not $connPropValue }}
              {{- fail (printf "Invalid property value specification for subsystem %s, connection %s, property %s: %s" $subsys $conn $connProp ($connPropValue | toYaml | nindent 0)) }}
        {{- end }}
        {{- $connPropValue = ($newPropValue | fromYaml) }}

        {{- if and $connPropValue.env (eq "env" $render) }}
          {{- $p2 := dict }}
          {{- $env := $connPropValue.env }}
          {{- if (kindIs "string" $env) }}
            {{- if not (regexMatch "^[a-zA-Z_][a-zA-Z0-9_]*$" $env) }}
              {{- fail (printf "Invalid environment variable name: [%s] for subsystem %s, connection %s, property %s" $env $subsys $conn $connProp) }}
            {{- end }}
            {{- $p2 = set $p2 "name" $env }}
          {{- end }}
          {{- include "arkcase.subsystem-access.env.conn" (merge $p2 $params) | nindent 0 }}
        {{- end }}

        {{- if $connPropValue.path }}
          {{- if (eq "mnt" $render) }}
            {{- $p2 := dict }}
            {{- $path := $connPropValue.path }}
            {{- if (kindIs "string" $path) }}
              {{- if not (regexMatch "^/[^/]+(/[^/]+)*$" $path) }}
                {{- fail (printf "Invalid path specification: [%s] for subsystem %s, connection %s, property %s" $path $subsys $conn $connProp) }}
              {{- end }}
              {{- $p2 = set $p2 "mountPath" $path }}
            {{- end }}
            {{- include "arkcase.subsystem-access.volumeMount.conn" (merge $p2 $params) | nindent 0 }}
          {{- end }}
          {{- $connVolume = true }}
        {{- end }}
      {{- end }}

      {{- $params = omit $params "key" }}
      {{- if and $connVolume (eq "vol" $render) }}
        {{- include "arkcase.subsystem-access.volume.conn" $params | nindent 0 }}
      {{- end }}

      {{- range $cred, $credData := ($connData.credentials | default dict) }}

        {{- if not $credData }}
          {{- continue }}
        {{- end }}

        {{- $params := (set $params "type" $cred) }}
        {{- $credVolume := false }}

        {{- range $credProp, $credPropValue := $credData }}
          {{- if not $credPropValue }}
            {{- continue }}
          {{- end }}

          {{- $params = (set $params "key" $credProp) }}

          {{- $newPropValue := (include "__arkcase.subsystem-access.all-render.sanitize-propValue" $credPropValue) }}
          {{- if not $credPropValue }}
            {{- fail (printf "Invalid property value specification for subsystem %s, connection %s, credential %s, property %s: %s" $subsys $conn $cred $credProp ($credPropValue | toYaml | nindent 0)) }}
          {{- end }}
          {{- $credPropValue = ($newPropValue | fromYaml) }}

          {{- if and $credPropValue.env (eq "env" $render) }}
            {{- $p2 := dict }}
            {{- $env := $credPropValue.env }}
            {{- if (kindIs "string" $env) }}
              {{- if not (regexMatch "^[a-zA-Z_][a-zA-Z0-9_]*$" $env) }}
                {{- fail (printf "Invalid environment variable name: [%s] for subsystem %s, connection %s, credential %s, property %s" $env $subsys $conn $cred $credProp) }}
              {{- end }}
              {{- $p2 = set $p2 "name" $env }}
            {{- end }}
            {{- include "arkcase.subsystem-access.env.cred" (merge $p2 $params) | nindent 0 }}
          {{- end }}

          {{- if $credPropValue.path }}
            {{- if (eq "mnt" $render) }}
              {{- $p2 := dict }}
              {{- $path := $credPropValue.path }}
              {{- if (kindIs "string" $path) }}
                {{- if not (regexMatch "^/[^/]+(/[^/]+)*$" $path) }}
                  {{- fail (printf "Invalid path specification: [%s] for subsystem %s, connection %s, credential %s, property %s" $path $subsys $conn $cred $credProp) }}
                {{- end }}
                {{- $p2 = set $p2 "mountPath" $path }}
              {{- end }}
              {{- include "arkcase.subsystem-access.volumeMount.cred" (merge $p2 $params) | nindent 0 }}
            {{- end }}
            {{- $credVolume = true }}
          {{- end }}
          {{- $params = omit $params "key" }}

          {{- if and $credVolume (eq "vol" $render) }}
            {{- include "arkcase.subsystem-access.volume.cred" $params | nindent 0 }}
          {{- end }}
        {{- end }}
      {{- end }}
    {{- end }}
  {{- end }}
{{- end }}

{{- define "arkcase.subsystem-access.all.env" -}}
  {{- include "__arkcase.subsystem-access.all-render" (dict "ctx" $ "render" "env") -}}
{{- end -}}

{{- define "arkcase.subsystem-access.all.volumeMount" -}}
  {{- include "__arkcase.subsystem-access.all-render" (dict "ctx" $ "render" "mnt") -}}
{{- end -}}

{{- define "arkcase.subsystem-access.all.volume" -}}
  {{- include "__arkcase.subsystem-access.all-render" (dict "ctx" $ "render" "vol") -}}
{{- end -}}
