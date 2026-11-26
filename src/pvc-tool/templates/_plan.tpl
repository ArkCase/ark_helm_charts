{{- /*
The label that marks every resource this release renders, so we can tell
our own Jobs and Pods apart from the ones that belong to others
*/ -}}
{{- define "pvc-tool.markerLabel" -}}
armedia.com/pvc-mounter-name
{{- end -}}

{{- define "pvc-tool.taskLabel" -}}
armedia.com/pvc-tool-task
{{- end -}}

{{- define "pvc-tool.mode" -}}
  {{- $mode := (.Values.mode | default "rsync" | toString | lower) -}}
  {{- if not (has $mode (list "rsync" "clone" "s3")) -}}
    {{- fail (printf "Unsupported mode [%s] - must be one of: rsync, clone, s3" $mode) -}}
  {{- end -}}
  {{- $mode -}}
{{- end -}}

{{- define "pvc-tool.clonePrefix" -}}
  {{- $clonePrefixRE := "^[a-z0-9]([a-z0-9-]*[a-z0-9])?$" -}}
  {{- $clonePrefix := (.Values.clonePrefix | default "clone" | toString) -}}
  {{- if not (regexMatch $clonePrefixRE $clonePrefix) -}}
    {{- fail (printf "The clone prefix [%s] is not valid - must match the regular expression /%s/ (default: 'clone')" $clonePrefix $clonePrefixRE) -}}
  {{- end -}}
  {{- $clonePrefix -}}
{{- end -}}

