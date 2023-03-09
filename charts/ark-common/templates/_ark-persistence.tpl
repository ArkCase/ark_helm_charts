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
    {{- if (.spec) -}}
      {{- $hasVolumeSpec = (lt 0 (len (.spec))) -}}
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
  {{- $localEnabled := true -}}
  {{- if $localSet -}}
    {{- $localEnabled = (eq "true" (include "arkcase.tools.get" (dict "ctx" $ "name" ".Values.persistence.enabled") | lower)) -}}
  {{- end -}}
  {{- /* Now check to see what the global flag says (defaults to true if not set) */ -}}
  {{- $globalSet := (include "arkcase.tools.check" (dict "ctx" $ "name" ".Values.global.persistence.enabled")) -}}
  {{- $globalEnabled := true -}}
  {{- if $globalSet -}}
    {{- $globalEnabled = (eq "true" (include "arkcase.tools.get" (dict "ctx" $ "name" ".Values.global.persistence.enabled") | lower)) -}}
  {{- end -}}
  {{- /* Persistence is only enabled if the local and global flags agree that it should be */ -}}
  {{- if (and $localEnabled $globalEnabled) -}}
    {{- true -}}
  {{- end -}}
{{- end -}}

{{- /*
Render a volumes: entry for a given volume, as per the persistence model
*/ -}}
{{- define "arkcase.persistence.volume" -}}
  {{- $volumeName := .name -}}
- name: {{ $volumeName | quote }}
  {{- if (include "arkcase.persistence.enabled" .ctx) -}}
    {{- $claimName := (printf "%s-%s" (include "arkcase.fullname" .ctx) $volumeName ) -}}
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

