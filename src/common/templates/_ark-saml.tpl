{{- define "arkcase.saml.config" -}}
  {{- $config := $ -}}
  {{- $results := dict -}}
  {{-
    $required :=
      list
        "entityId"
        "arkcaseHost"
        "arkcaseContextPath"
        "identityProviderHost"
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

  {{- /* The config is valid! */ -}}
  {{- $results = set $results "saml" $config -}}
  {{- $results | toYaml -}}
{{- end -}}

{{- define "arkcase.saml.compute" -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The single parameter must be the root context ($ or .)" -}}
  {{- end -}}

  {{- $samlconfig := dict -}}

  {{- /* TODO: When we add KeyCloak et al, we need to support both local and global configurations */ -}}
  {{- /* This value must be a map with configs, or a true-false string */ -}}
  {{- $conf := (include "arkcase.tools.conf" (dict "ctx" $ctx "value" "sso" "detailed" true) | fromYaml) -}}
  {{- $saml := dict -}}
  {{- if $conf.found -}}
    {{- $conf := $conf.value -}}
    {{- if and $conf $conf.enabled $conf.protocol $conf.saml (include "arkcase.toBoolean" $conf.enabled) (eq "saml" $conf.protocol) -}}
      {{- $samlconfig = (include "arkcase.saml.config" $conf.saml) -}}
    {{- end -}}
  {{- end -}}
  {{- $samlconfig -}}
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
    {{- $yamlResult = (include "arkcase.saml.compute" $ctx) -}}
    {{- $masterCache = set $masterCache $chartName ($yamlResult | fromYaml) -}}
  {{- else -}}
    {{- $yamlResult = get $masterCache $chartName | toYaml -}}
  {{- end -}}
  {{- $yamlResult -}}
{{- end -}}
