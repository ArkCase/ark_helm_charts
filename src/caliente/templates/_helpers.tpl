{{- define "arkcase.caliente.objectName" -}}
  {{- $part := (include "arkcase.part.name" $) -}}
  {{- $release := $.Release.Name -}}
  {{- if $part -}}
    {{- $part = (printf "%s-%s" $release $part) -}}
  {{- else -}}
    {{- $part = $release -}}
  {{- end -}}
  {{- $part -}}
{{- end -}}

{{- define "arkcase.caliente.acme" -}}
  {{- /* First, identify which secret is in use - old or new */ -}}

  {{- /* Old secret: ${release}-acme-shared */ -}}
  {{- /* Old url: "https://acme:9000" */ -}}
  {{- /* Old key: ${secret}.ACME_CLIENT_PASSWORD */ -}}

  {{- /* New secret: ${release}-acme-main */ -}}
  {{- /* New url: ${secret}.url */ -}}
  {{- /* New key: ${secret}.password */ -}}

  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "You must supply the root context as the only parameter" -}}
  {{- end -}}

  {{- $serviceName := (include "arkcase.caliente.objectName" $ctx) -}}
  {{- $arkcase := ($ctx.Values.arkcase | default "arkcase") -}}
  {{- $namespace := $ctx.Release.Namespace -}}

  {{- $secretName := (printf "%s-acme-main" $arkcase) -}}
  {{- $passwordKey := "password" -}}
  {{- $urlKey := "url" -}}

  {{- $legacy := (empty (lookup "v1" "Secret" $namespace $secretName)) -}}

  {{- /* Compute the environment variables */ -}}
  {{- $urlEnv := dict -}}

  {{- /* Identify the type of ArkCase we're latching on to */ -}}
  {{- if $legacy -}}
    {{- $secretName = (printf "%s-acme-shared" $arkcase) -}}
    {{- if (empty (lookup "v1" "Secret" $namespace $secretName)) -}}
      {{- fail (printf "There doesn't seem to be an ArkCase release named [%s] in the %s namespace - couldn't find either the legacy or modern ACME secrets" $arkcase $namespace) -}}
    {{- end -}}

    {{- $passwordKey = "ACME_CLIENT_PASSWORD" -}}
    {{- $urlEnv = dict "value" "https://acme:9000" -}}
  {{- else -}}
    {{-
      $urlEnv = dict
        "valueFrom" (
          dict
            "secretKeyRef" (
              dict
                "name" $secretName
                "key" $urlKey
                "optional" false
            )
        )
    -}}
  {{- end -}}

  {{- /* Compute the environment variables */ -}}
  {{-
    $env := list
      (
        dict
          "name" "SSL_DIR"
          "value" "/.ssl"
      )
      (
        dict
          "name" "ACME_SERVICE_NAME"
          "value" $serviceName
      )
      (
        merge (dict "name" "ACME_URL") $urlEnv
      )
  -}}

  {{- /* Compute the volume mounts */ -}}
  {{- $secretVolumeName := (printf "vol-%s" $secretName) -}}
  {{-
    $volumeMount := list
      (
        dict
          "name" $secretVolumeName
          "mountPath" "/.acme.password"
          "subPath" $passwordKey
          "readOnly" true
      )
  -}}

  {{- /* Compute the volumes */ -}}
  {{-
    $volume := list
      (
        dict
          "name" $secretVolumeName
          "secret" (
            dict
              "secretName" $secretName
              "defaultMode" 0444
              "optional" false
          )
      )
  -}}

  {{- dict "env" $env "volumeMount" $volumeMount "volume" $volume | toYaml -}}
{{- end -}}

{{- define "arkcase.caliente.alfresco-env" -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "You must supply the root context as the only parameter" -}}
  {{- end -}}

  {{- $arkcase := ($ctx.Values.arkcase | default "arkcase") -}}
  {{- $namespace := $ctx.Release.Namespace -}}

  {{- $keys := dict -}}
  {{- $secretName := (printf "%s-content-admin" $arkcase) -}}
  {{- if (lookup "v1" "Secret" $namespace $secretName) -}}
    {{- /* Get all the values from the modern secret */ -}}
    {{- $keys = dict "url" "" "username" "" "password" "" -}}
  {{- else -}}
    {{- $secretName = (printf "%s-core" $arkcase) -}}
    {{- if (lookup "v1" "Secret" $namespace $secretName) -}}
      {{- /* Only some values come from the legacy secret */ -}}
      {{- $keys = dict "username" "contentUsername" "password" "contentPassword" -}}
      {{- /* This URL is hardcoded in the legacy chart */ -}}
- name: "ALFRESCO_URL"
  value: "https://content-main:8080"
    {{- end -}}
  {{- end -}}
  {{- range $k, $v := $keys }}
- name: {{ printf "ALFRESCO_%s" $k | upper | quote }}
  valueFrom:
    secretKeyRef:
      name: {{ $secretName | quote }}
      key: {{ $v | default $k | quote }}
      optional: false
  {{- end }}
{{- end -}}
