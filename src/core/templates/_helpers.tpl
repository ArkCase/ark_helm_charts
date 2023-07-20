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
  {{- $host := ($messaging.host | default "messaging") -}}
  {{- $port := (include "arkcase.tools.conf" (dict "ctx" $ "value" "messaging.openwire") | default "61616" | int) -}}
  {{- printf "%s://%s:%d" $scheme $host $port -}}
{{- end -}}

{{- define "arkcase.core.content.url" -}}
  {{- if not (include "arkcase.isRootContext" $) -}}
    {{- fail "Must send the root context as the only parameter" -}}
  {{- end -}}

  {{- $contentUrl := (include "arkcase.tools.conf" (dict "ctx" $ "value" "content.url")) -}}
  {{- if not ($contentUrl) -}}
    {{- $dialect := (include "arkcase.tools.conf" (dict "ctx" $ "value" "content.dialect")) -}}
    {{- if or (not $dialect) (eq "alfresco" $dialect) -}}
      {{- $contentUrl = "http://content-main:8080/alfresco" -}}
    {{- else if (eq "s3" $dialect) -}}
      {{- $contentUrl = "http://content-minio:9000/" -}}
    {{- else -}}
      {{- fail (printf "Unsupported content dialect [%s]" $dialect) -}}
    {{- end -}}
  {{- end -}}
  {{- $contentUrl -}}
{{- end -}}

{{- define "arkcase.core.content.share" -}}
  {{- if not (include "arkcase.isRootContext" $) -}}
    {{- fail "Must send the root context as the only parameter" -}}
  {{- end -}}

  {{- $shareUrl := (include "arkcase.tools.conf" (dict "ctx" $ "value" "content.shareUrl")) -}}
  {{- if not ($shareUrl) -}}
    {{- $shareUrl = "http://content-share:8080/share" -}}
  {{- end -}}
  {{- $shareUrl -}}
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
