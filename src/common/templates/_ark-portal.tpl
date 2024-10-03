{{- define "arkcase.portal" -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The single parameter must be the root context ($ or .)" -}}
  {{- end -}}

  {{- $global := ($ctx.Values.global | default dict) -}}
  {{- $portal := dict -}}
  {{- $key := "" -}}
  {{- range $key = (list "portal" "foia") -}}
    {{- /* We only ignore a key if it's not set */ -}}
    {{- if not (hasKey $ctx.Values.global $key) -}}
      {{- continue -}}
    {{- end -}}

    {{- /* If the key was set, we consume its contents */ -}}
    {{- $portal = (get $global $key | default dict) -}}
    {{- if not $portal -}}
      {{- $portal = dict "enabled" false -}}
      {{- break -}}
    {{- end -}}

    {{- /* This value must be a map with configs, or a true-false string */ -}}
    {{- if or (kindIs "bool" $portal) (kindIs "string" $portal) -}}
      {{- $portal = dict "enabled" (not (empty (include "arkcase.toBoolean" $portal))) -}}
    {{- end -}}

    {{- if (kindIs "map" $portal) -}}
      {{- /* All is well, sanitize the "enabled" flag */ -}}
      {{- /* Unlike other features, the portal must be explicitly enabled */ -}}
      {{- if (hasKey $portal "enabled") -}}
        {{- $portal = set $portal "enabled" (not (empty (include "arkcase.toBoolean" $portal.enabled))) -}}
      {{- else -}}
        {{- $portal = dict -}}
      {{- end -}}
    {{- else -}}
      {{- fail (printf "The global.%s configuration is bad - must be a bool, a string, or a map, but is a %s" $key (kindOf $portal)) -}}
    {{- end -}}

    {{- break -}}
  {{- end -}}

  {{- /* By here, $portal should have a dict - empty or not - that we can analyze further */ -}}
  {{- $result := dict -}}
  {{- if $portal.enabled -}}

    {{- /* We want a portal, so enable it and figure out the rest of the configurations */ -}}

    {{- /* LDAP configuration */ -}}
    {{- /* constant value, no longer configurable */ -}}
    {{- $ldapServer := "foia" -}}

    {{- $ldapDomain := (include "arkcase.ldap" (dict "ctx" $ "server" $ldapServer "value" "domain")) -}}
    {{- $ldapUserPrefix := (include "arkcase.ldap" (dict "ctx" $ "server" $ldapServer "value" "search.user.prefix") | default "") -}}
    {{- $ldapGroupPrefix := (include "arkcase.ldap" (dict "ctx" $ "server" $ldapServer "value" "search.groups.prefix") | default "") -}}

    {{- $generateUsers := (not (empty (include "arkcase.toBoolean" $portal.generateUsers))) -}}
    {{- $disableAuth := (not (empty (include "arkcase.toBoolean" $portal.disableAuth))) -}}

    {{- /* New! Configurable portal context!! */ -}}
    {{- $context := $key -}}
    {{- if (hasKey $portal "context") -}}
      {{- $context = ($portal.context | default "" | toString) -}}
      {{- $contextRegex := "^/?[^/]+$" -}}
      {{- if not (regexMatch $contextRegex $context) -}}
        {{- fail (printf "The portal context [%s] is not valid - must match /%s/" $context $contextRegex) -}}
      {{- end -}}
    {{- end -}}

    {{- /* In case it comes with a leading slash */ -}}
    {{- $context = trimPrefix "/" $context -}}

    {{- $portalId := (hasKey $portal "portalId" | ternary $portal.portalId "") -}}
    {{- if or (not $portalId) (not (kindIs "string" $portalId)) -}}
      {{- /* This default value was taken from the installer */ -}}
      {{- $portalId = "8c41ee4e-49d4-4acb-8bce-866e52de3e4e" -}}
    {{- end -}}

    {{- $apiSecret := (hasKey $portal "apiSecret" | ternary $portal.apiSecret "") -}}
    {{- if or (not $apiSecret) (not (kindIs "string" $apiSecret)) -}}
      {{- $apiSecret = "voSNRpEtMsK0ocueclMvd97KE7aTezFTtEOoYfe2MtX7/8t+dq1dXvlOMpD10B8Nu+R/UE8CA1rvD4o2Nrb9gwZt" -}}
    {{- end -}}

    {{- /* If we're not authenticating, then we won't be generating users */ -}}
    {{- $generateUsers = and $generateUsers (not $disableAuth) -}}

    {{- $notificationGroups := ($portal.notificationGroups | default list) -}}
    {{- if $notificationGroups -}}
      {{- if (kindIs "map" $notificationGroups) -}}
        {{- $notificationGroups = (keys $notificationGroups) -}}
      {{- else if (not (kindIs "slice" $notificationGroups)) -}}
        {{- $notificationGroups = ($notificationGroups | toString | splitList ",") -}}
      {{- end -}}
      {{- $notificationGroups = ($notificationGroups | compact | sortAlpha | uniq) -}}
    {{- end -}}

    {{- /* Make sure there are always entries here */ -}}
    {{- if not $notificationGroups -}}
      {{- $notificationGroups = list "OFFICERS" -}}
    {{- end -}}

    {{- /* default values */ -}}
    {{-
      $result = dict
        "context" $context
        "apiSecret" $apiSecret
        "disableAuth" $disableAuth
        "generateUsers" $generateUsers
        "portalId" $portalId
        "ldap" (
          dict
            "server" $ldapServer
            "userPrefix" $ldapUserPrefix
            "groupPrefix" $ldapGroupPrefix
            "domain" $ldapDomain
          )
        "notificationGroups" $notificationGroups
    -}}
  {{- end -}}
  {{- $result | toYaml -}}
{{- end -}}
