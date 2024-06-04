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

  {{- range $v := (list "subsys" "type" "key" "rand-ascii" "rand-alpha-num") -}}

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
  {{- /* Only consider the parameters if we weren't sent only the root context */ -}}
  {{- if $checkParams -}}
    {{- $subsys = ((hasKey $ "subsys") | ternary ($.subsys | default "" | toString) $subsys) | default $subsys -}}
  {{- end -}}

  {{- $result := dict "ctxIsRoot" (not $checkParams) "release" $ctx.Release.Name "subsys" $subsys "local" (eq $subsys $thisSubsys) -}}
  {{- $result = set $result "radix" (printf "%s-%s" $result.release $result.subsys) -}}
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

  {{- $result := dict -}}
  {{- if $credentials -}}
    {{- $enabled := or (not (hasKey $credentials "enabled")) (include "arkcase.toBoolean" $credentials.enabled) -}}
    {{- if $enabled -}}
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
  {{- end -}}
  {{- $result | toYaml -}}
{{- end -}}

{{- define "__arkcase.subsystem-access.sanitize-connection" -}}
  {{- $connection := $ -}}
  {{- if or (not $connection) (not (kindIs "map" $connection)) -}}
    {{- $connection = dict -}}
  {{- end -}}

  {{- $result := dict -}}
  {{- if $connection -}}
    {{- $enabled := or (not (hasKey $connection "enabled")) (include "arkcase.toBoolean" $connection.enabled) -}}
    {{- $reference := "" -}}
    {{- $type := "" -}}
    {{- if $enabled -}}
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
    {{- end -}}

    {{- if $reference -}}
      {{- /* We only tack the connection info if there actually is a target */ -}}
      {{- $result = set $result "configMap" (eq "configMap" $type) -}}
      {{- $result = set $result "source" $reference -}}
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

  {{- $connection := (include "__arkcase.subsystem-access.sanitize-connection" $conf.connection | fromYaml) -}}
  {{- if $connection -}}
    {{- $result = set $result "connection" $connection -}}
  {{- end -}}

  {{- $settings := (include "__arkcase.subsystem-access.sanitize-settings" $conf.settings | fromYaml) -}}
  {{- if $settings -}}
    {{- $result = set $result "settings" $settings -}}
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
  {{- (empty $conf.connection) | ternary "" "true" -}}
{{- end -}}

{{- define "arkcase.subsystem-access.external.admin" -}}
  {{- $params := (include "__arkcase.subsystem-access.extract-params" $ | fromYaml) -}}
  {{- $ctx := ($params.ctxIsRoot | ternary $ $.ctx) -}}
  {{- $args := (dict "ctx" $ctx "type" "cred-admin" "subsys" $params.subsys) -}}
  {{- $conf := (include "arkcase.subsystem-access.conf" $args | fromYaml) -}}
  {{- $creds := ((get (($conf.connection).credentials | default dict) "admin") | default dict) -}}
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
    {{- fail (printf "Invalid resource type [%s] for subsystem [%s] - must match /%s/" $type $params.subsys $regex) -}}
  {{- end -}}
  {{- if not (hasPrefix "cred-" $type) -}}
    {{- $type = (printf "%s%s" "cred-" $type) -}}
  {{- end -}}
  {{- $args := (dict "ctx" $ctx "type" $type "subsys" $params.subsys) -}}
  {{- $conf := (include "arkcase.subsystem-access.conf" $args | fromYaml) -}}
  {{- $creds := ((get (($conf.connection).credentials | default dict) (trimPrefix "cred-" $type)) | default dict) -}}
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
    {{- fail (printf "Invalid resource type [%s] for subsystem [%s] - must match /%s/" $type $params.subsys $regex) -}}
  {{- end -}}
  {{- printf "%s-%s" $params.radix $type -}}
{{- end -}}

