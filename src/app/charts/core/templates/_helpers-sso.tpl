{{- define "__arkcase.core.sso.saml.parse-config" -}}
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
    {{- fail (printf "The SAML Configuration is missing the following keys: %s" $missing) -}}
  {{- end -}}

  {{- /* The config is valid! But we only return that which is important */ -}}
  {{- pick $config "entityId" "identityProviderUrl" | toYaml -}}
{{- end -}}

{{- define "__arkcase.core.sso.compute.saml" -}}
  {{- $ctx := $.ctx -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The 'ctx' parameter must be the root context ($ or .)" -}}
  {{- end -}}

  {{- /* This will be the global.sso.saml settings, if they exist */ -}}
  {{- $saml := $.conf -}}
  {{- if not (kindIs "map" $saml) -}}
    {{- fail (printf "The SAML configuration must be given as a map, not a %s: %s" (kindOf $saml) $saml) -}}
  {{- end -}}

  {{- $saml = (include "__arkcase.core.sso.saml.parse-config" $saml | fromYaml) -}}

  {{- /* We parse the required URLs right away, to make sure they're valid and for further use */ -}}
  {{- $identityProviderUrl := ($saml.identityProviderUrl | toString) -}}
  {{- $saml = set $saml "identityProviderUrl" (include "arkcase.tools.parseUrl" $identityProviderUrl | fromYaml) -}}
  {{- if not $saml.identityProviderUrl -}}
    {{- fail (printf "The SAML identityProviderUrl is not a valid URL: [%s]" $identityProviderUrl) -}}
  {{- end -}}

  {{- /* We add this here for convenience later on */ -}}
  {{- $arkcaseUrl := (include "arkcase.tools.conf" (dict "ctx" $ctx "value" "baseUrl")) -}}
  {{- $saml = set $saml "arkcaseUrl" (include "arkcase.tools.parseUrl" $arkcaseUrl | fromYaml) -}}
  {{- $saml = set $saml "profiles" (list "externalSaml") -}}
  {{- $saml | toYaml -}}
{{- end -}}

{{- define "__arkcase.core.sso.oidc.parse-clients" -}}
  {{- $clients := $.oidc -}}
  {{- if not (kindIs "map" $clients) -}}
    {{- fail (printf "The OIDC configuration must be given as a map, not a %s: %s" (kindOf $clients) $clients) -}}
  {{- end -}}
  {{- $usersDirectory := $.usersDirectory -}}
  {{- $baseUrl := (printf "%s/login/oauth2/code" $.baseUrl) -}}

  {{- $results := dict -}}
  {{- if and $clients (kindIs "map" $clients) -}}
    {{-
      $required :=
        list 
          "authorizationUri"
          "clientId"
          "clientSecret"
          "jwkSetUri"
          "registrationId"
          "scope"
          "tokenUri"
          "userInfoUri"
          "usernameAttribute"
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

      {{- /* The client is valid! Clean the map a little */ -}}
      {{- $client = (omit $client "enabled") -}}

      {{- /* Set the usersDirectory to the specified value */ -}}
      {{- $client = set $client "usersDirectory" $usersDirectory -}}

      {{- /* Set the redirectUri to the specified value */ -}}
      {{- $client = set $client "redirectUri" (printf "%s/%s" $baseUrl $client.registrationId) -}}

      {{- /* Store the result */ -}}
      {{- $results = set $results $id $client -}}
    {{- end -}}
  {{- end -}}
  {{- $results | toYaml -}}
{{- end -}}

{{- define "__arkcase.core.sso.compute.oidc" -}}
  {{- $ctx := $.ctx -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The 'ctx' parameter must be the root context ($ or .)" -}}
  {{- end -}}

  {{- $oidc := $.conf -}}
  {{- if not (kindIs "map" $oidc) -}}
    {{- fail (printf "The OIDC configuration must be given as a map, not a %s: %s" (kindOf $oidc) $oidc) -}}
  {{- end -}}

  {{- /* Set the usersDirectory for all clients to the default one ... */ -}}
  {{- $baseUrl := (include "arkcase.tools.conf" (dict "ctx" $ctx "value" "baseUrl")) -}}
  {{- /* Remove any potential trailing slashes */ -}}
  {{- $baseUrl = (regexReplaceAll "/*$" $baseUrl "") -}}

  {{- /* The enabled flag is on by default, unless explicitly turned off */ -}}
  {{- $clients := (include "__arkcase.core.sso.oidc.parse-clients" (dict "oidc" $oidc "usersDirectory" "arkcase" "baseUrl" $baseUrl) | fromYaml) -}}

  {{- /* We also condition the configuation on whether there are client configurations */ -}}
  {{- if not $clients -}}
    {{- fail "OIDC seems to be enabled, but no clients are enabled" -}}
  {{- end -}}

  {{- /* Special consideration here: legacy mode will be enabled if we only have one client, and it's called "arkcase" */ -}}
  {{- $profiles := list -}}
  {{- $legacy := false -}}
  {{- if (and (eq 1 (len $clients)) (or (hasKey $clients "arkcase") (hasKey $clients "legacy"))) -}}
    {{- $legacy = true -}}
    {{- /* Ensure the single client is called "arkcase" */ -}}
    {{- $clients = dict "arkcase" (($clients | values | first)) -}}
    {{- $profiles = list "externalOidc" -}}
  {{- else -}}
    {{- $profiles = list "ldap" -}}
  {{- end -}}
  {{- dict "clients" $clients "legacy" $legacy "profiles" $profiles | toYaml -}}
{{- end -}}

{{- define "__arkcase.core.sso.compute" -}}
  {{- $ctx := $ -}}
  {{- $sso := ($ctx.Values.global).sso | default dict -}}
  {{- $result := dict -}}
  {{- if $sso -}}
    {{- $enabled := or (not (hasKey $sso "enabled")) (include "arkcase.toBoolean" $sso.enabled) -}}
    {{- if $enabled -}}
      {{- if (not $sso) -}}
        {{- fail "You have enabled SSO, but not provided further configuration. Please refer to the manual for more information" -}}
      {{- end -}}

      {{- /*
          Here, the SSO configuration may contain a protocol and the "oidc" and "saml" sections

          Both are allowed to exist, but only one may be active at any given time. Thus, if both
          are present, the protocol MUST be present.

          If only one is present, the protocol is presumed to be the one present and we simply
          move forward.
      */ -}}

      {{- /* If we're given a protocol, we're being told to do specific things */ -}}
      {{- $protocol := "" -}}
      {{- if (hasKey $sso "protocol") -}}
        {{- $protocol = ($sso.protocol | toString) -}}
        {{- if (not (has $protocol (list "saml" "oidc"))) -}}
          {{- fail (printf "Invalid SSO protocol value [%s] - must be either 'saml' or 'oidc'" $protocol) -}}
        {{- end -}}

        {{- if (not (hasKey $sso $protocol)) -}}
          {{- fail (printf "You've selected to use the %s protocol for SSO, but not included the relevant configuation section. Please refer to the manual for more information" $protocol) -}}
        {{- end -}}
      {{- else -}}
        {{- /* No protocol given ... so there MUST be exactly one of either "oidc" or "saml" in the dict */ -}}
        {{- $saml := (hasKey $sso "saml") -}}
        {{- $oidc := (hasKey $sso "oidc") -}}

        {{- /* Quick test: are they both there, or neither there? */ -}}
        {{- if (eq $saml $oidc) -}}
          {{- if $saml -}}
            {{- /* Both are there */ -}}
            {{- fail "You have enabled SSO, and provided both 'oidc' and 'saml' sections, but no 'protocol' setting to activate only one of them. Please refer to the manual for more information" -}}
          {{- else -}}
            {{- /* Neither is there */ -}}
            {{- fail "You have enabled SSO, but not provided sufficient configuration - either an 'oidc' or 'saml' section must be present. Please refer to the manual for more information" -}}
          {{- end -}}
        {{- end -}}

        {{- /* Only one is there ... thus we can take a shortcut */ -}}
        {{- $protocol = ($saml | ternary "saml" "oidc") -}}
      {{- end -}}

      {{- /* This is the actual configuration for the chosen SSO mode */ -}}
      {{- $conf := (include (printf "__arkcase.core.sso.compute.%s" $protocol) (dict "ctx" $ctx "conf" (get $sso $protocol)) | fromYaml) -}}
      {{- if $conf -}}
        {{- $result = dict "protocol" $protocol "conf" $conf -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
  {{- $result | toYaml -}}
{{- end -}}

{{- define "arkcase.core.sso" -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The parameter must be the root context ($ or .)" -}}
  {{- end -}} 

  {{- $args :=
    dict
      "ctx" $ctx
      "template" "__arkcase.core.sso.compute"
  -}}
  {{- include "__arkcase.tools.getCachedValue" $args -}}
{{- end -}}

{{- define "__arkcase.core.sso-protocol" -}}
  {{- $sso := (include "arkcase.core.sso" $.ctx | fromYaml) -}}
  {{- if $sso -}}
    {{- if (eq $.proto $sso.protocol) -}}
      {{- $sso.conf | toYaml -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.core.sso.saml" -}}
  {{- include "__arkcase.core.sso-protocol" (dict "ctx" $ "proto" "saml") -}}
{{- end -}}

{{- define "arkcase.core.sso.oidc" -}}
  {{- include "__arkcase.core.sso-protocol" (dict "ctx" $ "proto" "oidc") -}}
{{- end -}}
