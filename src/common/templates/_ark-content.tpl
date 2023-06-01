{{- define "arkcase.content.info.compute" -}}
  {{- if not (include "arkcase.isRootContext" $) -}}
    {{- fail "The parameter given must be the root context (. or $)" -}}
  {{- end -}}

  {{- $global := ((($.Values.global).conf).content | default dict) -}}
  {{- $local := (($.Values.configuration).content | default dict) -}}

  {{- /* Get the engine type */ -}}
  {{- $type := (include "arkcase.tools.conf" (dict "ctx" $ "value" "content.type")) -}}
  {{- if and $type (kindIs "string" $type) -}}
    {{- /* Sanitize the engine type */ -}}
    {{- $ltype := ($type | lower) -}}
    {{-
      $aliases :=
        dict
          "minio" "s3"
          "s3" "s3"
          "alfresco" "alfresco"
          "alf" "alfresco"
          "cmis" "alfresco"
    -}}
    {{- if not (hasKey $aliases $ltype) -}}
      {{- fail (printf "Invalid content engine type [%s] - must be one of %s" $type (keys $aliases | sortAlpha)) -}}
    {{- end -}}
    {{- $type = get $aliases $ltype -}}
  {{- else -}}
    {{- $type = "s3" -}}
  {{- end -}}

  {{- $auth := dict -}}
  {{- $authValues := dict -}}
  {{- $defaultUrl := "" -}}
  {{- if (eq "alfresco" $type) -}}
    {{- $defaultUrl = "http://content:8080/alfresco" -}}
    {{-
      $authValues =
        dict
          "username" true
          "password" true
          "shareUrl" true
    -}}
  {{- else if (eq "s3" $type) -}}
    {{- $defaultUrl = "http://content:9000" -}}
    {{-
      $authValues =
        dict
          "bucket" true
          "accessKey" true
          "secretKey" true
          "sessionToken" false
          "prefix" false
          "region" false
    -}}
  {{- end -}}

  {{- range $v, $r := $authValues -}}
    {{- $V := (include "arkcase.tools.conf" (dict "ctx" $ "value" (printf "content.%s" $v))) -}}
    {{- if $V -}}
      {{- $auth = set $auth $v $V -}}
    {{- else if $r -}}
      {{- fail (printf "Missing content configuration value '%s' for content engine type %s - must be a non-empty string" $v $type) -}}
    {{- end -}}
  {{- end -}}

  {{- $url := (include "arkcase.tools.conf" (dict "ctx" $ "value" "content.url") | default $defaultUrl) -}}
  {{- /* Parse the URL, to ensure it's valid */ -}}
  {{- $url = (include "arkcase.tools.parseUrl" $url | fromYaml) -}}

  {{- /* Special case - if we have an S3 prefix, we must sanitize it as a path and make sure it starts with a slash */ -}}
  {{- if (hasKey $auth "prefix") -}}
    {{- $prefix := (include "arkcase.tools.normalizePath" $auth.prefix) -}}
    {{- if not (hasPrefix "/" $prefix) -}}
      {{- $prefix = (printf "/%s" $prefix) -}}
    {{- end -}}
    {{- $auth = set $auth "prefix" $prefix -}}
  {{- end -}}

  {{- /* Special case - if we have an Alfresco shareUrl, parse it */ -}}
  {{- $shareUrl := dict -}}
  {{- if (hasKey $auth "shareUrl") -}}
    {{- $shareUrl = (include "arkcase.tools.parseUrl" $auth.shareUrl | fromYaml) -}}
    {{- $auth = omit $auth "shareUrl" -}}
  {{- end -}}

  {{- /* Return the configuration data */ -}}
  {{- $result := dict "type" $type "url" $url "auth" $auth -}}
  {{- if $shareUrl -}}
    {{- $result = set $result "shareUrl" $shareUrl -}}
  {{- end -}}
  {{- $result | toYaml -}}
{{- end -}}

{{- define "arkcase.content.info" -}}
  {{- if not (include "arkcase.isRootContext" $) -}}
    {{- fail "The parameter given must be the root context (. or $)" -}}
  {{- end -}}
  {{- $ctx := $ -}}

  {{- $cacheKey := "ContentInfo" -}}
  {{- $masterCache := dict -}}
  {{- if (hasKey $ctx $cacheKey) -}}
    {{- $masterCache = get $ctx $cacheKey -}}
    {{- if and $masterCache (not (kindIs "map" $masterCache)) -}}
      {{- $masterCache = dict -}}
    {{- end -}}
  {{- end -}}
  {{- $ctx = set $ctx $cacheKey $masterCache -}}

  {{- /* We do not use arkcase.fullname b/c we don't want to deal with partnames */ -}}
  {{- $chartName := (include "common.fullname" $ctx) -}}
  {{- $yamlResult := dict -}}
  {{- if not (hasKey $masterCache $chartName) -}}
    {{- $yamlResult = (include "arkcase.content.info.compute" $ctx) -}}
    {{- $masterCache = set $masterCache $chartName ($yamlResult | fromYaml) -}}
  {{- else -}}
    {{- $yamlResult = get $masterCache $chartName | toYaml -}}
  {{- end -}}
  {{- $yamlResult -}}
{{- end -}}
