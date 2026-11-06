{{- /*
The label that marks every resource this release renders, so we can tell
our own StatefulSets and Pods apart from the ones that belong to others
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
    - name: the StatefulSet's name
      replicas: how many pods (one per source PVC)
      family: true if the PVCs are mounted via volumeClaimTemplates
      sourceTemplate: (family only) the volumeClaimTemplate name for the source PVCs
      sourcePrefix: (family only) the source PVCs' name, minus the "-${ordinal}" suffix
      sourceSpec: (family only) the spec for the source volumeClaimTemplate
      targetSpec: (family + clone only) the spec for the target volumeClaimTemplate
      claim: (single only) the source PVC's name
  clones:
    - the new PVCs to create (clone mode only)

PVCs named ${something}-${ordinal}, with ordinals 0..N-1 (N > 1), most likely
came from a StatefulSet's volumeClaimTemplates. A StatefulSet's PVCs are named
${template}-${statefulSet}-${ordinal}, so if we split ${something} into
${template}-${statefulSet} at one of its dashes, a StatefulSet of our own with
N replicas, named ${statefulSet}, with a volumeClaimTemplate named ${template},
will mount each of those PVCs on its matching pod. The target PVCs, named
${clonePrefix}-${something}-${ordinal}, then match the volumeClaimTemplate
${clonePrefix}-${template} in that same StatefulSet.

The split is chosen such that the StatefulSet's name (and its pods' names) don't
collide with anything else that exists in the namespace, or that this release
renders. If no viable split exists, each PVC is handled by its own StatefulSet.
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

  {{- /* Volume names our pods already use, which the volumeClaimTemplates may not reuse */ -}}
  {{- $reservedVolumes := (list "pvc-tool-logs" "pvc-tool-scripts" "source" "target") -}}

  {{- /* StatefulSets and pods that exist in the namespace, but aren't ours */ -}}
  {{- $foreign := dict -}}
  {{- range $obj := (dig "items" list (lookup "apps/v1" "StatefulSet" $namespace "")) -}}
    {{- if ne (dig "metadata" "labels" $markerLabel "" $obj) $release -}}
      {{- $foreign = set $foreign (printf "sts/%s" $obj.metadata.name) true -}}
    {{- end -}}
  {{- end -}}
  {{- range $obj := (dig "items" list (lookup "v1" "Pod" $namespace "")) -}}
    {{- if ne (dig "metadata" "labels" $markerLabel "" $obj) $release -}}
      {{- $foreign = set $foreign (printf "pod/%s" $obj.metadata.name) true -}}
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

  {{- /* Group the PVCs into families by their ordinal suffix */ -}}
  {{- $families := dict -}}
  {{- $singles := list -}}
  {{- range $name := (keys $sources | sortAlpha) -}}
    {{- if (regexMatch "^.+-(0|[1-9][0-9]*)$" $name) -}}
      {{- $prefix := (regexReplaceAll "-[0-9]+$" $name "") -}}
      {{- $members := (get $families $prefix | default dict) -}}
      {{- $members = set $members (regexFind "[0-9]+$" $name) $name -}}
      {{- $families = set $families $prefix $members -}}
    {{- else -}}
      {{- $singles = append $singles $name -}}
    {{- end -}}
  {{- end -}}

  {{- $used := dict -}}
  {{- $tasks := list -}}
  {{- range $prefix := (keys $families | sortAlpha) -}}
    {{- $members := (get $families $prefix) -}}
    {{- $replicas := (len $members) -}}

    {{- /* The ordinals must be exactly 0..N-1, or the StatefulSet would create the missing PVCs */ -}}
    {{- $contiguous := true -}}
    {{- range $i := (until $replicas) -}}
      {{- if not (hasKey $members (toString $i)) -}}
        {{- $contiguous = false -}}
      {{- end -}}
    {{- end -}}

    {{- $task := dict -}}
    {{- if and $contiguous (gt $replicas 1) -}}
      {{- $parts := (splitList "-" $prefix) -}}
      {{- /* Longest StatefulSet name first: most likely to match the original */ -}}
      {{- range $i := (untilStep 1 (len $parts) 1) -}}
        {{- $template := (slice $parts 0 $i | join "-") -}}
        {{- $sts := (slice $parts $i | join "-") -}}
        {{- $targetTemplate := (printf "%s-%s" $clonePrefix $template) -}}

        {{- /* StatefulSet names must leave room for the controller-revision-hash label */ -}}
        {{- if or (not (regexMatch $labelRE $sts)) (gt (len $sts) 52) -}}
          {{- continue -}}
        {{- end -}}
        {{- if or (not (regexMatch $labelRE $template)) (gt (len $template) 63) (has $template $reservedVolumes) -}}
          {{- continue -}}
        {{- end -}}
        {{- if and $clone (or (gt (len $targetTemplate) 63) (has $targetTemplate $reservedVolumes)) -}}
          {{- continue -}}
        {{- end -}}
        {{- if or (hasKey $used $sts) (hasKey $foreign (printf "sts/%s" $sts)) -}}
          {{- continue -}}
        {{- end -}}
        {{- $podCollision := false -}}
        {{- range $o := (until $replicas) -}}
          {{- if (hasKey $foreign (printf "pod/%s-%d" $sts $o)) -}}
            {{- $podCollision = true -}}
          {{- end -}}
        {{- end -}}
        {{- if $podCollision -}}
          {{- continue -}}
        {{- end -}}

        {{- $first := (get $sources (get $members "0")) -}}
        {{- $sourceSpec := (pick $first.spec "accessModes" "resources" "storageClassName" "volumeMode") -}}
        {{-
          $task = dict
            "name" $sts
            "replicas" $replicas
            "family" true
            "sourceTemplate" $template
            "sourcePrefix" $prefix
            "sourceSpec" $sourceSpec
        -}}
        {{- if $clone -}}
          {{- $targetSpec := (pick $first.spec "accessModes" "volumeMode") -}}
          {{- $targetSpec = set $targetSpec "resources" (pick ($first.spec.resources | default dict) "requests") -}}
          {{- if $storageClassName -}}
            {{- $targetSpec = set $targetSpec "storageClassName" $storageClassName -}}
          {{- end -}}
          {{- $task = set $task "targetTemplate" $targetTemplate -}}
          {{- $task = set $task "targetSpec" $targetSpec -}}
        {{- end -}}
        {{- break -}}
      {{- end -}}
    {{- end -}}

    {{- if $task -}}
      {{- $used = set $used $task.name true -}}
      {{- $tasks = append $tasks $task -}}
    {{- else -}}
      {{- range $ordinal, $name := $members -}}
        {{- $singles = append $singles $name -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}

  {{- /* Everything else gets a StatefulSet of its own */ -}}
  {{- range $name := ($singles | sortAlpha) -}}
    {{- $base := (printf "%s-%s" $release $name | replace "." "-") -}}
    {{- $sts := $base -}}
    {{-
      $taken := or
        (gt (len $sts) 52)
        (not (regexMatch $labelRE $sts))
        (hasKey $used $sts)
        (hasKey $foreign (printf "sts/%s" $sts))
        (hasKey $foreign (printf "pod/%s-0" $sts))
    -}}
    {{- if $taken -}}
      {{- $sts = (printf "%s-%s" (regexReplaceAll "-+$" ($base | trunc 43) "") (sha256sum $name | trunc 8)) -}}
      {{- if or (hasKey $used $sts) (hasKey $foreign (printf "sts/%s" $sts)) (hasKey $foreign (printf "pod/%s-0" $sts)) -}}
        {{- fail (printf "Unable to find a free StatefulSet name for the PVC [%s] (tried [%s] and [%s])" $name $base $sts) -}}
      {{- end -}}
    {{- end -}}
    {{- $used = set $used $sts true -}}
    {{- $tasks = append $tasks (dict "name" $sts "replicas" 1 "family" false "claim" $name) -}}
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