{{- /*
Render the PersistentVolume and PersistentVolumeClaim objects for a given volume, per configurations
*/ -}}
{{- define "arkcase.persistence.declareObjects" -}}
  {{- $ctx := .ctx -}}
  {{- if not $ctx -}}
    {{- fail "Must provide the 'ctx' context to find the configuration data" -}}
  {{- end -}}
  {{- $volumeName := .name -}}
  {{- if not $volumeName -}}
    {{- fail "Must provide the 'name' of the volume objects to declare" -}}
  {{- end -}}

  {{- if (include "arkcase.persistence.enabled" $ctx) -}}

    {{- $objectName := (printf "%s-%s" (include "arkcase.fullname" $ctx) $volumeName) -}}
    {{- $volumeObjectName := (printf "%s-%s" $ctx.Release.Namespace $objectName) -}}
    {{- $volumeData := dict -}}
    {{- if (include "arkcase.tools.check" (dict "ctx" $ctx "name" (printf ".Values.persistence.%s" $volumeName))) -}}
      {{- $volumeData = (include "arkcase.tools.get" (dict "ctx" $ctx "name" (printf ".Values.persistence.%s" $volumeName)) | fromYaml) -}}
    {{- end -}}
    {{- include "arkcase.persistence.validateVolumeConfig" ( dict "vol" $volumeData "ctx" $ctx "name" $volumeName ) -}}

    {{- $globalDefaults := (include "arkcase.tools.get" (dict "ctx" $ctx "name" ".Values.global.persistence.defaults") | fromYaml | default dict) -}}
    {{- $localDefaults := (include "arkcase.tools.get" (dict "ctx" $ctx "name" ".Values.persistence.defaults") | fromYaml | default dict) -}}

    {{- /* Overlay localDefaults on top of globalDefaults */ -}}
    {{- $defaults := mergeOverwrite $globalDefaults $localDefaults -}}
    {{- $defaultSize := (include "arkcase.tools.get" (dict "ctx" $defaults "name" "size") | default "1Gi") -}}
    {{- $defaultReclaimPolicy := (include "arkcase.tools.get" (dict "ctx" $defaults "name" "persistentVolumeReclaimPolicy") | default "Retain") -}}
    {{- $defaultStorageClassName := (include "arkcase.tools.get" (dict "ctx" $defaults "name" "storageClassName") | default "manual") -}}
    {{- $defaultAccessModes := (include "arkcase.tools.get" (dict "ctx" $defaults "name" "accessModes")) -}}
    {{- if not $defaultAccessModes -}}
      {{- $defaultAccessModes = (list "ReadWriteOnce") -}}
    {{- end -}}

    {{- $claimName := (default "" ($volumeData.claim).name) -}}
    {{- $claimSpec := (default dict ($volumeData.claim).spec) -}}
    {{- $volumeSpec := (default dict $volumeData.spec) -}}

    {{- $storageClassName := $defaultStorageClassName -}}
    {{- $accessModes := $defaultAccessModes -}}
    {{- $storageSize := $defaultSize -}}

    {{- if not $claimName -}}
    {{- if not $claimSpec -}}
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: {{ $volumeObjectName | quote }}
  namespace: {{ $ctx.Release.Namespace | quote }}
  labels: {{- include "common.labels" $ctx | nindent 4 }}
    {{- with $ctx.Values.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
    {{- with $volumeData.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
    arkcase/persistentVolume: {{ $volumeObjectName | quote }}
  annotations:
    {{- with $ctx.Values.annotations  }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
    {{- with $volumeData.annotations  }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
{{- if ($volumeSpec) }}
  {{- if $volumeSpec.accessModes -}}
    {{- $accessModes = $volumeSpec.accessModes -}}
  {{- end -}}
  {{- if ($volumeSpec.capacity).storage -}}
    {{- $storageSize = $volumeSpec.capacity.storage -}}
  {{- end -}}
  {{- if $volumeSpec.storageClassName -}}
    {{- $storageClassName = $volumeSpec.storageClassName -}}
  {{- end -}}
  {{- toYaml $volumeSpec | nindent 2 -}}
{{- else }}
  {{- /* Use "local-storage" when we've figured out the folder creation thing */ -}}
  {{- $storageClassName = "manual" }}
  storageClassName: {{ $storageClassName | quote }}
  persistentVolumeReclaimPolicy: {{ $defaultReclaimPolicy | quote }}
  accessModes: {{- toYaml $accessModes | nindent 4 }}
  capacity:
    storage: {{ $storageSize | quote }}
  {{- if (eq "local-storage" $storageClassName) }}
  # Use "local:" when using "local-storage" as the storage class
  local:
  {{- else }}
  # Use "hostPath:" when using "manual" as the storage class
  hostPath:
  {{- end }}
    {{- $localPath := $volumeData.localPath -}}
    {{- if not $localPath -}}
      {{- $localPath = coalesce ($ctx.Values.persistence).localPath (($ctx.Values.global).persistence).localPath "/opt/app/arkcase" -}}
      {{- $localPath = (printf "%s/%s/%s" $localPath (include "arkcase.subsystem.name" $ctx) $volumeName) -}}
    {{- end }}
    path: {{ $localPath | quote }}
    type: DirectoryOrCreate
  {{- if (eq "local-storage" $storageClassName) }}
  # Node affinity is required when using "local-storage" as the storage class
  nodeAffinity:
    # TODO: Could eventually match kubernetes.io/hostname=$(hostname) ... must use kustomize or somesuch
    # TODO: This should probably be revised ... should work for now
    required:
      nodeSelectorTerms:
        - matchExpressions:
            - key: kubernetes.io/os
              operator: In
              values:
                - linux
  {{- end }}
  claimRef:
    apiVersion: v1
    kind: PersistentVolumeClaim
    name: {{ $objectName | quote }}
    namespace: {{ $ctx.Release.Namespace | quote }}
{{- end }}

    {{- end }}

---
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: {{ $objectName | quote }}
  namespace: {{ $ctx.Release.Namespace | quote }}
  labels: {{- include "common.labels" $ctx | nindent 4 }}
    {{- with $ctx.Values.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
    {{- with $volumeData.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
    arkcase/persistentVolumeClaim: {{ $objectName | quote }}
  annotations:
    {{- with $ctx.Values.annotations  }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
    {{- with $volumeData.annotations  }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
{{- if ($claimSpec) -}}
  {{- $claimSpec | toYaml | nindent 2 }}
{{- else }}
  volumeName: {{ $volumeObjectName | quote }}
  selector:
    matchLabels:
      arkcase/persistentVolume: {{ $volumeObjectName | quote }}
  storageClassName: {{ $storageClassName | quote }}
  accessModes: {{- toYaml $accessModes | nindent 4 }}
  resources:
    requests:
      storage: {{ $storageSize | quote }}
{{- end }}
    {{- end -}}

  {{- end -}}

{{- end -}}
