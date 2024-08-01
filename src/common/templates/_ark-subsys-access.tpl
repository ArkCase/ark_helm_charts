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

  {{- $die := (contains "$" $str) -}}

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

  {{- ($hasRegex | ternary (mustRegexReplaceAll $regex $str $replace) $str) -}}
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

  {{- /* These are the parameters we're interested in */ -}}
  {{- $thisSubsys := (include "arkcase.subsystem.name" $ctx) -}}
  {{- $subsys := $thisSubsys -}}
  {{- $conn := "main" -}}
  {{- $key := "" -}}
  {{- $name := "" -}}
  {{- $mountPath := "" -}}
  {{- $optional := false -}}

  {{- /* Only consider the parameters if we weren't sent only the root context */ -}}
  {{- if $checkParams -}}
    {{- $subsys = ((hasKey $ "subsys") | ternary ($.subsys | default "" | toString) $subsys) | default $subsys -}}
    {{- $conn = ((hasKey $ "conn") | ternary ($.conn | default "" | toString) $conn) | default $conn -}}
    {{- $key = ((hasKey $ "key") | ternary ($.key | default "" | toString) $key) | default $key -}}
    {{- $name = ((hasKey $ "name") | ternary ($.name | default "" | toString) $name) | default $name -}}
    {{- $mountPath = ((hasKey $ "mountPath") | ternary ($.mountPath | default "" | toString) $mountPath) | default $mountPath -}}
    {{- $optional = ((hasKey $ "optional") | ternary $.optional $optional) -}}
    {{- $optional = (not (empty (include "arkcase.toBoolean" $optional))) -}}
  {{- end -}}

  {{- $regex := "^[a-z0-9]+(-[a-z0-9]+)*$" -}}

  {{- if (not (regexMatch $regex $subsys)) -}}
    {{- fail (printf "Invalid subsystem name [%s] - must match /%s/" $subsys $regex) -}}
  {{- end -}}

  {{- if (not (regexMatch $regex $conn)) -}}
    {{- fail (printf "Invalid connection name [%s] for subsystem %s - must match /%s/" $conn $subsys $regex) -}}
  {{- end -}}

  {{- if $key -}}
    {{- $regex = "^[-._a-zA-Z0-9]+$" -}}
    {{- if (not (regexMatch $regex $key)) -}}
      {{- fail (printf "Invalid configuration key [%s] for connection %s, subsystem %s - must match /%s/" $key $conn $subsys $regex) -}}
    {{- end -}}
  {{- end -}}

  {{- $vars := (dict "subsys" $subsys "conn" $conn "key" ($key | snakecase)) -}}
  {{- if $name -}}
    {{- $name = (include "__arkcase.subsystem-access.expand-vars" (dict "str" $name "params" $vars "regex" "[-.]" "replace" "_" "defaultCase" "u")) -}}
  {{- end -}}

  {{- if $mountPath -}}
    {{- $mountPath = (include "__arkcase.subsystem-access.expand-vars" (dict "str" $mountPath "params" $vars)) -}}
  {{- end -}}

  {{- $result :=
     dict
       "ctxIsRoot" (not $checkParams)
       "local" (eq $subsys $thisSubsys)
       "subsys" $subsys
       "conn" $conn
       "key" $key
       "name" $name
       "mountPath" $mountPath
       "optional" $optional
  -}}

  {{- /* Render the name, if a one wasn't given */ -}}
  {{- if (not $result.name) -}}
    {{- /* ARKCASE_${SUBSYS}_${CONN} */ -}}
    {{- $subsysPart := ($result.local | ternary "" (printf "_%s" $result.subsys)) -}}
    {{- $result = set $result "name" (printf "ARKCASE%s_%s" $subsysPart $conn | upper | replace "-" "_" | replace "." "_") -}}
  {{- end -}}

  {{- /* Render the mountPath, if one wasn't given */ -}}
  {{- if not $result.mountPath -}}
    {{- /* /srv/arkcase/${subsys}/${conn} */ -}}
    {{- $subsysPart := ($result.local | ternary "" (printf "/%s" $result.subsys)) -}}
    {{- $result = set $result "mountPath" (printf "/srv/arkcase%s/%s" $subsysPart $conn) -}}
  {{- end -}}

  {{- if $key -}}
    {{- /* If a name wasn't given, then append the key */ -}}
    {{- if not $name -}}
      {{- $result = set $result "name" (printf "%s_%s" $result.name ($key | snakecase | upper | replace "-" "_" | replace "." "_")) -}}
    {{- end -}}
    {{- /* If a mountPath wasn't given, then append the key */ -}}
    {{- if not $mountPath -}}
      {{- $result = set $result "mountPath" (printf "%s/%s" $result.mountPath $key) -}}
    {{- end -}}
  {{- end -}}

  {{- if not (regexMatch "^/[^/]+(/[^/]+)*$" $result.mountPath) -}}
    {{- fail (printf "Invalid mountPath specification: [%s]" $result.mountPath) -}}
  {{- end -}}

  {{- $result | toYaml -}}
{{- end -}}

