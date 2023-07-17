{{- define "arkcase.foia" -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $) -}}
    {{- fail "The single parameter must be the root context ($ or .)" -}}
  {{- end -}}

  {{- /* TODO: Only proceed if we're in enterprise mode */ -}}
  {{- $enterprise := true -}}

  {{- if $enterprise -}}
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
          "notificationGroups" $notificationGroups
          "disableAuth" $disableAuth
          "generateUsers" $generateUsers
          "springProfile" "FOIA_server"
          "ldap" (
            dict
              "server" $ldapServer
              "groupPrefix" $ldapGroupPrefix
              "domain" $ldapDomain
            )
      -}}
    {{- end -}}
    {{- $result | toYaml -}}
  {{- end -}}
{{- end -}}
