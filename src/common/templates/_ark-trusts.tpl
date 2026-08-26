{{- define "__arkcase.trusts.parse-link" -}}
  {{- $link := (. | toString) -}}
  {{- $link = (include "arkcase.tools.parseUrl" $link | fromYaml) -}}

  {{- $result := dict -}}
  {{- $type := ($link.scheme | lower) -}}
  {{- if has $type (list "secret" "configmap") -}}
    {{- $type = ((eq "secret" $type) | ternary $type "configMap") -}}

    {{- $name := $link.host -}}
    {{- if not (include "arkcase.tools.checkHostname" $name) -}}
      {{- fail (printf "The resource name [%s] is not valid (from [%s])" $name .) -}}
    {{- end -}}

    {{- $key := $link.fragment -}}
    {{- if not (regexMatch "^[-._a-zA-Z0-9]+$" $key) -}}
      {{- fail (printf "The target key [%s] is not a valid key for a %s resource (from [%s])" $key $type .) -}}
    {{- end -}}

    {{-
      $result = dict
        "type" $type
        "name" $name
        "key" $key
    -}}
  {{- end -}}
  {{- $result | toYaml -}}
{{- end -}}

{{- define "__arkcase.trusts.compute" -}}
  {{- if not (include "arkcase.isRootContext" $) -}}
    {{- fail "The parameter given must be the root context (. or $)" -}}
  {{- end -}}

  {{- $global := ($.Values.global | default dict) -}}
  {{- if or (not $global) (not (kindIs "map" $global)) -}}
    {{- $global = dict -}}
  {{- end -}}

  {{- $trusts := $global.trusts -}}
  {{- if or (not $trusts) (not (kindIs "slice" $trusts)) -}}
    {{- $trusts = list -}}
  {{- end -}}

  {{- $certs := list -}}
  {{- $links := dict "secret" dict "configMap" dict -}}

  {{- $dupes := dict -}}
  {{- $current := 0 -}}
  {{- range $trusts -}}
    {{- $current = add 1 $current -}}
    {{- if (kindIs "string" .) -}}
      {{- $value := "" -}}
      {{- $type := "" -}}
      {{- if and (contains "-----BEGIN CERTIFICATE-----" .) (contains "-----END CERTIFICATE-----" .) -}}
        {{- $value = . -}}
        {{- $type = "pem" -}}
      {{- else if (regexMatch "^([^:/?#]+)://([^/?#]*)([^?#]*)([?]([^#]*))?(#(.*))?$" .) -}}
        {{- $value = . -}}
        {{- $type = "url" -}}
        {{- $newLink := (include "__arkcase.trusts.parse-link" $value | fromYaml) -}}
        {{- if $newLink -}}
          {{- $typeDict := (get $links $newLink.type | default dict) -}}
          {{- $keys := (get $typeDict $newLink.name | default list) -}}
          {{- $keys = (append $keys $newLink.key | sortAlpha | uniq) -}}
          {{- $typeDict = set $typeDict $newLink.name $keys -}}
          {{- $links = set $links $newLink.type $typeDict -}}
          {{- continue -}}
        {{- end -}}
      {{- else if (regexMatch "^(([^@:/]+)@)?(([^@:/]+):([^@:/]+))(/.*)?$" .) -}}
        {{- $value = . -}}
        {{- $type = "ssl" -}}
      {{- else -}}
        {{- fail (printf "Value # %d for global.trusts is not valid - must be a PEM-encoded certificate, URL from which to download one (using curl), or an SSL endpoing of the form [serverName@]hostnameOrIP[:port]. Bad value = [%s]" $current .) -}}
      {{- end -}}

      {{- if $value -}}
        {{- $hash := ($value | sha256sum) -}}
        {{- if (not (hasKey $dupes $hash)) -}}
          {{- $name := (printf "ssl-trust-%03d" (len $certs)) -}}
          {{- $result := (dict "type" $type "name" $name "value" $value "hash" $hash) -}}
          {{- $certs = append $certs $result -}}
          {{- $dupes = set $dupes $hash $result -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}

  {{- dict "certs" $certs "links" $links | toYaml -}}
{{- end -}}

{{- define "arkcase.trusts" -}}
  {{- $args :=
    dict
      "ctx" $
      "template" "__arkcase.trusts.compute"
  -}}
  {{- include "__arkcase.tools.getCachedValue" $args -}}
{{- end -}}

{{- define "arkcase.trusts.dir" -}}
/.trusts
{{- end -}}

{{- define "arkcase.trusts.secret-name" -}}
  {{- if not (include "arkcase.isRootContext" $) -}}
    {{- fail "The parameter given must be the root context (. or $)" -}}
  {{- end -}}
  {{- printf "%s-ssl-trusts" $.Release.Name -}}
{{- end -}}

{{- define "arkcase.trusts.mount" -}}
  {{- if not (include "arkcase.isRootContext" $) -}}
    {{- fail "The parameter given must be the root context (. or $)" -}}
  {{- end -}}
  {{- $volumeName := (include "arkcase.trusts.secret-name" $) -}}
  {{- $trustsDir := (include "arkcase.trusts.dir" $) -}}
  {{- $trusts := (include "arkcase.trusts" $ | fromYaml) -}}
  {{- $first := true -}}
  {{- with (include "arkcase.trusts" $ | fromYaml) }}
    {{- range .certs }}
      {{- if $first }}
# These are the statically-added trusts in the configuration
        {{- $first = false }}
      {{- end }}
      {{- $name := (printf "%s.%s" .name .type) }}
- name: {{ $volumeName | quote }}
  mountPath: {{ printf "%s/%s" $trustsDir $name | quote }}
  subPath: {{ $name | quote }}
  readOnly: true
    {{- end }}
  {{- end }}
  {{- $resNum := 0 }}
  {{- range $type := (keys $trusts.links | sortAlpha) }}
    {{- $items := get $trusts.links $type }}
    {{- if eq 0 $resNum }}
# These are the dynamic trusts added from other secrets/configMaps
    {{- end }}
    {{- range $resource := (keys $items | sortAlpha) }}
      {{- $volumeName = (printf "ssl-trust-link-%03d" $resNum) }}
      {{- $keys := (get $items $resource) }}
      {{- $keyNum := 0 }}
      {{- range $key := ($keys | sortAlpha) }}
- name: {{ $volumeName | quote }}
  mountPath: {{ printf "%s/ssl-trust-link-%03d-%03d.pem" $trustsDir $resNum $keyNum | quote }}
  subPath: {{ $key | quote }}
  readOnly: true
        {{- $keyNum = add $keyNum 1 }}
      {{- end }}
      {{- $resNum = add $resNum 1 }}
    {{- end }}
  {{- end }}
{{- end -}}

{{- define "arkcase.trusts.volume" -}}
  {{- if not (include "arkcase.isRootContext" $) -}}
    {{- fail "The parameter given must be the root context (. or $)" -}}
  {{- end -}}
  {{- $secretName := (include "arkcase.trusts.secret-name" $) -}}
  {{- $trusts := (include "arkcase.trusts" $ | fromYaml) -}}
# This is the secret containing the statically-added trusts in the configuration
- name: {{ $secretName | quote }}
  secret:
    optional: true
    secretName: {{ $secretName | quote }}
    defaultMode: 0444
  {{- $resNum := 0 }}
  {{- range $type := (keys $trusts.links | sortAlpha) }}
    {{- $items := get $trusts.links $type }}
    {{- if eq 0 $resNum }}
# These are the secrets and configMaps containing the dynamic trusts
    {{- end }}
    {{- $nameAtt := ((eq "secret" $type) | ternary "secretName" "name") }}
    {{- range $resource := (keys $items | sortAlpha) }}
- name: {{ printf "ssl-trust-link-%03d" $resNum | quote }}
  {{ $type }}:
    optional: true
    {{ $nameAtt }}: {{ $resource | quote }}
    defaultMode: 0444
      {{- $resNum = add $resNum 1 }}
    {{- end }}
  {{- end }}
{{- end -}}

{{- define "arkcase.trusts.secret" -}}
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "arkcase.trusts.secret-name" $ | quote }}
  namespace: {{ .Release.Namespace | quote }}
  labels: {{- include "arkcase.labels" $ | nindent 4 }}
    {{- with ($.Values.labels).common }}
      {{- toYaml . | nindent 4 }}
    {{- end }}
  annotations:
    {{- with ($.Values.annotations).common }}
      {{- toYaml . | nindent 4 }}
    {{- end }}
type: Opaque
stringData:
  {{- with (include "arkcase.trusts" $ | fromYaml) }}
    {{- range .certs }}
      {{- $name := (printf "%s.%s" .name .type) }}
      {{- if (eq "pem" .type) }}
  {{ $name }}: |- {{- .value | nindent 4 }}
      {{- else }}
  {{ $name }}: {{ .value | quote }}
      {{- end }}
    {{- end }}
  {{- end }}
{{- end -}}
