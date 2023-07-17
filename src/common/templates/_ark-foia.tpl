{{- define "arkcase.foia" -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The single parameter must be the root context ($ or .)" -}}
  {{- end -}}

  {{- if (include "arkcase.enterprise" $ctx) -}}
    {{- /* This value must be a map with configs, or a true-false string */ -}}
    {{- $foia := (($ctx.Values.global).foia) -}}
    {{- if $foia -}}
      {{- if or (kindIs "bool" $foia) (kindIs "string" $foia) -}}
        {{- $foia = (not (empty (include "arkcase.toBoolean" $foia))) | ternary (dict "enabled" true) dict -}}
      {{- else if (kindIs "map" $foia) -}}
        {{- /* All is well, sanitize the "enabled" flag */ -}}
        {{- if (hasKey $foia "enabled") -}}
          {{- $foia = set $foia "enabled" (not (empty (include "arkcase.toBoolean" $foia.enabled))) -}}
        {{- else -}}
          {{- /* Unlike other features, FOIA must be explicitly enabled */ -}}
          {{- $foia = set $foia "enabled" false -}}
        {{- end -}}
      {{- else -}}
        {{- fail (printf "The global.foia configuration is bad - must be a bool, a string, or a map (%s)" (kindOf $foia)) -}}
      {{- end -}}
    {{- else -}}
      {{- /* Empty value or equivalent, we don't care about the type and simply don't activate anything */ -}}
      {{- $foia = dict -}}
    {{- end -}}

    {{- $result := dict -}}
    {{- if $foia.enabled -}}
      {{- /* We want FOIA, so enable it and figure out the rest of the configurations */ -}}

      {{- /* LDAP configuration */ -}}
      {{- /* constant value */ -}}
      {{- $ldapServer := "foia" -}}
      {{- $ldapDomain := (include "arkcase.ldap" (dict "ctx" $ "server" $ldapServer "value" "domain")) -}}
      {{- $ldapGroupPrefix := (include "arkcase.ldap" (dict "ctx" $ "server" $ldapServer "value" "search.groups.prefix") | default "") -}}

      {{- $generateUsers := (not (empty (include "arkcase.toBoolean" $foia.generateUsers))) -}}
      {{- $disableAuth := (not (empty (include "arkcase.toBoolean" $foia.disableAuth))) -}}

      {{- $portalId := (hasKey $foia "portalId" | ternary $foia.portalId "") -}}
      {{- if or (not $portalId) (not (kindIs "string" $portalId)) -}}
        {{- /* This default value was taken from the installer */ -}}
        {{- $portalId = "8c41ee4e-49d4-4acb-8bce-866e52de3e4e" -}}
      {{- end -}}

      {{- $apiSecret := (hasKey $foia "apiSecret" | ternary $foia.apiSecret "") -}}
      {{- if or (not $apiSecret) (not (kindIs "string" $apiSecret)) -}}
        {{- $apiSecret = "voSNRpEtMsK0ocueclMvd97KE7aTezFTtEOoYfe2MtX7/8t+dq1dXvlOMpD10B8Nu+R/UE8CA1rvD4o2Nrb9gwZt" -}}
      {{- end -}}

      {{- /* If we're not authenticating, then we won't be generating users */ -}}
      {{- $generateUsers = and $generateUsers (not $disableAuth) -}}

      {{- $notificationGroups := ($foia.notificationGroups | default list) -}}
      {{- if $notificationGroups -}}
        {{- if (kindIs "map" $notificationGroups) -}}
          {{- $notificationGroups = (keys $notificationGroups) -}}
        {{- else if (not (kindIs "slice" $notificationGroups)) -}}
          {{- $notificationGroups = ($notificationGroups | toString | splitList ",") -}}
        {{- end -}}
        {{- $notificationGroups = ($notificationGroups | compact | sortAlpha | uniq) -}}
      {{- else -}}
        {{- $notificationGroups = list -}}
      {{- end -}}

      {{- /* default values */ -}}
      {{-
        $result = dict
          "apiSecret" $apiSecret
          "disableAuth" $disableAuth
          "generateUsers" $generateUsers
          "portalId" $portalId
          "ldap" (
            dict
              "server" $ldapServer
              "groupPrefix" $ldapGroupPrefix
              "domain" $ldapDomain
            )
          "notificationGroups" $notificationGroups
          "springProfile" "FOIA_server"
      -}}
    {{- end -}}
    {{- $result | toYaml -}}
  {{- end -}}
{{- end -}}
