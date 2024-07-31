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

  {{- /* Now, validate! */ -}}
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

  {{- $release := $ctx.Release.Name -}}
  {{- $result :=
     dict
       "ctxIsRoot" (not $checkParams)
       "local" (eq $subsys $thisSubsys)
       "release" $release
       "subsys" $subsys
       "conn" $conn
       "key" $key
       "name" $name
       "mountPath" $mountPath
       "optional" $optional
       "source" (printf "%s-%s-%s" $release $subsys $conn)
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
    {{- if not $mountPath -}}
      {{- $result = set $result "mountPath" (printf "%s/%s" $result.mountPath $key) -}}
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
  {{- $params := (include "__arkcase.subsystem-access.extract-params" $ | fromYaml) -}}
  {{- $ctx := ($params.ctxIsRoot | ternary $ $.ctx) -}}

  {{- $regex := "^[a-z0-9]+(-[a-z0-9]+)*$" -}}
  {{- if (not (regexMatch $regex $params.conn)) -}}
    {{- fail (printf "Invalid connection name [%s] for subsystem [%s] - must match /%s/" $params.conn $params.subsys $params.conn $regex) -}}
  {{- end -}}

  {{- /* Get the subsystem configuration */ -}}
  {{- $conf := (include "arkcase.subsystem-access.conf" $ | fromYaml) -}}

  {{- $name := $params.source -}}
  {{- if $conf.external -}}
    {{- /* Is the connection an external one? Were we given a name for its resource? */ -}}
    {{- $conn := $conf.external.connection | default dict -}}
    {{- if (hasKey $conn $params.conn) -}}
      {{- $conn := get $conn $params.conn -}}
      {{- $name = $conn.source | default $name -}}
    {{- end -}}
  {{- end -}}
  {{- $name -}}
{{- end -}}

{{- define "__arkcase.subsystem-access.env.render" -}}
  {{- $params := $ -}}
- name: {{ $params.name | quote }}
  valueFrom:
    {{ $params.sourceType }}KeyRef:
      name: {{ $params.sourceName | quote }}
      key: {{ $params.key | quote }}
      optional: {{ $params.optional }}
{{- end -}}

{{- define "__arkcase.subsystem-access.deps" -}}
  {{- $params := (include "__arkcase.subsystem-access.extract-params" $ | fromYaml) -}}
  {{- $ctx = ($params.ctxIsRoot | ternary $ $.ctx) -}}

  {{- if $params.ctxIsRoot -}}
  {{- else -}}
    {{- /* Check to see if we were given limitations */ -}}
  {{- end -}}

  {{- $result := list -}}

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

{{- /* Params: subsys?, conn?, type?, key, name?, optional? */ -}}
{{- define "arkcase.subsystem-access.env" -}}
  {{- $renderList := list -}}
  {{- $ctx := $ -}}
  {{- if (hasKey $ "key") -}}
    {{- $params := (include "__arkcase.subsystem-access.extract-params" $ | fromYaml) -}}
    {{- $ctx = ($params.ctxIsRoot | ternary $ $.ctx) -}}

    {{- /* If we're given a key, then we only do that key for the given subsystem and connection */ -}}
    {{- $renderList = append $renderList $params -}}
  {{- else -}}
    {{- /* If we weren't given a key, then we read stuff from the subsys-deps.yaml and build our renderList */ -}}
    {{- $result := (include "__arkcase.subsystem-access.deps" $ | fromYaml) -}}
    {{- $ctx = ($result.ctxIsRoot | ternary $ $.ctx) -}}

    {{- /* The render list may or may not include stuff for all dependencies from all subsystems, or only the selected ones */ -}}
    {{- /* Every item must contain the keys: [subsys, conn, name, key, optional] */ -}}
    {{- $renderList = $result.renderList -}}
  {{- end -}}

  {{- $range $p := $renderList -}}
    {{- $conf := (include "arkcase.subsystem-access.conf" (dict "ctx" $ctx "subsys" $p.subsys) | fromYaml) -}}
    {{- $conf = (($conf.external).connection | default dict) -}}
    {{- if (hasKey $conf $p.conn) -}}
      {{- $conf = (get $conf $p.conn | default dict) -}}
    {{- else -}}
      {{- $conf = dict -}}
    {{- end -}}

    {{- $env := pick $p "name" "optional" -}}

    {{- /* For now, we only support secrets here */ -}}
    {{- $env = set $env "sourceType" "secret" -}}

    {{- /* If the source isn't explicitly set, we must render our own */ -}}
    {{- $env = set $env "sourceName" ((hasKey $conf "source") | ternary $conf.source (include "arkcase.subsystem-access.name" $)) -}}

    {{- /* Now we try to find any mappings for this key */ -}}
    {{- $mappings := (get $conf "mappings" | default dict) -}}
    {{- $env = set $env "key" ((hasKey $mappings $p.key) | ternary (get $mappings $p.key) $p.key) -}}
    {{- include "__arkcase.subsystem-access.env.render" $env -}}
  {{- end -}}
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
