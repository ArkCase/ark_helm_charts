{{- /*
Verify that the persistence configuration is good
*/ -}}
{{- define "arkcase.persistence.validateVolumeConfig" -}}
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

{{- /*
Check if persistence is enabled, assuming a missing setting defaults to true
*/ -}}
{{- define "arkcase.persistence.enabled" -}}
  {{- /* First check to see what the local flag says (defaults to true if not set) */ -}}
  {{- $localSet := (include "arkcase.tools.check" (dict "ctx" $ "name" ".Values.persistence.enabled")) -}}
  {{- $localEnabled := (eq 1 1) -}}
  {{- if $localSet -}}
    {{- $localEnabled = (eq "true" (include "arkcase.tools.get" (dict "ctx" $ "name" ".Values.persistence.enabled") | lower)) -}}
  {{- end -}}
  {{- /* Now check to see what the global flag says (defaults to true if not set) */ -}}
  {{- $globalSet := (include "arkcase.tools.check" (dict "ctx" $ "name" ".Values.global.persistence.enabled")) -}}
  {{- $globalEnabled := (eq 1 1) -}}
  {{- if $globalSet -}}
    {{- $globalEnabled = (eq "true" (include "arkcase.tools.get" (dict "ctx" $ "name" ".Values.global.persistence.enabled") | lower)) -}}
  {{- end -}}
  {{- /* Persistence is only enabled if the local and global flags agree that it should be */ -}}
  {{- if (and $localEnabled $globalEnabled) -}}
    {{- true -}}
  {{- end -}}
{{- end -}}

{{- /*
Render a volumeMount entry for a given volume, as per the persistence model
*/ -}}
{{- define "arkcase.persistence.volumeMount" -}}
  {{- $volumeName := .name -}}
name: {{ $volumeName | quote }}
  {{- if (include "arkcase.persistence.enabled" .ctx) -}}
    {{- $claimName := (printf "%s-%s" (include "common.fullname" .ctx) $volumeName ) -}}
    {{- $explicitClaimName := (include "arkcase.tools.get" (dict "ctx" .ctx "name" (printf ".Values.persistence.%s.claim.name" $volumeName) )) -}}
    {{- if $explicitClaimName -}}
      {{- $claimName = $explicitClaimName -}}
    {{- end }}
  persistentVolumeClaim:
    claimName: {{ $claimName | quote }}
  {{- else }}
  emptyDir: {}
  {{- end }}
{{- end -}}