{{- define "__arkcase.subsystem-access.extract-params-mapped" -}}
  {{- $params := (include "__arkcase.subsystem-access.extract-params" $ | fromYaml) -}}
  {{- $ctx := ($params.ctxIsRoot | ternary $ $.ctx) -}}

  {{- $conf := (include "arkcase.subsystem-access.conf" (dict "ctx" $ctx "subsys" $params.subsys) | fromYaml) -}}
  {{- $conf = (($conf.external).connection | default dict) -}}
  {{- $conf := (get $conf $params.conn | default dict) -}}

  {{- $release := $ctx.Release.Name -}}

  {{- $params = set $params "release" $release -}}
  {{- $params = set $params "volumeName" (printf "vol-subsys-%s-%s" $params.subsys $params.conn) -}}

  {{- $mappedKey := $params.key -}}
  {{- if and $conf $conf.mappings -}}
    {{- if and $mappedKey $conf.mappings -}}
      {{- $regex := "^[-._a-zA-Z0-9]+$" -}}
      {{- /*  Identify the actual mapped key, and use it */ -}}
      {{- if (hasKey $conf.mappings $mappedKey) -}}
        {{- $mappedKey = get $conf.mappings $mappedKey -}}
      {{- end -}}

      {{- if (not (regexMatch $regex $mappedKey)) -}}
        {{- fail (printf "Invalid configuration mapped key [%s] for key %s, connection %s, subsystem %s - must match /%s/" $mappedKey $params.key $params.conn $params.subsys $params.regex) -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
  {{- $params = set $params "mappedKey" $mappedKey -}}

  {{- /* Get the actual source */ -}}
  {{- $source := (printf "%s-%s-%s" $release $params.subsys $params.conn) -}}
  {{- if (hasKey $conf "source") -}}
    {{- $regex := "^[a-z0-9]+(-[a-z0-9]+)*$" -}}
    {{- if (not (regexMatch $regex $conf.source)) -}}
      {{- fail (printf "Invalid connection source [%s] for connection %s, subsystem %s - must match /%s/" $conf.source $params.conn $params.subsys $regex) -}}
    {{- end -}}
    {{- $source = $conf.source -}}
  {{- end -}}
  {{- $params = set $params "source" $source -}}

  {{- /* We only support secrets for now, b/c supporting both adds complexity that we don't really need */ -}}
  {{- $params = set $params "sourceType" "secret" -}}

  {{- $params | toYaml -}}
{{- end -}}

{{- define "__arkcase.subsystem-access.sanitize-settings" -}}
  {{- $settings := $ -}}
  {{- if or (not $settings) (not (kindIs "map" $settings)) -}}
    {{- $settings = dict -}}
  {{- end -}}
  {{- $settings | toYaml -}}
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

{{- define "__arkcase.subsystem-access.sanitize-connection" -}}
  {{- $connection := $.c -}}

  {{- /* It may only be a non-empty map (with specific keys) or a non-empty string (the resource name) */ -}}
  {{- if $connection -}}
    {{- if (kindIs "string" $connection) -}}
      {{- $connection = dict "source" $connection -}}
    {{- else if not (kindIs "map" $connection) -}}
      {{- $connection = dict -}}
    {{- end -}}
  {{- end -}}

  {{- $result := dict -}}
  {{- if $connection -}}
    {{- $resource := pick $connection "source" "inherit-mappings" "mappings" -}}
    {{- $settings := omit $connection "source" "inherit-mappings" "mappings" -}}
    {{- if and $resource $settings -}}
      {{- fail (printf "Connection definitions may only supply resource information (source, et al) or connectivity settings (all other values): %s" ($connection | toYaml | nindent 0)) -}}
    {{- end -}}

    {{- if $resource -}}
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

    {{- /* If we're using explicitly-set connectivity settings, then we return them */ -}}
    {{- if $settings -}}
      {{- $result = set $result "settings" $settings -}}
    {{- end -}}
  {{- end -}}
  {{- $result | toYaml -}}
{{- end -}}

{{- define "__arkcase.subsystem-access.sanitize-external" -}}
  {{- $external := $ -}}

  {{- if $external -}}
    {{- /* If it's a list, then treat it as an empty dict */ -}}
    {{- if (kindIs "slice" $external) -}}
      {{- $external = dict -}}
    {{- end -}}

    {{- /* If it's not a list, and it's not a map, it must be a scalar value */ -}}
    {{- if not (kindIs "map" $external) -}}
      {{- $external = dict "enabled" (not (empty (include "arkcase.toBoolean" $external))) -}}
    {{- end -}}
  {{- else -}}
    {{- $external = dict -}}
  {{- end -}}

  {{- /* The value should be sanitized to a map by now ... ignore empty maps */ -}}
  {{- if $external -}}
    {{- /* If the credential configuration is disabled, treat it as such */ -}}
    {{- if and (hasKey $external "enabled") (not (include "arkcase.toBoolean" $external.enabled)) -}}
      {{- $external = dict -}}
    {{- end -}}
  {{- end -}}

  {{- $result := dict -}}
  {{- if $external -}}
    {{- /* Make sure we don't return an empty map, whatever happens */ -}}
    {{- $result = set $result "enabled" true -}}

    {{- $mappings := (include "__arkcase.subsystem-access.sanitize-mappings" $external.mappings | fromYaml) -}}
    {{- $connection := dict -}}
    {{- range $k, $c := $external.connection -}}
      {{- if not $k -}}
        {{- fail (printf "Invalid empty-string connection name found: %s" ($external.connection | toYaml | nindent 0)) -}}
      {{- end -}}
      {{- $r := (include "__arkcase.subsystem-access.sanitize-connection" (dict "c" $c "m" $mappings) | fromYaml) -}}
      {{- if $r -}}
        {{- $connection = set $connection $k $r -}}
      {{- else -}}
        {{- /* TODO: raise the correct error? */ -}}
      {{- end -}}
    {{- end -}}
    {{- $result = set $result "connection" $connection -}}
  {{- end -}}

  {{- $result | toYaml -}}
{{- end -}}

{{- define "__arkcase.subsystem-access.conf.render" -}}
  {{- $params := (include "__arkcase.subsystem-access.extract-params" $ | fromYaml) -}}
  {{- $ctx := ($params.ctxIsRoot | ternary $ $.ctx) -}}

  {{- /* Gather up the configurations for the given subsystem */ -}}
  {{- $conf := dict -}}

  {{- /* First apply the global settings, which are the overrides */ -}}
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
      {{- /* We add the local configurations later b/c the global ones override */ -}}
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

{{- define "arkcase.subsystem.conf" -}}
  {{- include "arkcase.subsystem-access.conf" $ -}}
{{- end -}}

{{- define "arkcase.subsystem-access.name" -}}
  {{- $params := (include "__arkcase.subsystem-access.extract-params-mapped" $ | fromYaml) -}}
  {{- $params.source -}}
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

{{- define "__arkcase.subsystem-access.deps-compute.env" -}}
  {{-
    $result := dict
      "name" $.name
      "valueFrom" (
        dict
          (printf "%sKeyRef" $.sourceType) (
            dict
              "name" $.source
              "key" $.mappedKey
              "optional" $.optional
          )
      )
  -}}
  {{- $result | toYaml -}}
{{- end -}}

{{- define "__arkcase.subsystem-access.deps-compute.volumeMount" -}}
  {{-
    $result := dict
      "name" $.volumeName
      "mountPath" $.mountPath
      "subPath" $.mappedKey
      "readOnly" true
  -}}
  {{- $result | toYaml -}}
{{- end -}}

{{- define "__arkcase.subsystem-access.deps-compute.volume" -}}
  {{-
    $result := dict
      "name" $.volumeName
      $.sourceType (
        dict
          ((eq "secret" $.sourceType) | ternary "secretName" "name") $.source
          "defaultMode" 0444
          "optional" $.optional
      )
  -}}
  {{- $result | toYaml -}}
{{- end -}}

{{- define "__arkcase.subsystem-access.deps-compute" -}}
  {{- $ctx := $ -}}
  {{- $accessConfig := ($ctx.Files.Get "subsys-deps.yaml" | fromYaml | default dict) -}}

  {{- $resultEnv := dict -}}
  {{- $resultMnt := dict -}}
  {{- $resultVol := dict -}}

  {{- $consumes := ($accessConfig.consumes | default dict) -}}
  {{- range $subsys := (keys $consumes | sortAlpha) -}}
    {{- $subsysData := get $consumes $subsys -}}

    {{- /* If there's nothing to consume from this subsystem, skip it */ -}}
    {{- if or (not $subsysData) (not (kindIs "map" $subsysData)) -}}
      {{- continue -}}
    {{- end -}}

    {{- if (eq $subsys "$self") -}}
      {{- /* Resolve this to the real subsystem name */ -}}
      {{- $subsys = (include "arkcase.subsystem.name" $ctx) -}}
    {{- end -}}

    {{- $subsysEnv := dict -}}
    {{- $subsysMnt := dict -}}
    {{- $subsysVol := dict -}}

    {{- $params := (dict "ctx" $ctx "subsys" $subsys) -}}

    {{- /* Iterate over all the dependencies listed for this subsystem */ -}}
    {{- range $conn := (keys $subsysData | sortAlpha) -}}
      {{- $connData := get $subsysData $conn -}}

      {{- /* If there's nothing to consume from this subsystem connection, skip it */ -}}
      {{- if or (not $connData) (not (kindIs "map" $connData)) -}}
        {{- continue -}}
      {{- end -}}

      {{- $params = (set $params "conn" $conn) -}}

      {{- $connEnv := dict -}}
      {{- $connMnt := dict -}}

      {{- /* $connData is the set of properties */ -}}
      {{- range $connProp := (keys $connData | sortAlpha) -}}
        {{- $connPropValue := (get $connData $connProp) -}}
        {{- if not $connPropValue -}}
          {{- continue -}}
        {{- end -}}

        {{- $newPropValue := (include "__arkcase.subsystem-access.all.render.sanitize-propValue" $connPropValue) -}}
        {{- if not $newPropValue -}}
          {{- fail (printf "Invalid property value specification for subsystem %s, connection %s, property %s: %s" $subsys $conn $connProp ($connPropValue | toYaml | nindent 0)) -}}
        {{- end -}}
        {{- $connPropValue = ($newPropValue | fromYaml) -}}

        {{- $params = (set $params "key" $connProp) -}}

        {{- $computeParams := (include "__arkcase.subsystem-access.extract-params-mapped" $params | fromYaml) -}}

        {{- if $connPropValue.env -}}
          {{- /* For now we only support secrets */ -}}
          {{- $p2 := dict "sourceType" "secret" -}}
          {{- $env := $connPropValue.env -}}
          {{- if (kindIs "string" $env) -}}
            {{- $p2 = set $p2 "name" $env -}}
          {{- end -}}
          {{- $connEnv = set $connEnv $connProp (include "__arkcase.subsystem-access.deps-compute.env" (merge $p2 $computeParams) | fromYaml) -}}
        {{- end -}}

        {{- if $connPropValue.path -}}
          {{- $p2 := dict "sourceType" "secret" -}}
          {{- $path := $connPropValue.path -}}
          {{- if (kindIs "string" $path) -}}
            {{- $p2 = set $p2 "mountPath" $path -}}
          {{- end -}}
          {{- $connMnt = set $connMnt $connProp (include "__arkcase.subsystem-access.deps-compute.volumeMount" (merge $p2 $computeParams) | fromYaml) -}}
        {{- end -}}
      {{- end -}}

      {{- if $connEnv -}}
        {{- $subsysEnv = set $subsysEnv $conn $connEnv -}}
      {{- end -}}

      {{- if $connMnt -}}
        {{- $subsysMnt = set $subsysMnt $conn $connMnt -}}

        {{- $p2 := dict "sourceType" "secret" -}}

        {{- /* There's only one volume per connection */ -}}
        {{- $subsysVol = set $subsysVol $conn (include "__arkcase.subsystem-access.deps-compute.volume" (merge $p2 (include "__arkcase.subsystem-access.extract-params-mapped" (omit $params "key") | fromYaml)) | fromYaml) -}}
      {{- end -}}
    {{- end -}}

    {{- if $subsysEnv -}}
      {{- $resultEnv = set $resultEnv $subsys $subsysEnv -}}
    {{- end -}}

    {{- if $subsysMnt -}}
      {{- $resultMnt = set $resultMnt $subsys $subsysMnt -}}
    {{- end -}}

    {{- if $subsysVol -}}
      {{- $resultVol = set $resultVol $subsys $subsysVol -}}
    {{- end -}}
  {{- end -}}
  {{- dict "env" $resultEnv "volumeMount" $resultMnt "volume" $resultVol | toYaml -}}
{{- end -}}

{{- define "__arkcase.subsystem-access.deps" -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The parameter given must be the root context (. or $)" -}}
  {{- end -}}

  {{- $cacheKey := "ArkCase-Subsystem-Access-Dependencies" -}}
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
    {{- $yamlResult = (include "__arkcase.subsystem-access.deps-compute" $ctx) -}}
    {{- $masterCache = set $masterCache $masterKey ($yamlResult | fromYaml) -}}
  {{- else -}}
    {{- $yamlResult = get $masterCache $masterKey | toYaml -}}
  {{- end -}}
  {{- $yamlResult -}}
{{- end -}}

{{- /* Params: subsys?, conn?, type?, key?, name?, optional? */ -}}
{{- define "__arkcase.subsystem-access.interface" -}}
  {{- $params := (include "__arkcase.subsystem-access.extract-params" $.params | fromYaml) -}}
  {{- $ctx := ($params.ctxIsRoot | ternary $.params $.params.ctx) -}}

  {{- $supportsKey := (ne $.type "volume") -}}

  {{- /* If we're given a key, then we must use it in the filter */ -}}
  {{- $filter := dict "key" (and (not $params.ctxIsRoot) (hasKey $.params "key")) -}}

  {{- /* If we're given a connection or filtering by key, then we must use the computed connection in the filter */ -}}
  {{- $filter = set $filter "conn" (or $filter.key (and (not $params.ctxIsRoot) (hasKey $.params "conn"))) -}}

  {{- /* If we're given a subsys or filtering by connection, then we must use the computed subsystem in the filter */ -}}
  {{- $filter = set $filter "subsys" (or $filter.conn (and (not $params.ctxIsRoot) (hasKey $.params "subsys"))) -}}

  {{- $depsData := (include "__arkcase.subsystem-access.deps" $ctx | fromYaml) -}}
  {{- $depsData = (get $depsData $.type | default dict) -}}
  {{- $renderTemplate := (printf "__arkcase.subsystem-access.deps-compute.%s" $.type) -}}

  {{- $result := list -}}
  {{- range $subsys := ($filter.subsys | ternary (list $params.subsys) (keys $depsData | sortAlpha)) -}}
    {{- $args := (dict "ctx" $ctx "subsys" $subsys) -}}
    {{- $subsysData := (get $depsData $subsys | default dict) -}}
    {{- range $conn := ($filter.conn | ternary (list $params.conn) (keys $subsysData | sortAlpha)) -}}
      {{- $args = set $args "conn" $conn -}}
      {{- $connData := (get $subsysData $conn | default dict) -}}
      {{- if $supportsKey -}}
        {{- range $key := ($filter.key | ternary (list $params.key) (keys $connData | sortAlpha)) -}}
          {{- $args = set $args "key" $key -}}
          {{- $keyData := (get $connData $key | default dict) -}}
          {{- if not $keyData -}}
            {{- $keyParams := (include "__arkcase.subsystem-access.extract-params-mapped" $args | fromYaml) -}}
            {{- $keyData = (include $renderTemplate $keyParams | fromYaml) -}}
          {{- end -}}
          {{- $result = append $result $keyData -}}
        {{- end -}}
      {{- else -}}
        {{- if not $connData -}}
          {{- $connParams := (include "__arkcase.subsystem-access.extract-params-mapped" $args | fromYaml) -}}
          {{- $connData = (include $renderTemplate $connParams | fromYaml) -}}
        {{- end -}}
        {{- $result = append $result $connData -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
  {{- $result | toYaml -}}
{{- end }}

{{- define "arkcase.subsystem-access.env" -}}
  {{- include "__arkcase.subsystem-access.interface" (dict "params" $ "type" "env") -}}
{{- end -}}

{{- define "arkcase.subsystem-access.volumeMount" -}}
  {{- include "__arkcase.subsystem-access.interface" (dict "params" $ "type" "volumeMount") -}}
{{- end -}}

{{- define "arkcase.subsystem-access.volume" -}}
  {{- include "__arkcase.subsystem-access.interface" (dict "params" $ "type" "volume") -}}
{{- end -}}
