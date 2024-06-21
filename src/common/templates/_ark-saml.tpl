{{- define "arkcase.saml.config" -}}
  {{- $config := $ -}}
  {{- if not (kindIs "map" $config) -}}
    {{- fail (printf "The SAML configuration must be given as a map, not a %s: %s" (kindOf $config) $config) -}}
  {{- end -}}
  {{-
    $required :=
      list
        "entityId"
        "identityProviderUrl"
  -}}

  {{- $missing := list -}}
  {{- range $key := $required -}}
    {{- if (not (hasKey $config $key)) -}}
      {{- $missing = append $missing $key -}}
    {{- end -}}
  {{- end -}}
  {{- if $missing -}}
    {{- fail (printf "SAML Configuration is missing the following keys: %s" $missing) -}}
  {{- end -}}

  {{- /* The config is valid! But we only return that which is important */ -}}
  {{- pick $config "entityId" "identityProviderUrl" | toYaml -}}
{{- end -}}

{{- define "arkcase.saml.compute" -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The single parameter must be the root context ($ or .)" -}}
  {{- end -}}

  {{- /* TODO: When we add KeyCloak et al, we need to support both local and global configurations */ -}}
  {{- /* This value must be a map with configs, or a true-false string */ -}}
  {{- $conf := (include "arkcase.tools.conf" (dict "ctx" $ctx "value" "sso" "detailed" true) | fromYaml) -}}
  {{- $samlconfig := dict -}}
  {{- if and $conf.found $conf.value -}}
    {{- $conf = $conf.value -}}
    {{- if not (kindIs "map" $conf) -}}
      {{- fail (printf "The SSO configuration must be given as a map, not a %s: %s" (kindOf $conf) $conf) -}}
    {{- end -}}

    {{- $enabled := (or (not (hasKey $conf "enabled")) (include "arkcase.toBoolean" $conf.enabled)) -}}
    {{- if and $enabled (eq "saml" $conf.protocol) $conf.saml -}}
      {{- $samlconfig = (include "arkcase.saml.config" $conf.saml | fromYaml) -}}
      {{- $arkcaseUrl := (include "arkcase.tools.conf" (dict "ctx" $ "value" "baseUrl")) -}}
      {{- $samlconfig = set $samlconfig "arkcaseUrl" (include "arkcase.tools.parseUrl" $arkcaseUrl | fromYaml) -}}
    {{- end -}}
  {{- end -}}
  {{- $samlconfig | toYaml -}}
{{- end -}}

{{- define "arkcase.saml" -}}
  {{- $ctx := . -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The parameter given must be the root context (. or $)" -}}
  {{- end -}}

  {{- /* First things first: do we have any global overrides? */ -}}
  {{- $global := $ctx.Values.global -}}
  {{- if or (not $global) (not (kindIs "map" $global)) -}}
    {{- $global = dict -}}
  {{- end -}}

  {{- /* Now get the local values */ -}}
  {{- $local := $ctx.Values.configuration -}}
  {{- if or (not $local) (not (kindIs "map" $local)) -}}
    {{- $local = dict -}}
  {{- end -}}

  {{- /* The keys on this map are the images in the local repository */ -}}
  {{- $chart := $ctx.Chart.Name -}}
  {{- $data := dict "local" $local "global" $global -}}

  {{- $cacheKey := "SAML" -}}
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
    {{- $yamlResult = (include "arkcase.saml.compute" $ctx) | fromYaml -}}
    {{- $masterCache = set $masterCache $chartName $yamlResult -}}
  {{- else -}}
    {{- $yamlResult = get $masterCache $chartName -}}
  {{- end -}}
  {{- $yamlResult | toYaml -}}
{{- end -}}
