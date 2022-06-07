{{/*
Verify that the persistence configuration is good
*/}}
{{- define "common.persistence.validateVolumeConfig" -}}
  {{- $name := .name -}}
  {{- with .vol -}}
    {{- $hasClaimSpec := false -}}
    {{- $hasClaimName := false -}}
    {{- $hasVolumeSpec := false -}}
    {{- if (.claim) -}}
      {{- if .claim.spec -}}
        {{- $hasClaimSpec = (lt 0 (len (.claim).spec)) -}}
      {{- end -}}
      {{- if .claim.name -}}
        {{- $hasClaimName = true -}}
      {{- end -}}
      {{- if and $hasClaimName $hasClaimSpec -}}
         {{- $message := printf "The persistence definition for [%s] has both claim.name and claim.spec, choose only one" $name -}}
         {{- fail $message -}}
      {{- end -}}
    {{- end -}}
    {{- if (.volume) -}}
      {{- $hasVolumeSpec = (lt 0 (len (.volume))) -}}
    {{- end -}}
    {{- if and (or $hasClaimSpec $hasClaimName) $hasVolumeSpec -}}
       {{- $message := printf "The persistence definition for [%s] has both a claim definition and volume specifictions, choose only one" $name -}}
       {{- fail $message -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{/*
Check if persistence is enabled, assuming a missing setting defaults to true
*/}}
{{- define "common.persistence.isEnabled" -}}
{{- if (and (or ((.Values.global).persistence).enabled (not (hasKey ((.Values.global).persistence | default dict) "enabled"))) (or (.Values.persistence).enabled (not (hasKey (.Values.persistence | default dict) "enabled")))) }}
{{- true -}}
{{- else -}}
{{- end -}}
{{- end -}}
