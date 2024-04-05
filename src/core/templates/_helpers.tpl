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

{{- define "arkcase.core.image.deploy" -}}
  {{- $imageName := "deploy" -}}
  {{- if (include "arkcase.foia" $.ctx | fromYaml) -}}
    {{- $imageName = (printf "%s-foia" $imageName) -}}
  {{- end -}}
  {{- $param := (merge (dict "name" $imageName) (omit $ "name")) -}}
  {{- include "arkcase.image" $param }}
{{- end -}}

{{- define "arkcase.core.email" -}}
  {{- if not (include "arkcase.isRootContext" $) -}}
    {{- fail "Must send the root context as the only parameter" -}}
  {{- end -}}

  {{- /* With this trick we can get an actual null value */ -}}
  {{- $null := $.Eeshae3bo6oosh3ahngiengoifah5qui5aeteitiemuRaeng1iexoom0ThooTh9yeiph3taVahj3iB7am3Tohse1eim2okaiJiemiebi6uoWeeM0aethahv2haex0OoR -}}

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
      "from" $from
  -}}
  {{- $result := dict "sender" $sender -}}

  {{- $host = "localhost" -}}
  {{- $v = (include "arkcase.tools.conf" (dict "ctx" $ "value" "email.send.host" "detailed" true) | fromYaml) -}}
  {{- if and $v $v.global $v.value (eq $v.type "string") -}}
    {{- /* This will explode or give us a valid value */ -}}
    {{- $host = (include "arkcase.tools.singleHostname" $v.value) -}}
    {{- if not $host -}}
      {{- fail (printf "Invalid email.receive.host value [%s] - must be a valid RFC-1123 domain name" $v.value) -}}
    {{- end -}}
  {{- end }}
  {{- $result = set $result "host" $host -}}

  {{- $port = $null -}}
  {{- $v = (include "arkcase.tools.conf" (dict "ctx" $ "value" "email.send.port" "detailed" true) | fromYaml) -}}
  {{- if and $v $v.global $v.value -}}
    {{- $port = (include "arkcase.tools.checkNumericPort" $v.value) -}}
    {{- if not $port -}}
      {{- fail (printf "Invalid email.port [%s] - must be a valid port number in the range [1..65535]" $v.value) -}}
    {{- end -}}
    {{- $result = set $result "port" $port -}}
  {{- end }}

  {{- dict "email" $result | toYaml -}}
{{- end }}

{{- define "arkcase.core.integrations.computeKey" -}}
  {{- $name := .name -}}
  {{- $config := .config -}}
  {{- $value := get $config $name -}}
  {{- if $value -}}
    {{- $value = ($value | toString) -}}
    {{- if (eq "true" $value) -}}
      {{- $name -}}
    {{- else if (ne "false" $value) -}}
      {{- $value -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.core.integrations" -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "Must send the root context as the only parameter" -}}
  {{- end -}}

  {{- $config := (.Files.Get "integration.yaml" | fromYaml | default dict) -}}

  {{- $ints := ($.Values.global).integration -}}
  {{- $result := dict -}}
  {{- $disabled := dict "enabled" false -}}
  {{- $bad := list -}}
  {{- if and $ints (kindIs "map" $ints) -}}
    {{- range $name, $t := $ints -}}

      {{- /* First ... is this a known integration? If not... complain! */ -}}
      {{- if not (hasKey $config $name) -}}
        {{- $bad = append $bad $name -}}
        {{- continue -}}
      {{- end -}}

      {{- $key := (include "arkcase.core.integrations.computeKey" (dict "name" $name "config" $config)) -}}
      {{- if not $key -}}
        {{- /* If this integration is disabled, skip it! */ -}}
        {{- continue -}}
      {{- end -}}

      {{- if and $t (kindIs "map" $t) -}}
        {{- if or (not (hasKey $t "enabled")) (include "arkcase.toBoolean" $t.enabled) -}}
          {{- $t = set $t "enabled" true -}}
        {{- else -}}
          {{- $t = $disabled -}}
        {{- end -}}
      {{- else -}}
        {{- $t = $disabled -}}
      {{- end -}}
      {{- $result = set $result $key $t -}}
    {{- end -}}
  {{- end -}}
  {{- if $bad -}}
    {{- fail (printf "Unsupported integrations configured: %s" ($bad | sortAlpha)) -}}
  {{- end -}}
  {{- (empty $result) | ternary "" ($result | toYaml) -}}
{{- end -}}

{{- define "arkcase.core.renderLoggers" -}}
  {{- $ctx := $.ctx -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "Must send the root context as the 'ctx' parameter" -}}
  {{- end -}}

  {{- $dev := (include "arkcase.dev" $ctx | fromYaml) -}}

  {{- $loggers := $.loggers -}}
  {{- if or (not $loggers) (not (kindIs "map" $loggers)) -}}
    {{- $loggers = dict -}}
  {{- end -}}
  {{- $loggers = (include "arkcase.sanitizeLoggers" $loggers | fromYaml) -}}

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