{{- /*
Compute the work plan for the "clone" and "s3" modes. The output is a YAML map:

  tasks:
    - name: the Job's name
      claim: the PVC's name (the source, or the target when downloading from S3)
      target: (clone only) the new PVC's name
  clones:
    - the new PVCs to create (clone mode only)

Each PVC (or pair of old and new PVCs) gets a Job of its own, named
${release}-${pvcName}, which mounts it by name: nothing in it can create more
PVCs (as a StatefulSet's volumeClaimTemplates would, when scaled). Names that
are too long, or that collide with a Job that isn't ours, get a hash suffix
instead.
*/ -}}
{{- define "pvc-tool.plan" -}}
  {{- $ctx := . -}}
  {{- $release := $ctx.Release.Name -}}
  {{- $namespace := $ctx.Release.Namespace -}}
  {{- $mode := (include "pvc-tool.mode" $ctx) -}}
  {{- $clone := (eq $mode "clone") -}}
  {{- $clonePrefix := (include "pvc-tool.clonePrefix" $ctx) -}}
  {{- $markerLabel := (include "pvc-tool.markerLabel" $ctx) -}}
  {{- $storageClassName := ($ctx.Values.storageClassName | default "" | toString) -}}
  {{- $labelRE := "^[a-z0-9]([a-z0-9-]*[a-z0-9])?$" -}}

  {{- /* Jobs that exist in the namespace, but aren't ours */ -}}
  {{- $foreign := dict -}}
  {{- range $obj := (dig "items" list (lookup "batch/v1" "Job" $namespace "")) -}}
    {{- if ne (dig "metadata" "labels" $markerLabel "" $obj) $release -}}
      {{- $foreign = set $foreign $obj.metadata.name true -}}
    {{- end -}}
  {{- end -}}

  {{- /* Gather the PVCs we can work on */ -}}
  {{- $sources := dict -}}
  {{- range $pvc := (dig "items" list (lookup "v1" "PersistentVolumeClaim" $namespace "")) -}}
    {{- $name := $pvc.metadata.name -}}
    {{- if $pvc.metadata.deletionTimestamp -}}
      {{- continue -}}
    {{- end -}}
    {{- if ne ($pvc.spec.volumeMode | default "Filesystem") "Filesystem" -}}
      {{- /* Ignore non-filesystem PVCs... can't work on them yet */ -}}
      {{- continue -}}
    {{- end -}}
    {{- if and $clone (hasPrefix (printf "%s-" $clonePrefix) $name) -}}
      {{- /* This is a clone (ours, or from an earlier run), not a source */ -}}
      {{- continue -}}
    {{- end -}}
    {{- $sources = set $sources $name $pvc -}}
  {{- end -}}

  {{- /* One Job per PVC (or PVC pair), named after it */ -}}
  {{- $used := dict -}}
  {{- $tasks := list -}}
  {{- range $name := (keys $sources | sortAlpha) -}}
    {{- $base := (printf "%s-%s" $release $name | replace "." "-") -}}
    {{- $job := $base -}}
    {{- /* The name is also a label value, so it can't exceed 63 characters */ -}}
    {{- $taken := or (gt (len $job) 63) (not (regexMatch $labelRE $job)) (hasKey $used $job) (hasKey $foreign $job) -}}
    {{- if $taken -}}
      {{- $job = (printf "%s-%s" (regexReplaceAll "-+$" ($base | trunc 54) "") (sha256sum $name | trunc 8)) -}}
      {{- if or (hasKey $used $job) (hasKey $foreign $job) -}}
        {{- fail (printf "Unable to find a free Job name for the PVC [%s] (tried [%s] and [%s])" $name $base $job) -}}
      {{- end -}}
    {{- end -}}
    {{- $used = set $used $job true -}}
    {{- $task := (dict "name" $job "claim" $name) -}}
    {{- if $clone -}}
      {{- $task = set $task "target" (printf "%s-%s" $clonePrefix $name) -}}
    {{- end -}}
    {{- $tasks = append $tasks $task -}}
  {{- end -}}

  {{- /* The new PVCs (clone mode only) */ -}}
  {{- $clones := list -}}
  {{- if $clone -}}
    {{- range $name := (keys $sources | sortAlpha) -}}
      {{- $pvc := (get $sources $name) -}}

      {{- $annotations := dict -}}
      {{- range $k, $v := ($pvc.metadata.annotations | default dict) -}}
        {{- /* Drop the annotations that tie the PVC to its current volume or node */ -}}
        {{- if (regexMatch "^(pv[.]kubernetes[.]io|volume[.]kubernetes[.]io|volume[.]beta[.]kubernetes[.]io)/" $k) -}}
          {{- continue -}}
        {{- end -}}
        {{- if eq $k "kubectl.kubernetes.io/last-applied-configuration" -}}
          {{- continue -}}
        {{- end -}}
        {{- $annotations = set $annotations $k $v -}}
      {{- end -}}
      {{- $annotations = set $annotations "helm.sh/resource-policy" "keep" -}}

      {{- $labels := (deepCopy ($pvc.metadata.labels | default dict)) -}}
      {{- $labels = set $labels $markerLabel $release -}}

      {{- $spec := (pick $pvc.spec "accessModes" "volumeMode") -}}
      {{- $spec = set $spec "resources" (pick ($pvc.spec.resources | default dict) "requests") -}}
      {{- if $storageClassName -}}
        {{- $spec = set $spec "storageClassName" $storageClassName -}}
      {{- end -}}

      {{- $metadata := dict "name" (printf "%s-%s" $clonePrefix $name) "namespace" $namespace "labels" $labels "annotations" $annotations -}}
      {{- $clones = append $clones (dict "apiVersion" "v1" "kind" "PersistentVolumeClaim" "metadata" $metadata "spec" $spec) -}}
    {{- end -}}
  {{- end -}}

  {{- dict "tasks" $tasks "clones" $clones | toYaml -}}
{{- end -}}

{{- /*
The names of the PVCs the rsync mode exposes, as a YAML list
*/ -}}
{{- define "pvc-tool.rsyncPvcs" -}}
  {{- $names := list -}}
  {{- range $pvc := (dig "items" list (lookup "v1" "PersistentVolumeClaim" .Release.Namespace "")) -}}
    {{- if $pvc.metadata.deletionTimestamp -}}
      {{- continue -}}
    {{- end -}}
    {{- if ne ($pvc.spec.volumeMode | default "Filesystem") "Filesystem" -}}
      {{- continue -}}
    {{- end -}}
    {{- $names = append $names $pvc.metadata.name -}}
  {{- end -}}
  {{- $names | sortAlpha | toYaml -}}
{{- end -}}
