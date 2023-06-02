{{- define "arkcase.content.info.get" -}}
  {{- $local := $.local -}}
  {{- $global := $.global -}}
  {{- $value := $.value -}}

  {{- $local = (include "arkcase.tools.get" (dict "ctx" $local "name" $value) | fromYaml) -}}
  {{- $local = (eq "string" $local.type) | ternary $local.value "" -}}
  {{- $global = (include "arkcase.tools.get" (dict "ctx" $global "name" $value) | fromYaml) -}}
  {{- $global = (eq "string" $global.type) | ternary $global.value "" -}}

  {{- (empty $global) | ternary $local $global -}}
{{- end -}}

{{- define "arkcase.content.sanitizeDialect" -}}
  {{- $dialect := $ -}}
  {{- if not $dialect -}}
    {{- $dialect = "s3" -}}
  {{- end -}}
  {{- if (not (kindIs "string" $dialect)) -}}
    {{- fail (printf "The dialect to sanitize must be a non-empty string value: (%s)" (kindOf $dialect)) -}}
  {{- end -}}

  {{- /* Sanitize the engine dialect */ -}}
  {{- $ldialect := ($dialect | lower) -}}
  {{-
    $aliases :=
      dict
        "minio" "s3"
        "s3" "s3"
        "alfresco" "alfresco"
        "alf" "alfresco"
        "cmis" "alfresco"
  -}}
  {{- if not (hasKey $aliases $ldialect) -}}
    {{- fail (printf "Invalid content engine dialect [%s] - must be one of %s" $dialect (keys $aliases | sortAlpha)) -}}
  {{- end -}}
  {{- get $aliases $ldialect -}}
{{- end -}}

{{- define "arkcase.content.info.compute" -}}
  {{- if not (include "arkcase.isRootContext" $) -}}
    {{- fail "The parameter given must be the root context (. or $)" -}}
  {{- end -}}

  {{- $global := ((($.Values.global).conf).content | default dict) -}}
  {{- $local := (($.Values.configuration).content | default dict) -}}
  {{- $getParams := dict "local" $local "global" $global -}}

  {{- /* Get the engine dialect */ -}}
  {{- $dialect := (include "arkcase.content.info.get" (set $getParams "value" "dialect")) -}}
  {{- $dialect = (include "arkcase.content.sanitizeDialect" $dialect) -}}

  {{- $auth := dict -}}
  {{- $authValues := dict -}}
  {{- if (eq "alfresco" $dialect) -}}
    {{-
      $authValues =
        dict
          "username" true
          "password" true
          "shareUrl" false
    -}}
  {{- else if (eq "s3" $dialect) -}}
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

  {{- $failures := list -}}
  {{- range $v, $r := $authValues -}}
    {{- $V := (include "arkcase.content.info.get" (set $getParams "value" $v)) -}}
    {{- if $V -}}
      {{- $auth = set $auth $v $V -}}
    {{- else if $r -}}
      {{- $failures = append $failures $v -}}
    {{- end -}}
  {{- end -}}
  {{- if $failures -}}
    {{- fail (printf "Missing content configuration values for content engine dialect %s (must be non-empty strings): %s" $dialect $failures) -}}
  {{- end -}}

  {{- $url := (include "arkcase.content.info.get" (set $getParams "value" "url")) -}}
  {{- if not $url -}}
    {{- fail "Must provide a non-empty content url configuration (global.conf.content.url or configuration.content.url)" -}}
  {{- end -}}
  {{- /* Parse the URL, to ensure it's valid */ -}}
  {{- $url = (include "arkcase.tools.parseUrl" $url | fromYaml) -}}

  {{- if eq "s3" $dialect -}}
    {{- /* Special case - if we have an S3 prefix, we must sanitize it as a path and make sure it starts with a slash */ -}}
    {{- $prefix := (hasKey $auth "prefix") | ternary $auth.prefix "" -}}
    {{- if $prefix -}}
      {{- $prefix := (include "arkcase.tools.normalizePath" $auth.prefix) -}}
      {{- if and $prefix (not (hasPrefix "/" $prefix)) -}}
        {{- $prefix = (printf "/%s" $prefix) -}}
      {{- end -}}
      {{- $auth = set $auth "prefix" $prefix -}}
    {{- end -}}
  {{- end -}}

  {{- if eq "alfresco" $dialect -}}
    {{- /* Special case - if we have an Alfresco shareUrl, parse it */ -}}
    {{- if not $auth.shareUrl -}}
      {{- fail "Must provide a non-empty content share url configuration (global.conf.content.shareUrl or configuration.content.shareUrl)" -}}
    {{- end -}}
    {{- $auth = set $auth "shareUrl" (include "arkcase.tools.parseUrl" $auth.shareUrl | fromYaml) -}}
  {{- end -}}

  {{- /* Return the configuration data */ -}}
  {{- merge (dict "dialect" $dialect "url" $url) $auth | toYaml -}}
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

{{- define "arkcase.content.info.dialect" -}}
  {{- if not (include "arkcase.isRootContext" $) -}}
    {{- fail "The parameter given must be the root context (. or $)" -}}
  {{- end -}}
  {{- $dialect := (include "arkcase.tools.conf" (dict "ctx" $ "value" "content.dialect")) -}}
  {{- include "arkcase.content.sanitizeDialect" $dialect -}}
{{- end -}}
