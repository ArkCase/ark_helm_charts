{{- define "arkcase.oidc.clients" -}}
  {{- $clients := $ -}}
  {{- if not (kindIs "map" $clients) -}}
    {{- fail (printf "The OIDC configuration must be given as a map, not a %s: %s" (kindOf $clients) $clients) -}}
  {{- end -}}

  {{- $results := dict -}}
  {{- if and $clients (kindIs "map" $clients) -}}
    {{-
      $required :=
        list 
          "authorizationUri"
          "clientId"
          "clientSecret"
          "jwkSetUri"
          "redirectUri"
          "registrationId"
          "scope"
          "tokenUri"
          "userInfoUri"
          "usernameAttribute"
          "usersDirectory"
          "responseType"
          "responseMode"
    -}}
    {{- range $id, $client := $clients -}}

      {{- /* This allows us to ignore empty client configurations */ -}}
      {{- if not $client -}}
        {{- continue -}}
      {{- end -}}

      {{- if (not (kindIs "map" $client)) -}}
        {{- fail (printf "OIDC configuration for client '%s' is of type [%s], but it should be a map" $id (kindOf $client)) -}}
      {{- end -}}

      {{- /* Allow clients to be enabled/disabled individually */ -}}
      {{- if and (hasKey $client "enabled") (not (include "arkcase.toBoolean" $client.enabled)) -}}
        {{- continue -}}
      {{- end -}}

      {{- /* TODO: Is this correct? Do we want to check ALL settings? */ -}}
      {{- $missing := list -}}
      {{- range $key := $required -}}
        {{- if (not (hasKey $client $key)) -}}
          {{- $missing = append $missing $key -}}
        {{- end -}}
      {{- end -}}

      {{- if $missing -}}
        {{- fail (printf "OIDC Configuration for client '%s' is missing the following configurations: %s" $id $missing) -}}
      {{- end -}}

      {{- /*
         TODO: The clientId and clientSecret values MUST come from a secret, and
               be exposed to the application via environment variables, so the
               generated configuration will point to those envvars
      */ -}}

      {{- /* The client is valid! */ -}}
      {{- $results = set $results $id (omit $client "enabled") -}}
    {{- end -}}
  {{- end -}}
  {{- $results | toYaml -}}
{{- end -}}

{{- define "arkcase.oidc.compute" -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The single parameter must be the root context ($ or .)" -}}
  {{- end -}}

  {{- /* TODO: When we add KeyCloak et al, we need to support both local and global configurations */ -}}
  {{- /* This value must be a map with configs, or a true-false string */ -}}
  {{- $conf := (include "arkcase.tools.conf" (dict "ctx" $ctx "value" "sso" "detailed" true) | fromYaml) -}}

  {{- $oidc := dict -}}
  {{- if and $conf.found $conf.value -}}
    {{- $conf = $conf.value -}}
    {{- if not (kindIs "map" $conf) -}}
      {{- fail (printf "The SSO configuration must be given as a map, not a %s: %s" (kindOf $conf) $conf) -}}
    {{- end -}}

    {{- /* The enabled flag is on by default, unless explicitly turned off */ -}}
    {{- $enabled := or (not (hasKey $conf "enabled")) (include "arkcase.toBoolean" $conf.enabled) -}}
    {{- if and $enabled $conf.oidc (eq "oidc" $conf.protocol) -}}
      {{- $conf = $conf.oidc -}}
      {{- $clients := (include "arkcase.oidc.clients" $conf.clients | fromYaml) -}}

      {{- /* We also condition the configuation on whether there are client configurations */ -}}
      {{- if not $clients -}}
        {{- fail "OIDC seems to be enabled, but no clients are defined" -}}
      {{- end -}}

      {{- /* Special consideration here: legacy mode will be enabled if we only have one client, and it's called "arkcase" */ -}}
      {{- $oidc = dict "clients" $clients "legacy" (and (eq (len $clients) 1) (hasKey $clients "arkcase")) -}}
    {{- end -}}
  {{- end -}}
  {{- $oidc | toYaml -}}
{{- end -}}

{{- define "arkcase.oidc" -}}
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

  {{- $cacheKey := "OIDC" -}}
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
    {{- $yamlResult = (include "arkcase.oidc.compute" $ctx) -}}
    {{- $masterCache = set $masterCache $chartName ($yamlResult | fromYaml) -}}
  {{- else -}}
    {{- $yamlResult = get $masterCache $chartName | toYaml -}}
  {{- end -}}
  {{- $yamlResult -}}
{{- end -}}