{{- /* Params: subsys? */ -}}
{{- define "arkcase.subsystem-access.name.conn" -}}
  {{- $params := (include "__arkcase.subsystem-access.extract-params" $ | fromYaml) -}}
  {{- $ctx := ($params.ctxIsRoot | ternary $ $.ctx) -}}
  {{- include "__arkcase.subsystem-access.name" (dict "ctx" $ctx "type" "conn" "subsys" $params.subsys) -}}
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
    {{- fail (printf "Invalid resource type [%s] for subsystem [%s] - must match /%s/" $type $params.subsys $regex) -}}
  {{- end -}}
  {{- if not (hasPrefix "cred-" $type) -}}
    {{- $type = (printf "%s%s" "cred-" $type) -}}
  {{- end -}}
  {{- include "__arkcase.subsystem-access.name" (dict "ctx" $ctx "type" $type "subsys" $params.subsys) -}}
{{- end -}}

{{- define "arkcase.subsystem-access.name.admin" -}}
  {{- $params := (include "__arkcase.subsystem-access.extract-params" $ | fromYaml) -}}
  {{- $ctx := ($params.ctxIsRoot | ternary $ $.ctx) -}}
  {{- include "__arkcase.subsystem-access.name" (dict "ctx" $ctx "type" "cred-admin" "subsys" $params.subsys) -}}
{{- end -}}

{{- /* Params: subsys?, type?, key, name?, optional? */ -}}
{{- define "__arkcase.subsystem-access.env" -}}
  {{- $params := (include "__arkcase.subsystem-access.extract-params" $ | fromYaml) -}}
  {{- if or $params.ctxIsRoot (not (hasKey $ "key")) -}}
    {{- fail "Must provide a 'key' parameter" -}}
  {{- end -}}
  {{- $ctx := $.ctx -}}

  {{- $type := "access" -}}
  {{- if not $params.ctxIsRoot -}}
    {{- $type = ($.type | default $type | toString) -}}
  {{- end -}}

  {{- $key := $.key -}}
  {{- $regex := "^[a-zA-Z0-9_.-]+$" -}}
  {{- if not (regexMatch $regex $key) -}}
    {{- fail (printf "Invalid key [%s] from the configuration resource of type %s for subsystem %s - must match /%s/" $key $params.type $params.subsys $regex) -}}
  {{- end -}}

  {{- $envVarName := "" -}}
  {{- if (hasKey $ "name") -}}
    {{- $vars := (dict "subsys" $params.subsys "type" $type "key" $key "defaultCase" "u") -}}
    {{- $envVarName = (include "__arkcase.subsystem-access.expand-vars" (dict "str" $.name "params" $vars "regex" "[-.]" "replace" "_" "defaultCase" "u")) -}}
    {{- $regex := "^[a-zA-Z0-9_]+$" -}}
    {{- if not (regexMatch $regex $envVarName) -}}
      {{- fail (printf "Invalid envvar name [%s] (final result = [%s]) for the key %s from the configuration resource of type %s for subsystem %s - must match /%s/" $.name $envVarName $key $params.type $params.subsys $regex) -}}
    {{- end -}}
  {{- else -}}
    {{- $envVarName = "arkcase" -}}
    {{- if not $params.local -}}
      {{- $envVarName = (printf "%s_%s" $envVarName $params.subsys) -}}
    {{- end -}}
    {{- $envVarName = (printf "%s_%s_%s" $envVarName $type $key | upper) -}}
    {{- $envVarName = regexReplaceAll "[-.]" $envVarName "_" -}}
  {{- end -}}

  {{- $sourceName := "" -}}
  {{- $sourceNameTemplate := "" -}}
  {{- $conf := (include "arkcase.subsystem-access.conf" $ | fromYaml) -}}
  {{- $conf = ($conf.connection | default dict) -}}

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
{{- end -}}

{{- define "arkcase.subsystem-access.env.conn" -}}
  {{- $params := (include "__arkcase.subsystem-access.extract-params" $ | fromYaml) -}}
  {{- $ctx := ($params.ctxIsRoot | ternary $ $.ctx) -}}
  {{- if or $params.ctxIsRoot (not (hasKey $ "key")) -}}
    {{- fail "Must provide a 'key' parameter" -}}
  {{- end -}}
  {{- $args := merge (dict "ctx" $ctx "type" "conn" "subsys" $params.subsys) (pick $ "key" "name" "optional") -}}
  {{- include "__arkcase.subsystem-access.env" $args -}}
{{- end -}}

