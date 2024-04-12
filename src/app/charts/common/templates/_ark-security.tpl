{{- define "arkcase.serviceAccountName" -}}
  {{- $global := (include "arkcase.tools.get" (dict "ctx" $ "name" "Values.global.security.serviceAccountName") | fromYaml) -}}
  {{- if and $global $global.value -}}
    {{- $global.value -}}
  {{- else -}}
    {{- include "common.serviceAccountName" . -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.securityContext" -}}
  {{- $ctx := . -}}
  {{- $container := "" -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- $ctx = .ctx -}}
    {{- if not (include "arkcase.isRootContext" $ctx) -}}
      {{- fail "Must send the root context as either the only parameter, or the 'ctx' parameter" -}}
    {{- end -}}
    {{- $container = .container -}}
    {{- if or (not $container) (not (kindIs "string" $container)) -}}
      {{- fail "The container name must be a non-empty string" -}}
    {{- end -}}
  {{- end -}}
  {{- $part := (include "arkcase.part.name" $) -}}

  {{- $result := dict -}}

  {{- $securityContext := $ctx.Values.securityContext | default dict -}}
  {{- if not (kindIs "map" $securityContext) -}}
    {{- $securityContext = dict -}}
  {{- end -}}

  {{- if and $part (hasKey $securityContext $part) -}}
    {{- $securityContext = get $securityContext $part -}}
    {{- if or (not $securityContext) (not (kindIs "map" $securityContext)) -}}
      {{- $securityContext = dict -}}
    {{- end -}}
  {{- end -}}

  {{- if $container -}}
    {{- /* If a container name was given, this must be for a container */ -}}
    {{- if (hasKey $securityContext $container) -}}
      {{- $securityContext = get $securityContext $container -}}
      {{- if or (not $securityContext) (not (kindIs "map" $securityContext)) -}}
        {{- $securityContext = dict -}}
      {{- end -}}
      {{-
        $result = pick $securityContext
          "allowPrivilegeEscalation"
          "capabilities"
          "privileged"
          "procMount"
          "readOnlyRootFilesystem"
          "runAsGroup"
          "runAsNonRoot"
          "runAsUser"
          "seLinuxOptions"
          "seccompProfile"
          "windowsOptions"
      -}}
    {{- end -}}

    {{- /* Only apply the patched development IDs if and only if it's a container and we've been asked to do so */ -}}
    {{- if (include "arkcase.toBoolean" $securityContext.useDevId) -}}
      {{- $dev := (include "arkcase.dev" $ctx | fromYaml) -}}
      {{- if $dev -}}
        {{- if (hasKey $dev "uid") -}}
          {{- $uid := get $dev "uid" -}}
          {{- if (regexMatch "^(0|[1-9][0-9]*)$" ($uid | toString)) -}}
            {{- $result = set $result "runAsUser" ($uid | toString | atoi) -}}
          {{- end -}}
        {{- end -}}
        {{- if (hasKey $dev "gid") -}}
          {{- $gid := get $dev "gid" -}}
          {{- if (regexMatch "^(0|[1-9][0-9]*)$" ($gid | toString)) -}}
            {{- $result = set $result "runAsGroup" ($gid | toString | atoi) -}}
          {{- end -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
  {{- else -}}
    {{- /* If a container name wasn't given, this must be for a pod */ -}}
    {{-
      $result = pick $securityContext
        "fsGroup"
        "fsGroupChangePolicy"
        "runAsGroup"
        "runAsNonRoot"
        "runAsUser"
        "seLinuxOptions"
        "seccompProfile"
        "supplementalGroups"
        "sysctls"
        "windowsOptions"
    -}}
  {{- end -}}


  {{- $result | toYaml -}}
{{- end -}}
