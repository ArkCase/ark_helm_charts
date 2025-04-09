{{- define "arkcase.core.dev.deployEnv" -}}
  {{- $ctx := . -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "Must send the root context as the only parameter" -}}
  {{- end -}}

  {{- $wars := list -}}
  {{- $conf := "" -}}
  {{- $dev := (include "arkcase.dev" $ctx | fromYaml) -}}
  {{- if $dev.wars -}}
    {{- range $name := (keys $dev.wars | sortAlpha) -}}
      {{- $war := get $dev.wars $name -}}
      {{- if not $war.file -}}
        {{- $wars = append $wars $name -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
  {{- if and $dev.conf (not ($dev.conf).file) -}}
    {{- $conf = "true" -}}
  {{- end -}}

  {{- if $wars }}
- name: SKIP_WARS
  value: {{ $wars | join "/" | quote }}
  {{- end }}
  {{- if $conf }}
- name: SKIP_CONF
  value: {{ $conf | quote }}
  {{- end }}
- name: DEV
  value: {{ not (empty $dev) | toString | quote }}
{{- end -}}

{{- define "arkcase.core.dev.deployMounts" -}}
  {{- $ctx := . -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "Must send the root context as the only parameter" -}}
  {{- end -}}

- name: "wars"
  mountPath: "/app/depl/wars"
  {{- $dev := (include "arkcase.dev" $ctx | fromYaml) -}}
  {{- if $dev.wars }}
    {{- $num := 0 -}}
    {{- range $name := (keys $dev.wars | sortAlpha) }}
      {{- $war := get $dev.wars $name }}
      {{- if $war.file }}
- name: {{ printf "dev-war-%02d" $num | quote }}
  mountPath: {{ printf "/app/dev/wars/%s.war" $name | quote }}
      {{- end }}
      {{- $num = add 1 $num }}
    {{- end }}
  {{- end }}
  {{- if or (not $dev.conf) ($dev.conf).file }}
- name: "conf"
  mountPath: "/app/depl/conf"
  {{- end }}
  {{- if $dev.conf }}
- name: "dev-conf"
  mountPath: {{ $dev.conf.file | ternary "/app/dev/conf/01-conf.zip" "/app/depl/conf" | quote }}
  {{- end }}
{{- end -}}

{{- define "arkcase.core.dev.permissionMounts" -}}
  {{- $ctx := . -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "Must send the root context as the only parameter" -}}
  {{- end -}}

  {{- $dev := (include "arkcase.dev" $ctx | fromYaml) -}}
  {{- $num := 0 -}}
  {{- $confVolumeName := "conf" -}}
  {{- if and $dev.conf (not ($dev.conf).file) -}}
    {{- $confVolumeName = "dev-conf" -}}
  {{- end -}}
- name: &confVol {{ $confVolumeName | quote }}
  mountPath: &confDir "/app/conf"
  {{- if $dev.wars }}
    {{- range $name := (keys $dev.wars | sortAlpha) }}
      {{- $war := get $dev.wars $name }}
      {{- if not $war.file }}
- name: {{ printf "dev-war-%02d" $num | quote }}
  mountPath: {{ printf "/app/wars/%s" $name | quote }}
      {{- end }}
      {{- $num = add 1 $num }}
    {{- end }}
  {{- end }}
{{- end -}}

{{- define "arkcase.core.dev.runMounts" -}}
  {{- $ctx := . -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "Must send the root context as the only parameter" -}}
  {{- end -}}

  {{- $dev := (include "arkcase.dev" $ctx | fromYaml) -}}
  {{- if $dev.wars -}}
    {{- $num := 0 -}}
    {{- range $name := (keys $dev.wars | sortAlpha) }}
      {{- $war := get $dev.wars $name }}
      {{- if not $war.file }}
- name: {{ printf "dev-war-%02d" $num | quote }}
  mountPath: {{ printf "/app/tomcat/webapps/%s" $name | quote }}
      {{- end }}
      {{- $num = add 1 $num }}
    {{- end }}
  {{- end -}}
{{- end -}}

{{- define "arkcase.core.dev.volumes" -}}
  {{- $ctx := . -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "Must send the root context as the only parameter" -}}
  {{- end -}}

  {{- $dev := (include "arkcase.dev" $ctx | fromYaml) -}}
  {{- if or (not $dev.conf) $dev.conf.file }}
    {{- include "arkcase.persistence.volume" (dict "ctx" $ctx "name" "conf") }}
  {{- end }}
  {{- if $dev.conf }}
- name: "dev-conf"
  hostPath:
    path: {{ $dev.conf.path | quote }}
    type: {{ $dev.conf.file | ternary "File" "Directory" | quote }}
  {{- end }}
  {{- if $dev.wars }}
    {{- $num := 0 -}}
    {{- range $name := (keys $dev.wars | sortAlpha) }}
      {{- $war := get $dev.wars $name }}
- name: {{ printf "dev-war-%02d" $num | quote }}
  hostPath:
    path: {{ $war.path | quote }}
    type: {{ $war.file | ternary "File" "Directory" | quote }}
      {{- $num = add 1 $num }}
    {{- end }}
  {{- end }}
{{- end -}}

{{- define "arkcase.core.configPriority" -}}
  {{- $ctx := . -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "Must send the root context as the only parameter" -}}
  {{- end -}}

  {{- with (include "arkcase.tools.conf" (dict "ctx" $ctx "value" "priorities")) -}}
    {{- $priority := . -}}
    {{- if not (kindIs "string" $priority) -}}
      {{- fail "The priority list must be a comma-separated list" -}}
    {{- end -}}
    {{- $result := list -}}
    {{- range $i := splitList "," $priority -}}
      {{- /* Skip empty elements */ -}}
      {{- if $i -}}
        {{- $result = append $result $i -}}
      {{- end -}}
    {{- end -}}
    {{- $priority = "" -}}
    {{- if $result -}}
      {{- $priority = (printf "%s," (join "," $result)) -}}
    {{- end -}}
    {{- $priority -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.core.messaging.openwire" -}}
  {{- $messaging := (include "arkcase.tools.parseUrl" (include "arkcase.tools.conf" (dict "ctx" $ "value" "messaging.url")) | fromYaml) }}
  {{- $scheme := ($messaging.scheme | default "tcp") -}}
  {{- $host := ($messaging.hostname | default "messaging") -}}
  {{- $port := (include "arkcase.tools.conf" (dict "ctx" $ "value" "messaging.openwire") | default "61616" | int) -}}
  {{- printf "%s://%s:%d" $scheme $host $port -}}
{{- end -}}

{{- define "arkcase.core.content.url" -}}
  {{- if not (include "arkcase.isRootContext" $) -}}
    {{- fail "Must send the root context as the only parameter" -}}
  {{- end -}}
  {{- $content := (include "arkcase.cm.info" $ | fromYaml) -}}
  {{- $content.url.baseUrl -}}
{{- end -}}

{{- define "arkcase.core.content.ui" -}}
  {{- if not (include "arkcase.isRootContext" $) -}}
    {{- fail "Must send the root context as the only parameter" -}}
  {{- end -}}
  {{- $content := (include "arkcase.cm.info" $ | fromYaml) -}}
  {{- $content.ui.baseUrl -}}
{{- end -}}

{{- define "arkcase.core.email" -}}
  {{- if not (include "arkcase.isRootContext" $) -}}
    {{- fail "Must send the root context as the only parameter" -}}
  {{- end -}}

  {{- /* With this trick we can get an actual null value */ -}}
  {{- $nullMap := dict -}}
  {{- $null := $nullMap.null -}}

  {{- $sendProtocols := dict
    "plaintext" (list "off" 25)
    "ssl" (list "ssl-tls" 465)
    "starttls" (list "starttls" 25)
  -}}

  {{- $connect := $null -}}
  {{- $v := (include "arkcase.tools.conf" (dict "ctx" $ "value" "email.send.connect" "detailed" true) | fromYaml) -}}
  {{- if and $v $v.global $v.value (eq $v.type "string") -}}
    {{- $protocol := ($v.value | lower) -}}
    {{- if (not (hasKey $sendProtocols $protocol)) -}}
      {{- fail (printf "Unsupported email.send protocol [%s] - must be one of %s (case-insensitive)" $v.value (keys $sendProtocols | sortAlpha)) -}}
    {{- end -}}
    {{- $connect = get $sendProtocols $protocol -}}
  {{- else -}}
    {{- $connect = get $sendProtocols "starttls" -}}
  {{- end }}

  {{- $host := "localhost" -}}
  {{- $v = (include "arkcase.tools.conf" (dict "ctx" $ "value" "email.send.host" "detailed" true) | fromYaml) -}}
  {{- if and $v $v.global $v.value (eq $v.type "string") -}}
    {{- /* This will explode or give us a valid value */ -}}
    {{- $host = (include "arkcase.tools.singleHostname" $v.value) -}}
    {{- if not $host -}}
      {{- fail (printf "Invalid email.send.host value [%s] - must be a valid RFC-1123 domain name" $v.value) -}}
    {{- end -}}
  {{- end }}

  {{- $port := $null -}}
  {{- $v = (include "arkcase.tools.conf" (dict "ctx" $ "value" "email.send.port" "detailed" true) | fromYaml) -}}
  {{- if and $v $v.global $v.value -}}
    {{- $port = (include "arkcase.tools.checkNumericPort" $v.value) -}}
    {{- if not $port -}}
      {{- fail (printf "Invalid email.port [%s] - must be a valid port number in the range [1..65535]" $v.value) -}}
    {{- end -}}
  {{- else -}}
    {{- /* If no port was given, use the default per the protocol */ -}}
    {{- $port = (last $connect) -}}
  {{- end }}

  {{- $username := $null -}}
  {{- $v = (include "arkcase.tools.conf" (dict "ctx" $ "value" "email.send.username" "detailed" true) | fromYaml) -}}
  {{- if and $v $v.global $v.value (eq $v.type "string") -}}
    {{- $username = $v.value -}}
  {{- end }}

  {{- $password := $null -}}
  {{- if $username -}}
    {{- $v = (include "arkcase.tools.conf" (dict "ctx" $ "value" "email.send.password" "detailed" true) | fromYaml) -}}
    {{- if and $v $v.global $v.value (eq $v.type "string") -}}
      {{- $password = $v.value -}}
    {{- else -}}
      {{- fail "If you provide an email.send.username, you must also provide a password" -}}
    {{- end }}
  {{- end -}}

  {{- $from := "no-reply@localhost.localdomain" -}}
  {{- $v = (include "arkcase.tools.conf" (dict "ctx" $ "value" "email.send.from" "detailed" true) | fromYaml) -}}
  {{- if and $v $v.global $v.value (eq $v.type "string") -}}
    {{- $from = (include "arkcase.tools.validEmail" $v.value) -}}
    {{- if not $from -}}
      {{- fail (printf "Invalid email.send.from value [%s] - must be a valid e-mail address" $v.value) -}}
    {{- end -}}
  {{- end }}

  {{-
    $sender := dict
      "encryption" (first $connect)
      "host" $host
      "port" $port
      "username" $username
      "password" $password
      "userFrom" $from
  -}}
  {{- $result := dict "sender" $sender -}}

  {{- $host = "localhost" -}}
  {{- $v = (include "arkcase.tools.conf" (dict "ctx" $ "value" "email.receive.host" "detailed" true) | fromYaml) -}}
  {{- if and $v $v.global $v.value (eq $v.type "string") -}}
    {{- /* This will explode or give us a valid value */ -}}
    {{- $host = (include "arkcase.tools.singleHostname" $v.value) -}}
    {{- if not $host -}}
      {{- fail (printf "Invalid email.receive.host value [%s] - must be a valid RFC-1123 domain name" $v.value) -}}
    {{- end -}}
  {{- end }}
  {{- $result = set $result "host" $host -}}

  {{- $port = $null -}}
  {{- $v = (include "arkcase.tools.conf" (dict "ctx" $ "value" "email.receive.port" "detailed" true) | fromYaml) -}}
  {{- if and $v $v.global $v.value -}}
    {{- $port = (include "arkcase.tools.checkNumericPort" $v.value) -}}
    {{- if not $port -}}
      {{- fail (printf "Invalid email.receive.port [%s] - must be a valid port number in the range [1..65535]" $v.value) -}}
    {{- end -}}
    {{- $result = set $result "port" $port -}}
  {{- end }}

  {{- $v = (include "arkcase.tools.conf" (dict "ctx" $ "value" "email.receive.channel-enabled" "detailed" true) | fromYaml) -}}
  {{- if and $v $v.global $v.value -}}
    {{- $receiverChannelEnabled := (and (not (empty $v)) (not (empty (include "arkcase.toBoolean" $v.value)))) -}}
    {{- if not $receiverChannelEnabled -}}
      {{- fail (printf "Invalid email.receive.channel-enabled [%s] - must be a valid boolean [true/false]" $v.value) -}}
    {{- end -}}
    {{- $result = set $result "receiver-channel-enabled" $receiverChannelEnabled -}}
  {{- end }}

  {{- dict "email" $result | toYaml -}}
{{- end }}

{{- define "__arkcase.core.integrations.config" -}}
  {{- $ctx := $ -}}
  {{- $config := ($.Files.Get "integration.yaml" | fromYaml | default dict) -}}
  {{- $result := dict -}}
  {{- if $config -}}
    {{- range $key, $data := $config -}}
      {{- $clash := (get $result $key) -}}
      {{- if $clash -}}
        {{- fail (printf "Conflicting integration keys: key [%s] conflicts with an alias from [%s]" $key $clash.key) -}}
      {{- end -}}

      {{- $enabled := (not (empty (include "arkcase.toBoolean" $data.enabled))) -}}

      {{- $configKey := ((hasKey $data "config-key") | ternary (get $data "config-key") "" | default $key | toString) -}}

      {{- $aliases := $data.aliases | default list -}}
      {{- if $aliases -}}
        {{- if (not (kindIs "slice" $aliases)) -}}
          {{- fail (printf "BAD integrations configuration: the aliases for [%s] must be a list: (%s) [%s]" $key (kindOf $aliases) $aliases) -}}
        {{- end -}}
        {{- $aliases = (without ($aliases | toStrings | sortAlpha | uniq | compact) $key) -}}
        {{- range $alias := $aliases -}}
          {{- $clash := (get $result $alias) -}}
          {{- if $clash -}}
            {{- fail (printf "Conflicting integration alias: [%s] from [%s] conflicts with [%s]" $alias $key $clash.key) -}}
          {{- end -}}

          {{- $clash = (get $config $alias) -}}
          {{- if $clash -}}
            {{- fail (printf "Conflicting integration alias: [%s] from [%s] conflicts with another key" $alias $key) -}}
          {{- end -}}
        {{- end -}}
      {{- end -}}

      {{- $springProfiles := (get $data "spring-profiles") | default list -}}
      {{- if $springProfiles -}}
        {{- if (not (kindIs "slice" $springProfiles)) -}}
          {{- fail (printf "BAD integrations configuration: the spring profiles for [%s] must be a list: (%s) [%s]" $key (kindOf $springProfiles) $springProfiles) -}}
        {{- end -}}
        {{- $springProfiles = ($springProfiles | toStrings | sortAlpha | uniq | compact) -}}
      {{- end -}}

      {{- $integration := dict "enabled" $enabled "key" $key "configKey" $configKey "springProfiles" $springProfiles -}}
      {{- $result = set $result $key $integration -}}
      {{- range $alias := $aliases -}}
        {{- $result = set $result $alias $integration -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
  {{- $result | toYaml -}}
{{- end -}}

{{- define "__arkcase.core.integrations.compute" -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "Must send the root context as the only parameter" -}}
  {{- end -}}

  {{- $config := (include "__arkcase.core.integrations.config" $ctx | fromYaml) -}}

  {{- $integrations := ($.Values.global).integration -}}
  {{- $result := dict -}}
  {{- $bad := list -}}
  {{- if and $integrations (kindIs "map" $integrations) -}}
    {{- $added := dict -}}
    {{- range $key, $integration := $integrations -}}

      {{- /* First ... is this a known integration? If not... complain! */ -}}
      {{- if not (hasKey $config $key) -}}
        {{- $bad = append $bad $key -}}
        {{- continue -}}
      {{- end -}}

      {{- $current := get $config $key -}}
      {{- if not $current.enabled -}}
        {{- /* If this integration is disabled, skip it! */ -}}
        {{- continue -}}
      {{- end -}}

      {{- if hasKey $added $current.key -}}
        {{- fail (printf "Duplicate integration configurations detected for [%s]: provided [%s] and [%s]" $current.key $key (get $added $current.key)) -}}
      {{- end -}}

      {{- $final := dict -}}
      {{- if and $integration (kindIs "map" $integration) -}}
        {{- if or (not (hasKey $integration "enabled")) (include "arkcase.toBoolean" $integration.enabled) -}}
          {{- $final = dict "profiles" $current.springProfiles "config" $integration -}}
        {{- end -}}
      {{- end -}}

      {{- if $final -}}
        {{- $result = set $result $current.configKey $final -}}
        {{- $added = set $added $current.key $key -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
  {{- if $bad -}}
    {{- fail (printf "Unsupported integrations configured: %s" ($bad | sortAlpha)) -}}
  {{- end -}}
  {{- (empty $result) | ternary "" ($result | toYaml) -}}
{{- end -}}

{{- define "arkcase.core.integrations" -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The parameter must be the root context ($ or .)" -}}
  {{- end -}} 

  {{- $args :=
    dict
      "ctx" $ctx
      "template" "__arkcase.core.integrations.compute"
  -}}
  {{- include "__arkcase.tools.getCachedValue" $args -}}
{{- end -}}

{{- define "arkcase.core.integrations.config" -}}
  {{- $result := dict -}}
  {{- range $key, $data := (include "arkcase.core.integrations" $ | fromYaml) -}}
    {{- $result = set $result $key $data.config -}}
  {{- end -}}
  {{- if $result -}}
    {{- $result | toYaml -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.core.renderLoggers" -}}
  {{- $ctx := $.ctx -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "Must send the root context as the 'ctx' parameter" -}}
  {{- end -}}

  {{- /* Clean up the default loggers */ -}}
  {{- $loggers := $.loggers -}}
  {{- if or (not $loggers) (not (kindIs "map" $loggers)) -}}
    {{- $loggers = dict -}}
  {{- end -}}
  {{- $loggers = (include "arkcase.sanitizeLoggers" $loggers | fromYaml) -}}

  {{- /* Find the configured extra loggers */ -}}
  {{- $settings := (include "arkcase.subsystem.settings" $ctx | fromYaml) -}}
  {{- $extraLogs := (include "arkcase.sanitizeLoggers" $settings.logs | fromYaml) -}}

  {{- /* The configured extra loggers override the defaults */ -}}
  {{- if $extraLogs -}}
    {{- $loggers = merge $extraLogs $loggers -}}
  {{- end -}}

  {{- /* Loggers from dev mode override both the defaults and the configured extra loggers */ -}}
  {{- $dev := (include "arkcase.dev" $ctx | fromYaml) -}}
  {{- if $dev.logs -}}
    {{- $loggers = merge $dev.logs $loggers -}}
  {{- end -}}

  {{- /* Make sure we render them alphabetically */ -}}
  {{- range $name := (keys $loggers | sortAlpha) }}
    {{- $level := get $loggers $name }}
<Logger name={{ include "arkcase.xmlEscape" $name | quote }} level={{ include "arkcase.xmlEscape" $level | quote }} additivity="false">
    <AppenderRef ref="Console"/>
    <AppenderRef ref="file-log"/>
</Logger>
  {{- end }}
{{- end -}}

{{- define "arkcase.core.mergeRoles" -}}
  {{- $ctx := $.ctx -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "Must send the root context as the 'ctx' parameter" -}}
  {{- end -}}

  {{- $finalMappings := $.base -}}
  {{- $overlay := $.overlay -}}

  {{- $finalMappings = (kindIs "map" $finalMappings) | ternary $finalMappings dict -}}
  {{- $overlay = (kindIs "map" $overlay) | ternary $overlay dict -}}

  {{- $replace := "replace" -}}
  {{- $merge := "merge" -}}
  {{- $remove := "remove" -}}

  {{- if $overlay -}}
    {{- $ovlRoles := dict -}}
    {{- range $ovlRole, $ovlGroups := $overlay -}}
      {{- $action := $replace -}}
      {{- if (hasPrefix "~" $ovlRole) -}}
        {{- $action = $merge -}}
      {{- else if (hasPrefix "^" $ovlRole) -}}
        {{- $action = $remove -}}
      {{- end -}}

      {{- $finalRole := (eq $replace $action) | ternary $ovlRole (substr 1 (len $ovlRole) $ovlRole) | trim -}}
      {{- if not $finalRole -}}
        {{- fail (printf "Illegal role specification: [%s]" $ovlRole) -}}
      {{- end -}}

      {{- /* Do a sanity check to catch dumb people doing dumb things */ -}}
      {{- if (hasKey $ovlRoles $finalRole) -}}
        {{- fail (printf "Duplicate role being overlaid: [%s] (from [%s], existing from [%s])" $finalRole $ovlRole (get $ovlRoles $finalRole)) -}}
      {{- end -}}
      {{- $ovlRoles = set $ovlRoles $finalRole $ovlRole -}}

      {{- /* If we're just removing the role, we don't care what's inside its mapping */ -}}
      {{- if (eq $action $remove) -}}
        {{- $finalMappings = set $finalMappings $finalRole list -}}
        {{- continue -}}
      {{- end -}}

      {{- /* Make sure $ovlGroups is a list of some kind */ -}}
      {{- if (not (kindIs "slice" $ovlGroups)) -}}
        {{- if (kindIs "map" $ovlGroups) -}}
          {{- $ovlGroups = (keys $ovlGroups) -}}
        {{- else -}}
          {{- $ovlGroups = ($ovlGroups | toString | splitList ",") -}}
        {{- end -}}
      {{- end -}}

      {{- /* Remove empty strings from the new values */ -}}
      {{- $ovlGroups = ($ovlGroups | compact) -}}

      {{- /* Decide whether we're merging or replacing */ -}}
      {{- $finalGroups := (and (eq $action $merge) (hasKey $finalMappings $finalRole)) | ternary (get $finalMappings $finalRole) list -}}

      {{- /* Reconcile the lists */ -}}
      {{- range $ovlGroup := $ovlGroups -}}
        {{- $remove := (hasPrefix "-" $ovlGroup) -}}
        {{- $g := ($remove | ternary (substr 1 (len $ovlGroup) $ovlGroup | trim) $ovlGroup) -}}
        {{- if not $g -}}
          {{- fail (printf "Invalid group name [%s] for role mapping [%s]" $ovlGroup $ovlRole) -}}
        {{- end -}}

        {{- $finalGroups = ($remove | ternary (without $finalGroups $g) (append $finalGroups $g)) -}}
      {{- end -}}

      {{- $finalMappings = set $finalMappings $finalRole ($finalGroups | compact | sortAlpha | uniq) -}}
    {{- end -}}
  {{- end -}}

  {{- $finalMappings | toYaml -}}
{{- end -}}

{{- define "__arkcase.core.rolesToGroups.compute" -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "Must send the root context as the only parameter" -}}
  {{- end -}}

  {{- $settings := (include "arkcase.subsystem.settings" $ctx | fromYaml) -}}

  {{- /* Ok ... now load the role-mappings.yaml file */ -}}
  {{- $defaultMappings := (.Files.Get "role-mappings.yaml" | fromYaml) -}}
  {{- if (not (kindIs "map" $defaultMappings)) -}}
    {{- $defaultMappings = dict -}}
  {{- end -}}

  {{- $param := (dict "ctx" $ctx) -}}

  {{- /* This will be the final result map, which output as YAML can be used for the final mappings */ -}}
  {{- $result := dict -}}

  {{- /* Read the base mappings */ -}}
  {{- $default := (get $defaultMappings "default") | default dict -}}
  {{- $default = (kindIs "map" $default) | ternary $default dict -}}
  {{- if $default -}}
    {{- /* We overlay the default mappings */ -}}
    {{- $result = (include "arkcase.core.mergeRoles" (merge (dict "base" $result "overlay" $default) $param) | fromYaml) -}}
  {{- end -}}

  {{- $portal := (include "arkcase.portal" $ctx | fromYaml) -}}
  {{- if $portal -}}
    {{- $portalMappings := (get $defaultMappings "portal") | default dict -}}
    {{- $portalMappings = (kindIs "map" $portalMappings) | ternary $portalMappings dict -}}
    {{- if $portalMappings -}}
      {{- /* We overlay the portal mappings */ -}}
      {{- $result = (include "arkcase.core.mergeRoles" (merge (dict "base" $result "overlay" $portalMappings) $param) | fromYaml) -}}
    {{- end -}}
  {{- end -}}

  {{- /* Finally, find the conf.roles-to-groups entry */ -}}
  {{- $mappingsKey := "roles-to-groups" -}}
  {{- $mappings := get $settings $mappingsKey -}}
  {{- if (not (kindIs "map" $mappings)) -}}
    {{- $mappings = dict -}}
  {{- end -}}

  {{- /* If there are mappings to be applied, apply them */ -}}
  {{- if $mappings -}}
    {{- /* If necessary, overlay the configured mappings */ -}}
    {{- $result = (include "arkcase.core.mergeRoles" (merge (dict "base" $result "overlay" $mappings) $param) | fromYaml) -}}
  {{- end -}}

  {{- /* Output the final result */ -}}
  {{- $result | toYaml -}}
{{- end -}}

{{- define "arkcase.core.rolesToGroups" -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The parameter must be the root context ($ or .)" -}}
  {{- end -}} 

  {{- $args :=
    dict
      "ctx" $ctx
      "template" "__arkcase.core.rolesToGroups.compute"
  -}}
  {{- include "__arkcase.tools.getCachedValue" $args -}}
{{- end -}}

{{- define "arkcase.core.springProfiles" -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "Must send the root context as the only parameter" -}}
  {{- end -}}

  {{- /* Assume LDAP will be needed by default - will get overridden below if needed */ -}}
  {{- $result := list "ldap" -}}

  {{- /* Add the OIDC or SAML profile, depending on the authentication configuration */ -}}
  {{- $sso := (include "arkcase.core.sso" $ | fromYaml) -}}
  {{- if $sso -}}
    {{- if (hasKey $sso.conf "profiles") -}}
      {{- $result = $sso.conf.profiles -}}
    {{- end -}}
  {{- end -}}

  {{- /* Add any profiles the integrations required */ -}}
  {{- range $key, $data := (include "arkcase.core.integrations" $ | fromYaml) -}}
    {{- $result = concat $result ($data.profiles | default list) -}}
  {{- end -}}

  {{- /* Add the FOIA profile if the configuration is set */ -}}
  {{- if (include "arkcase.portal" $ | fromYaml) -}}
    {{- $result = prepend $result "extension-foia" -}}
  {{- end -}}

  {{- $result | uniq | toYaml -}}
{{- end -}}

{{- define "arkcase.core.ldap" -}}
  {{- $ctx := $ -}}
  {{- $server := "default" -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- $ctx = $.ctx -}}
    {{- if not (include "arkcase.isRootContext" $ctx) -}}
      {{- fail "Must send the root context as the only parameter" -}}
    {{- end -}}
    {{- $server = ((hasKey $ "server") | ternary $.server "" | default $server) -}}
  {{- end -}}

  {{- $settings := (include "arkcase.subsystem.settings" (dict "ctx" $ctx "subsys" "ldap") | fromYaml) -}}
  {{- $server = (dig $server "" ($settings | default dict)) -}}
  {{- if not (kindIs "map" $server) -}}
    {{- $server = dict -}}
  {{- end -}}

  {{- $result := dict -}}
  {{- range $key := (list "Edit" "Create" "Sync") -}}
    {{- $v := (include "arkcase.toBoolean" (get $server ($key | lower)) | default "true") -}}
    {{- $result = set $result (printf "enable%s" $key) (not (empty $v)) -}}
  {{- end -}}
  {{- $result | toYaml -}}
{{- end -}}

{{- define "arkcase.core.extra-env.secret" -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "Must send the root context as the only parameter" -}}
  {{- end -}}
  {{- (printf "%s-%s-env" $ctx.Release.Name (include "arkcase.subsystem.name" $ctx)) -}}
{{- end -}}

{{- define "arkcase.core.extra-env.parseKey" -}}
  {{- $key := ($ | toString) -}}
  {{- /* The raw key is top-level absolute path with only one component */ -}}
  {{- if (regexMatch "^/+[^/]+$" $key) -}}
    {{- regexReplaceAll "^/+([^/]+)$" $key "${1}" -}}
  {{- end -}}
{{- end -}}

{{- define "__arkcase.core.extra-env.compute" -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "Must send the root context as the only parameter" -}}
  {{- end -}}

  {{- $global := ($ctx.Values.global | default dict) -}}
  {{- $global = ((kindIs "map" $global) | ternary $global dict) -}}
  {{- $envConf := $global.env -}}
  {{- $envConf = ((kindIs "map" $envConf) | ternary $global.env dict) -}}

  {{- $envSecretName := (include "arkcase.core.extra-env.secret" $ctx) -}}

  {{- $stringData := dict -}}
  {{- $env := dict -}}
  {{- $secret := dict -}}
  {{- $configMap := dict -}}
  {{- if $envConf -}}
    {{- $value := $envConf.value -}}
    {{- if and $value (kindIs "map" $value) -}}
      {{- range $k := (keys $value | sortAlpha) -}}
        {{- /* Do a first quick validation */ -}}
        {{- if not (regexMatch "^[a-zA-Z0-9._-]+$" $k) -}}
          {{- fail (printf "The key [%s] (from global.env.value.%s) is not a valid secret or configMap key" $k $k) -}}
        {{- end -}}

        {{- /* Set the defaults */ -}}
        {{- $type := "secret" -}}
        {{- $name := $envSecretName -}}
        {{- $key := $k -}}
        {{- $optional := false -}}

        {{- /* Now, analyze the value */ -}}
        {{- $v := (get $value $k) -}}
        {{- if (kindIs "map" $v) -}}
          {{- /* validate the map's structure */ -}}
          {{- $enabled := (or (not (hasKey $v "enabled")) (not (empty (include "arkcase.toBoolean" $v.enabled)))) -}}
          {{- $optional = (not (empty (include "arkcase.toBoolean" $v.optional))) -}}
          {{- $d := dict -}}
          {{- if and (hasKey $v "configMap") (hasKey $v "secret") -}}
            {{- fail (printf "The map at global.env.value.%s must contain either a configMap or a secret, not both: %s" $k ($v | toYaml | nindent 0)) -}}
          {{- else if (hasKey $v "configMap") -}}
            {{- $type = "configMap" -}}
            {{- $d = $v.configMap -}}
          {{- else if (hasKey $v "secret") -}}
            {{- $type = "secret" -}}
            {{- $d = $v.secret -}}
          {{- else -}}
            {{- fail (printf "The map at global.env.value.%s must contain either a configMap or secret entry describing where to pull the secret from: %s" $k ($v | toYaml | nindent 0)) -}}
          {{- end -}}

          {{- if (not (kindIs "map" $d)) -}}
            {{- fail (printf "The value at global.env.value.%s.%s must be a map describing where to pull the secret from" $k $type ($v | toYaml | nindent 0)) -}}
          {{- end -}}

          {{- if (not (hasKey $d "name")) -}}
            {{- fail (printf "The value at global.env.value.%s.%s must contain the name of the %s to get the value from: %s" $k $type $type ($v | toYaml | nindent 0)) -}}
          {{- end -}}
          {{- $name = (include "arkcase.tools.hostnamePart" (get $d "name" | default "" | toString)) | required (printf "The name [%s] (from global.env.value.%s.%s.name) is not a valid %s name" $name $k $type $type) -}}

          {{- $key = ((hasKey $d "key") | ternary (get $d "key" | default "" | toString) $key) -}}
          {{- if not (regexMatch "^[a-zA-Z0-9._-]+$" $key) -}}
            {{- fail (printf "The key [%s] (from global.env.value.%s.%s.key) is not a valid %s key" $key $k $type $type) -}}
          {{- end -}}

          {{- if not $enabled -}}
            {{- /* Map is disabled, ignore it */ -}}
            {{- continue -}}
          {{- end -}}
        {{- else if (kindIs "slice" $v) -}}
          {{- fail (printf "The global.env.value.%s value may not be of type %s" $k (kindOf $v)) -}}
        {{- else -}}
          {{- /* Make sure we ALWAYS have a string */ -}}
          {{- $v = ((eq $v nil) | ternary "" ($v | toString)) -}}

          {{- /* If it's a secret:// or configMap:// element, parse and validate */ -}}
          {{- if or (hasPrefix "secret://" $v) (hasPrefix "configMap://" $v) -}}
            {{- /* Parse the shorthand */ -}}
            {{- $data := (urlParse $v) -}}
            {{- $type = $data.scheme -}}
            {{- $name = (include "arkcase.tools.hostnamePart" $data.host) | required (printf "The %s name is required in the shorthand syntax: %s" $type $v) -}}
            {{- /* If the key is not present, we use the original value */ -}}
            {{- $key = (include "arkcase.core.extra-env.parseKey" $data.path) | default $key -}}
            {{- if not (regexMatch "^[a-zA-Z0-9._-]+$" $key) -}}
              {{- fail (printf "The key [%s] (from global.env.value.%s = %s) is not a valid secret or configMap key" $key $k $v) -}}
            {{- end -}}
          {{- else -}}
            {{- /* Add the literal value to the target secret's data */ -}}
            {{- $stringData = set $stringData $k $v -}}
          {{- end -}}
        {{- end -}}
        {{- /* Render the valueFrom map that will go into the the container's env.XXX */ -}}
        {{- $envVar := (printf "ARK_ENV_%s" (regexReplaceAllLiteral "[^A-Z0-9_]" ($k | snakecase | upper) "_")) -}}
        {{- $env = set $env $envVar (dict (printf "%sKeyRef" $type) (dict "key" $key "name" $name "optional" $optional)) -}}
      {{- end -}}

      {{- /* Convert it into a list of environment variables */ -}}
      {{- $envList := list -}}
      {{- range $name := (keys $env | sortAlpha) -}}
        {{- $valueFrom := (get $env $name) -}}
        {{- $envList = append $envList (dict "name" $name "valueFrom" $valueFrom) -}}
      {{- end -}}
      {{- $env = $envList -}}
    {{- end -}}

    {{- $secret := $envConf.secret -}}
    {{- if and $secret (kindIs "map" $secret) -}}
      {{- /* TODO: render the volumeMount */ -}}
      {{- /* TODO: render the volume */ -}}
    {{- end -}}

    {{- $configMap := $envConf.configMap -}}
    {{- if and $configMap (kindIs "map" $configMap) -}}
      {{- /* TODO: render the volumeMount */ -}}
      {{- /* TODO: render the volume */ -}}
    {{- end -}}
  {{- end -}}

  {{- (dict "env" $env "stringData" $stringData "secret" $secret "configMap" $configMap | toYaml) -}}
{{- end -}}

{{- define "arkcase.core.extra-env" -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The parameter must be the root context ($ or .)" -}}
  {{- end -}} 

  {{- $args :=
    dict
      "ctx" $ctx
      "template" "__arkcase.core.extra-env.compute"
  -}}
  {{- include "__arkcase.tools.getCachedValue" $args -}}
{{- end -}}

{{- define "arkcase.core.extra-env.env" -}}
  {{- $extraEnv := (include "arkcase.core.extra-env" $ | fromYaml) -}}
  {{- if $extraEnv.env -}}
    {{- $extraEnv.env | toYaml -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.portal.springProfiles" -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "Must send the root context as the only parameter" -}}
  {{- end -}}

  {{- $portalSSO := (include "arkcase.core.portal.sso" $ | fromYaml) -}}
  {{- $result := list -}}
  {{- if $portalSSO }}
    {{- $result = append $result "oidc" -}}
  {{- end }}

  {{- $result | uniq | toYaml -}}
{{- end -}}