{{- define "arkcase.subsystem-access.env.admin" -}}
  {{- $params := (include "__arkcase.subsystem-access.extract-params" $ | fromYaml) -}}
  {{- $ctx := ($params.ctxIsRoot | ternary $ $.ctx) -}}
  {{- if or $params.ctxIsRoot (not (hasKey $ "key")) -}}
    {{- fail "Must provide a 'key' parameter" -}}
  {{- end -}}
  {{- $args := merge (dict "ctx" $ctx "type" "cred-admin" "subsys" $params.subsys) (pick $ "key" "name" "optional") -}}
  {{- include "__arkcase.subsystem-access.env" $args -}}
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
    {{- fail (printf "Invalid resource type [%s] for subsystem [%s] - must match /%s/" $type $params.subsys $regex) -}}
  {{- end -}}
  {{- if not (hasPrefix "cred-" $type) -}}
    {{- $type = (printf "%s%s" "cred-" $type) -}}
  {{- end -}}
  {{- $args := merge (dict "ctx" $ctx "type" $type "subsys" $params.subsys) (pick $ "key" "name" "optional") -}}
  {{- include "__arkcase.subsystem-access.env" $args -}}
{{- end -}}

{{- define "__arkcase.subsystem-access.volumeMount" -}}
  {{- $params := (include "__arkcase.subsystem-access.extract-params" $ | fromYaml) -}}
  {{- $ctx := ($params.ctxIsRoot | ternary $ $.ctx) -}}
  {{- if or $params.ctxIsRoot (not (hasKey $ "key")) -}}
    {{- fail "Must provide a 'key' parameter" -}}
  {{- end -}}

  {{- $type := "access" -}}
  {{- if not $params.ctxIsRoot -}}
    {{- $type = ($.type | default $type | toString) -}}
  {{- end -}}

  {{- $key := $.key -}}
  {{- $regex := "^[a-zA-Z0-9_.-]+$" -}}
  {{- if not (regexMatch $regex $key) -}}
    {{- fail (printf "Invalid key [%s] from the configuration resource of type %s for subsystem %s - must match /%s/" $key $params.type $params.subsys $regex) -}}
  {{- end -}}

  {{- $conf := (include "arkcase.subsystem-access.conf" $ | fromYaml) -}}
  {{- $conf = ($conf.connection | default dict) -}}
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
    {{- $mountPath = (printf "/srv/arkcase/%s/%s/%s" ($params.local | ternary "local" $params.subsys) $type $key) -}}
  {{- end -}}

  {{- if not (regexMatch "/[^/].*" $mountPath) -}}
    {{- fail (printf "Invalid mount path [%s] - must be an absolute file path" $mountPath) -}}
  {{- end -}}
- name: {{ $volumeName | quote }}
  mountPath: {{ $mountPath | quote }}
  subPath: {{ $sourceKey | quote }}
  readOnly: true
{{- end -}}

{{- define "arkcase.subsystem-access.volumeMount.conn" -}}
  {{- $params := (include "__arkcase.subsystem-access.extract-params" $ | fromYaml) -}}
  {{- $ctx := ($params.ctxIsRoot | ternary $ $.ctx) -}}
  {{- if or $params.ctxIsRoot (not (hasKey $ "key")) -}}
    {{- fail "Must provide a 'key' parameter" -}}
  {{- end -}}
  {{- $args := merge (dict "ctx" $ctx "type" "conn" "subsys" $params.subsys) (pick $ "key" "mountPath") -}}
  {{- include "__arkcase.subsystem-access.volumeMount" $args -}}
{{- end -}}

