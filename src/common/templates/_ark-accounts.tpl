{{- define "__arkcase.accounts.secret.name" -}}
  {{- $ctx := $.ctx -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The 'ctx' parameter must be the root context ($)" -}}
  {{- end -}}

  {{- $type := $.type -}}
  {{- if (not (include "arkcase.tools.hostnamePart" (toString $type))) -}}
    {{- fail (printf "The secret type [%s] is not a valid RFC-1123 hostname" $type) -}}
  {{- end -}}

  {{- (printf "%s-accounts-%s" $ctx.Release.Name $type) -}}
{{- end -}}

{{- define "__arkcase.accounts.findcreds" -}}
  {{- $ctx := $.ctx -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The 'ctx' parameter must be the root context ($)" -}}
  {{- end -}}

  {{- $type := $.type -}}
  {{- if or (not $type) (not (kindIs "string" $type)) -}}
    {{- fail (printf "The account type must be a non-empty string [%s]" $type) -}}
  {{- end -}}

  {{- $account := $.account -}}
  {{- if or (not $account) (not (kindIs "string" $account)) -}}
    {{- fail (printf "The account name must be a non-empty string [%s]" $account) -}}
  {{- end -}}

  {{- /* TODO: seek out credentials from configurations to re-use here */ -}}
  {{- /* TODO: use $type and $account to identify where to look for the credentials to be re-used here */ -}}
  {{- /* TODO: Perhaps use a "hardcoded" (no better choice available, really) map that describes the search locations? */ -}}
  {{- /* $password := (randAlphaNum 64) */ -}}

  {{- /*
      So ... we have some problems to resolve. The caches aren't shared among
      all charts, so we can't just render values that will be reused. I'll have
      to figure that one out ... an operator may be our only reliable solution.

      That said, we can create a bit of a "predictable algorithm" that will help
      us render hard-to-guess, quasi-random passwords by using information that can
      be expected to be stable during the deployment, but is not likely to be
      repeated in the future and thus not likely to produce a guessable password.

      We generate a password using the account $type, the name ($account), and
      the SHA256 hashes for the YAML representations of the $.Values.Release and
      $.Values.Capabilities maps, and the last 10 minute boundary
  */ -}}
  {{- $hashRelease := ($ctx.Release | toYaml | sha256sum) -}}
  {{- $hashCapabilities := ($ctx.Capabilities | toYaml | sha256sum) -}}
  {{- $timeBoundary := "12345" -}}
  {{- $password := (printf "%s|%s|%s|%s|%d" $type $account $hashRelease $hashCapabilities $timeBoundary | sha256sum | lower) -}}

  {{- dict "username" $account "password" $password | toYaml -}}
{{- end -}}

{{- define "__arkcase.accounts.render" -}}
  {{- $ctx := $.ctx -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The 'ctx' parameter must be the root context ($)" -}}
  {{- end -}}

  {{- $type := $.type -}}
  {{- if or (not $type) (not (kindIs "string" $type)) -}}
    {{- fail "The secret type must be a non-empty string" -}}
  {{- end -}}

  {{- $accounts := dict -}}

  {{- /* If we have account names, use them ... else, return an empty map */ -}}
  {{- $names := ($.names | default list) -}}
  {{- with $names -}}

    {{- /* Sanity check */ -}}
    {{- if (not (kindIs "slice" $names)) -}}
      {{- fail "The account names must be a list" -}}
    {{- end -}}

    {{- $secretName := (include "__arkcase.accounts.secret.name" (pick $ "ctx" "type")) -}}
    {{- $namespace := $ctx.Release.Namespace -}}

    {{- $secretObj := (lookup "v1" "Secret" $namespace $secretName | default dict) -}}
    {{- $secretData := (get $secretObj "data") | default dict -}}

    {{- /* First, make sure we copy all the data */ -}}
    {{- $accounts = deepCopy $secretData -}}

    {{- /* Find each of the shared accounts in the existing secret data. If there, reuse */ -}}
    {{- range $account := $names -}}
      {{- $value := dict -}}
      {{- if (hasKey $secretData $account) -}}
        {{- /* Re-use the old auth info */ -}}
        {{- $value = (get $secretData $account | b64dec) -}}
      {{- else -}}
        {{- /* Render a new auth info */ -}}
        {{- $value = (include "__arkcase.accounts.findcreds" (dict "ctx" $ctx "type" $type "account" $account)) -}}
      {{- end -}}
      {{- $accounts = set $accounts $account ($value | fromYaml) -}}
    {{- end -}}
  {{- end -}}
  {{- $accounts | toYaml -}}
{{- end -}}

{{- define "__arkcase.accounts" -}}
  {{- $ctx := $.ctx -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The 'ctx' parameter must be the root context (. or $)" -}}
  {{- end -}}

  {{- $type := $.type -}}
  {{- if or (not $type) (not (kindIs "string" $type)) -}}
    {{- fail "The secret type must be a non-empty string" -}}
  {{- end -}}

  {{- $cacheKey := "ArkCase-CommonAccounts" -}}
  {{- $masterCache := dict -}}
  {{- if (hasKey $ctx $cacheKey) -}}
    {{- $masterCache = get $ctx $cacheKey -}}
    {{- if and $masterCache (not (kindIs "map" $masterCache)) -}}
      {{- $masterCache = dict -}}
    {{- end -}}
  {{- end -}}
  {{- $ctx = set $ctx $cacheKey $masterCache -}}

  {{- $masterKey := $type -}}
  {{- $yamlResult := dict -}}
  {{- if not (hasKey $masterCache $masterKey) -}}
    {{- $yamlResult = (include "__arkcase.accounts.render" $) -}}
    {{- $masterCache = set $masterCache $masterKey ($yamlResult | fromYaml) -}}
  {{- else -}}
    {{- $yamlResult = get $masterCache $masterKey | toYaml -}}
  {{- end -}}
  {{- $yamlResult -}}
{{- end -}}

{{- define "__arkcase.accounts.get" -}}
  {{- $ctx := $.ctx -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The 'ctx' parameter given must be the root context (. or $)" -}}
  {{- end -}}

  {{- $name := $.name -}}
  {{- if or (not $name) (not (kindIs "string" $name)) -}}
    {{- fail (printf "The name parameter must be a non-empty string: (%s) [%s]" (kindOf $name) $name) -}}
  {{- end -}}

  {{- $type := $.type -}}
  {{- if or (not $type) (not (kindIs "string" $type)) -}}
    {{- fail "The account type must be a non-empty string" -}}
  {{- end -}}

  {{- $accounts := (include (printf "arkcase.accounts.%s" $type) $ctx | fromYaml) -}}
  {{- if (hasKey $accounts $name) -}}
    {{- get $accounts $name | toYaml -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.accounts.shared" -}}
  {{- /* TODO: Should this be configurable... *somewhere*? */ -}}
  {{-
    $names := (
      list
        "ldap-client"
        "ldap-admin"
        "arkcase-content"
        "arkcase-messaging"
        "arkcase-reports"
        "arkcase-search"
    )
  -}}

  {{-
    $params :=
      dict
        "ctx" $
        "type" "shared"
        "names" $names
  -}}
  {{- include "__arkcase.accounts" $params -}}
{{- end -}}

{{- define "arkcase.accounts.shared.get" -}}
  {{- $ctx := $.ctx -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The 'ctx' parameter given must be the root context (. or $)" -}}
  {{- end -}}

  {{- $name := $.name -}}
  {{- if or (not $name) (not (kindIs "string" $name)) -}}
    {{- fail (printf "The name parameter must be a non-empty string: (%s) [%s]" (kindOf $name) $name) -}}
  {{- end -}}

  {{- include "__arkcase.accounts.get" (merge (dict "type" "shared") (pick $ "ctx" "name")) -}}
{{- end -}}

{{- define "arkcase.accounts.admin" -}}
  {{- /* TODO: Should this be configurable... *somewhere*? */ -}}
  {{-
    $names := (
      list
        "administrator"
        "admin-content"
        "admin-messaging"
        "admin-reports"
        "admin-search"
    )
  -}}

  {{-
    $params :=
      dict
        "ctx" $
        "type" "admin"
        "names" $names
  -}}
  {{- include "__arkcase.accounts" $params -}}
{{- end -}}

{{- define "arkcase.accounts.admin.get" -}}
  {{- $ctx := $.ctx -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The 'ctx' parameter given must be the root context (. or $)" -}}
  {{- end -}}

  {{- $name := $.name -}}
  {{- if or (not $name) (not (kindIs "string" $name)) -}}
    {{- fail (printf "The name parameter must be a non-empty string: (%s) [%s]" (kindOf $name) $name) -}}
  {{- end -}}

  {{- include "__arkcase.accounts.get" (merge (dict "type" "admin") (pick $ "ctx" "name")) -}}
{{- end -}}

{{- define "arkcase.accounts.rdbms" -}}
  {{- /* TODO: Should this be configurable... *somewhere*? */ -}}
  {{-
    $names := (
      list
        "arkcase-db"
        "arkcase-config"
        "pentaho-db"
        "pentaho-jcr"
        "pentaho-quartz"
    )
  -}}

  {{-
    $params :=
      dict
        "ctx" $
        "type" "rdbms"
        "names" $names
  -}}
  {{- include "__arkcase.accounts" $params -}}
{{- end -}}

{{- define "arkcase.accounts.rdbms.get" -}}
  {{- $ctx := $.ctx -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The 'ctx' parameter given must be the root context (. or $)" -}}
  {{- end -}}

  {{- $name := $.name -}}
  {{- if or (not $name) (not (kindIs "string" $name)) -}}
    {{- fail (printf "The name parameter must be a non-empty string: (%s) [%s]" (kindOf $name) $name) -}}
  {{- end -}}

  {{- include "__arkcase.accounts.get" (merge (dict "type" "admin") (pick $ "ctx" "name")) -}}
{{- end -}}


{{- define "__arkcase.accounts.secret.render" -}}
  {{- $ctx := $.ctx -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The 'ctx' parameter must be the root context ($)" -}}
  {{- end -}}

  {{- $type := $.type -}}
  {{- if or (not $type) (not (kindIs "string" $type)) -}}
    {{- fail "The secret type must be a non-empty string" -}}
  {{- end -}}

  {{- $keep := (not (empty (include "arkcase.toBoolean" ($.keep | default false)))) -}}

  {{- $accounts := $.accounts -}}
  {{- if or (not $accounts) (not (kindIs "map" $accounts)) -}}
    {{- $accounts = dict -}}
  {{- end -}}

  {{- $secretName := (include "__arkcase.accounts.secret.name" (pick $ "ctx" "type")) -}}
  {{- $namespace := $ctx.Release.Namespace -}}

  {{- $finalAccounts := dict -}}
  {{- range $account := (keys $accounts | sortAlpha) -}}
    {{- $finalAccounts = set $finalAccounts $account (get $accounts $account | toYaml) -}}
  {{- end -}}

---
apiVersion: v1
kind: Secret
metadata:
  name: {{ $secretName | quote }}
  namespace: {{ $namespace | quote }}
  labels: {{- include "arkcase.labels" $ctx | nindent 4 }}
  {{- if $keep }}
  annotations:
    helm.sh/resource-policy: "keep"
  {{- end }}
stringData: {{- $finalAccounts | toYaml | nindent 2 }}
{{- end -}}

{{- /* Render ONE secret, per the gien parameters, ONCE */ -}}
{{- define "__arkcase.accounts.secret" -}}
  {{- $ctx := $.ctx -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The 'ctx' parameter must be the root context (. or $)" -}}
  {{- end -}}

  {{- $type := $.type -}}
  {{- if or (not $type) (not (kindIs "string" $type)) -}}
    {{- fail "The secret type must be a non-empty string" -}}
  {{- end -}}

  {{- $keep := (not (empty (include "arkcase.toBoolean" ($.keep | default false)))) -}}

  {{- $cacheKey := "ArkCase-CommonAccountsSecrets" -}}
  {{- $masterCache := dict -}}
  {{- if (hasKey $ctx $cacheKey) -}}
    {{- $masterCache = get $ctx $cacheKey -}}
    {{- if and $masterCache (not (kindIs "map" $masterCache)) -}}
      {{- $masterCache = dict -}}
    {{- end -}}
  {{- end -}}
  {{- $ctx = set $ctx $cacheKey $masterCache -}}

  {{- $masterKey := $type -}}
  {{- if not (hasKey $masterCache $masterKey) -}}
    {{-
      $params :=
        dict
          "ctx" $ctx
          "type" $type
          "accounts" (include (printf "arkcase.accounts.%s" $type) $ctx | fromYaml)
          "keep" $keep
    -}}
    {{- include "__arkcase.accounts.secret.render" $params -}}
    {{- $masterCache = set $masterCache $masterKey (omit $params "ctx") -}}
  {{- end -}}
{{- end -}}

{{- /* Render the secrets (should only be rendered ONCE) */ -}}
{{- define "arkcase.accounts.secrets" -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The parameter must be the root context ($)" -}}
  {{- end -}}

  {{-
    $secrets :=
      dict
        "admin" true
        "rdbms" false
        "shared" false
  -}}

  {{- $params := dict "ctx" $ctx -}}
  {{- range $type := (keys $secrets | sortAlpha) }}
    {{- include "__arkcase.accounts.secret" (merge (dict "type" $type "keep" (get $secrets $type)) $params) | nindent 0 }}
  {{- end }}
{{- end -}}

{{- define "arkcase.accounts.volumeMount" -}}
  {{- $ctx := $.ctx -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The 'ctx' parameter given must be the root context (. or $)" -}}
  {{- end -}}

  {{- $type := $.type -}}
  {{- if or (not $type) (not (kindIs "string" $type)) -}}
    {{- fail (printf "The type parameter must be a non-empty string: (%s) [%s]" (kindOf $type) $type) -}}
  {{- end -}}

  {{- $anchor := (printf "&%sAccounts" $type) -}}
- name: {{ $anchor }} {{ include "__arkcase.accounts.secret.name" (dict "ctx" $ctx "type" $type) | quote }}
  mountPath: {{ printf "/.accounts/%s" $type }}
  readOnly: true
{{- end -}}

{{- define "arkcase.accounts.volume" -}}
  {{- $ctx := $.ctx -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The 'ctx' parameter given must be the root context (. or $)" -}}
  {{- end -}}

  {{- $type := $.type -}}
  {{- if or (not $type) (not (kindIs "string" $type)) -}}
    {{- fail (printf "The type parameter must be a non-empty string: (%s) [%s]" (kindOf $type) $type) -}}
  {{- end -}}

  {{- $anchor := (printf "*%sAccounts" $type) -}}
- name: {{ $anchor }}
  secret:
    optional: true
    secretName: {{ $anchor }}
    defaultMode: 0444
{{- end -}}