{{- define "arkcase.subsystem-access.volumeMount.admin" -}}
  {{- $params := (include "__arkcase.subsystem-access.extract-params" $ | fromYaml) -}}
  {{- $ctx := ($params.ctxIsRoot | ternary $ $.ctx) -}}
  {{- if or $params.ctxIsRoot (not (hasKey $ "key")) -}}
    {{- fail "Must provide a 'key' parameter" -}}
  {{- end -}}
  {{- $args := merge (dict "ctx" $ctx "type" "cred-admin" "subsys" $params.subsys) (pick $ "key" "mountPath") -}}
  {{- include "__arkcase.subsystem-access.volumeMount" $args -}}
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
    {{- fail (printf "Invalid resource type [%s] for subsystem [%s] - must match /%s/" $type $params.subsys $regex) -}}
  {{- end -}}
  {{- if not (hasPrefix "cred-" $type) -}}
    {{- $type = (printf "%s%s" "cred-" $type) -}}
  {{- end -}}
  {{- $args := merge (dict "ctx" $ctx "type" $type "subsys" $params.subsys) (pick $ "key" "mountPath") -}}
  {{- include "__arkcase.subsystem-access.volumeMount" $args -}}
{{- end -}}

{{- define "__arkcase.subsystem-access.volume" -}}
  {{- $params := (include "__arkcase.subsystem-access.extract-params" $ | fromYaml) -}}
  {{- $ctx := ($params.ctxIsRoot | ternary $ $.ctx) -}}

  {{- $type := "access" -}}
  {{- if not $params.ctxIsRoot -}}
    {{- $type = ($.type | default $type | toString) -}}
  {{- end -}}

  {{- $conf := (include "arkcase.subsystem-access.conf" $ | fromYaml) -}}
  {{- $conf = ($conf.connection | default dict) -}}
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
{{- end -}}

{{- define "arkcase.subsystem-access.volume.conn" -}}
  {{- $params := (include "__arkcase.subsystem-access.extract-params" $ | fromYaml) -}}
  {{- $ctx := ($params.ctxIsRoot | ternary $ $.ctx) -}}
  {{- $args := merge (dict "ctx" $ctx "type" "conn" "subsys" $params.subsys) (pick $ "optional") -}}
  {{- include "__arkcase.subsystem-access.volume" $args -}}
{{- end -}}

{{- define "arkcase.subsystem-access.volume.admin" -}}
  {{- $params := (include "__arkcase.subsystem-access.extract-params" $ | fromYaml) -}}
  {{- $ctx := ($params.ctxIsRoot | ternary $ $.ctx) -}}
  {{- $args := merge (dict "ctx" $ctx "type" "cred-admin" "subsys" $params.subsys) (pick $ "optional") -}}
  {{- include "__arkcase.subsystem-access.volume" $args -}}
{{- end -}}

{{- define "arkcase.subsystem-access.volume.cred" -}}
  {{- $params := (include "__arkcase.subsystem-access.extract-params" $ | fromYaml) -}}
  {{- $ctx := ($params.ctxIsRoot | ternary $ $.ctx) -}}
  {{- $args := merge (dict "ctx" $ctx "type" "cred-admin" "subsys" $params.subsys) (pick $ "optional") -}}
  {{- $type := "access" -}}
  {{- if not $params.ctxIsRoot -}}
    {{- $type = ($.type | default $type | toString) -}}
  {{- end -}}
  {{- $regex := "^[a-z0-9]+(-[a-z0-9]+)*$" -}}
  {{- if (not (regexMatch $regex $type)) -}}
    {{- fail (printf "Invalid resource type [%s] for subsystem [%s] - must match /%s/" $type $params.subsys $regex) -}}
  {{- end -}}
  {{- if not (hasPrefix "cred-" $type) -}}
    {{- $type = (printf "%s%s" "cred-" $type) -}}
  {{- end -}}
  {{- $args := merge (dict "ctx" $ctx "type" $type "subsys" $params.subsys) (pick $ "optional") -}}
  {{- include "__arkcase.subsystem-access.volume" $args -}}
{{- end -}}