{{- define "arkcase.persistence.getBaseSetting" -}}
  {{- $ctx := .ctx -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The 'ctx' parameter must be the root context (. or $)" -}}
  {{- end -}}
  {{- $name := .name -}}
  {{- if or (not $name) (not (kindIs "string" $name)) -}}
    {{- fail "The 'name' parameter must be the name of the setting to retrieve" -}}
  {{- end -}}

  {{- $result := dict -}}

  {{- $global :=(($ctx.Values.global).persistence | default dict) -}}
  {{- if (hasKey $global $name) -}}
    {{- $result = set $result "global" (get $global $name) -}}
  {{- end -}}

  {{- $local := ($ctx.Values.persistence | default dict) -}}
  {{- if (hasKey $local $name) -}}
    {{- $result = set $result "local" (get $local $name) -}}
  {{- end -}}

  {{- $result | toYaml -}}
{{- end -}}

{{- define "arkcase.persistence.getDefaultSetting" -}}
  {{- $ctx := .ctx -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The 'ctx' parameter must be the root context (. or $)" -}}
  {{- end -}}
  {{- $name := .name -}}
  {{- if or (not $name) (not (kindIs "string" $name)) -}}
    {{- fail "The 'name' parameter must be the name of the setting to retrieve" -}}
  {{- end -}}

  {{- $result := dict -}}

  {{- $global := (($ctx.Values.global).persistence | default dict) -}}
  {{- if not (kindIs "map" $global) -}}
    {{- $global = dict -}}
  {{- else -}}
    {{- $global = omit $global "volumes" -}}
  {{- end -}}
  {{- if (hasKey $global $name) -}}
    {{- $result = set $result "global" (get $global $name) -}}
  {{- end -}}

  {{- $local := ($ctx.Values.persistence | default dict) -}}
  {{- if not (kindIs "map" $local) -}}
    {{- $local = dict -}}
  {{- else -}}
    {{- $local = omit $local "volumes" -}}
  {{- end -}}
  {{- if (hasKey $local $name) -}}
    {{- $result = set $result "local" (get $local $name) -}}
  {{- end -}}

  {{- $result | toYaml -}}
{{- end -}}

{{- /* Check if persistence is enabled, assuming a missing setting defaults to true */ -}}
{{- define "arkcase.persistence.enabled" -}}
  {{- if not (include "arkcase.isRootContext" .) -}}
    {{- fail "The parameter must be the root context (. or $)" -}}
  {{- end -}}

  {{- $global := ((.Values.global).persistence | default dict) -}}
  {{- $globalSet := and (kindIs "map" $global) (hasKey $global "enabled") -}}
  {{- $global := and $globalSet (not (empty (include "arkcase.toBoolean" $global.enabled))) -}}

  {{- $local := (.Values.persistence | default dict) -}}
  {{- $localSet := and (kindIs "map" $local) (hasKey $local "enabled") -}}
  {{- $local := and $localSet (not (empty (include "arkcase.toBoolean" $local.enabled))) -}}

  {{- /* If global is set, use its value. Otherwise, use the local value. If none is given, assume true */ -}}
  {{- if $globalSet -}}
    {{- if $global -}}
      {{- true -}}
    {{- end -}}
  {{- else if $localSet -}}
    {{- if $local -}}
      {{- true -}}
    {{- end -}}
  {{- else -}}
    {{- true -}}
  {{- end -}}
{{- end -}}

{{- /* Get the mode of operation value that should be used for everything */ -}}
{{- define "arkcase.persistence.mode" -}}
  {{- if not (include "arkcase.isRootContext" .) -}}
    {{- fail "The parameter must be the root context (. or $)" -}}
  {{- end -}}
  {{- $mode := (include "arkcase.deployment.mode" . | fromYaml) -}}
  {{- if (include "arkcase.persistence.enabled" .) -}}
    {{- $storageClassName := (include "arkcase.persistence.getDefaultSetting" (dict "ctx" . "name" "storageClassName") | fromYaml) -}}
    {{- $storageClassName = (coalesce $storageClassName.global $storageClassName.local | default "" | lower) -}}
    {{- if $mode.set -}}
      {{- /* If the mode is explicitly set, then use it */ -}}
      {{- $mode = $mode.value -}}
    {{- else if $storageClassName -}}
      {{- /* If the mode is not explicitly set, but we have a storageClass, we default to production mode */ -}}
      {{- $mode = "production" -}}
    {{- else -}}
      {{- /* If the mode is not explicitly set, but we lack a storageClass, we default to development mode */ -}}
      {{- $mode = "development" -}}
    {{- end -}}
  {{- else if $mode.set -}}
    {{- /* If the mode is explicitly set, then use it */ -}}
    {{- $mode = $mode.value -}}
  {{- else -}}
    {{- /* No mode is explicitly set, and persistence is disabled, so we're in development mode */ -}}
    {{- $mode = "development" -}}
  {{- end -}}
  {{- $mode -}}
{{- end -}}

{{- /* Get the hostPathRoot value that should be used for everything */ -}}
{{- define "arkcase.persistence.hostPathRoot" -}}
  {{- if not (include "arkcase.isRootContext" .) -}}
    {{- fail "The parameter must be the root context (. or $)" -}}
  {{- end -}}
  {{- $hostPathRoot := (include "arkcase.persistence.getDefaultSetting" (dict "ctx" . "name" "hostPathRoot") | fromYaml) -}}
  {{- $local := (include "arkcase.tools.normalizePath" ($hostPathRoot.local | default "")) -}}
  {{- $global := (include "arkcase.tools.normalizePath" ($hostPathRoot.global | default "")) -}}
  {{- $finalRoot := coalesce $global $local "/opt/app" -}}
  {{- if not (isAbs $finalRoot) -}}
	{{- fail (printf "The hostPathRoot setting must be an absolute path (path = [%s], chart = %s, %s)" $finalRoot .Chart.Name $hostPathRoot) -}}
  {{- end -}}
  {{- $finalRoot -}}
{{- end -}}

{{- /* Get the storageClassName value that should be used for everything */ -}}
{{- define "arkcase.persistence.storageClassName" -}}
  {{- if not (include "arkcase.isRootContext" .) -}}
    {{- fail "The parameter must be the root context (. or $)" -}}
  {{- end -}}
  {{- $values := (include "arkcase.persistence.getDefaultSetting" (dict "ctx" . "name" "storageClassName") | fromYaml) -}}
  {{- $storageClassName := "" -}}
  {{- $storageClassSet := false -}}
  {{- if and (not $storageClassSet) (hasKey $values "global") -}}
    {{- $storageClassName = $values.global -}}
    {{- if and $storageClassName (not (regexMatch "^([a-z0-9][-a-z0-9]*)?[a-z0-9]$" ($storageClassName | lower))) -}}
      {{- fail (printf "The value global.persistence.storageClassName must be a valid storage class name: [%s]" $storageClassName) -}}
    {{- end -}}
    {{- $storageClassSet = true -}}
  {{- end -}}
  {{- if and (not $storageClassSet) (hasKey $values "local") -}}
    {{- $storageClassName = $values.local -}}
    {{- if and $storageClassName (not (regexMatch "^([a-z0-9][-a-z0-9]*)?[a-z0-9]$" ($storageClassName | lower))) -}}
      {{- fail (printf "The value persistence.storageClassName must be a valid storage class name: [%s]" $storageClassName) -}}
    {{- end -}}
    {{- $storageClassSet = true -}}
  {{- end -}}
  {{- /* Only output a value if one is set */ -}}
  {{- if $storageClassName -}}
    {{- $storageClassName -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.persistence.persistentVolumeReclaimPolicy" -}}
  {{- if not (include "arkcase.isRootContext" .) -}}
    {{- fail "The parameter must be the root context (. or $)" -}}
  {{- end -}}
  {{- $values := (include "arkcase.persistence.getDefaultSetting" (dict "ctx" . "name" "persistentVolumeReclaimPolicy") | fromYaml) -}}
  {{- $policy := "" -}}
  {{- if and (not $policy) (hasKey $values "global") -}}
    {{- $policy = $values.global -}}
    {{- if and $policy (not (regexMatch "^(retain|recycle|delete)$" ($policy | lower))) -}}
      {{- fail (printf "The value global.persistence.persistentVolumeReclaimPolicy must be a valid persistent volume reclaim policy (Retain/Recycle/Delete): [%s]" $policy) -}}
    {{- end -}}
  {{- end -}}
  {{- if and (not $policy) (hasKey $values "local") -}}
    {{- $policy = $values.local -}}
    {{- if and $policy (not (regexMatch "^(retain|recycle|delete)$" ($policy | lower))) -}}
      {{- fail (printf "The value persistence.persistentVolumeReclaimPolicy must be a valid persistent volume reclaim policy (Retain/Recycle/Delete): [%s]" $policy) -}}
    {{- end -}}
  {{- end -}}
  {{- if $policy -}}
    {{- $policy | lower | title -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.persistence.accessModes" -}}
  {{- if not (include "arkcase.isRootContext" .) -}}
    {{- fail "The parameter must be the root context (. or $)" -}}
  {{- end -}}
  {{- $values := (include "arkcase.persistence.getDefaultSetting" (dict "ctx" . "name" "accessModes") | fromYaml) -}}
  {{- $modes := dict -}}
  {{- if and (not $modes) (hasKey $values "global") -}}
    {{- $accessModes := $values.global -}}
    {{- $str := "" -}}
    {{- if kindIs "slice" $accessModes -}}
      {{- $str = join "," $accessModes -}}
    {{- else -}}
      {{- $str := ($accessModes | toString) -}}
    {{- end -}}
    {{- $modes = (include "arkcase.persistence.buildVolume.parseAccessModes" $str | fromYaml) -}}
    {{- if $modes.errors -}}
      {{- fail (printf "Invalid access modes found in the value global.persistence.accessModes: %s" $modes.errors) -}}
    {{- end -}}
  {{- end -}}
  {{- if and (not $modes) (hasKey $values "local") -}}
    {{- $accessModes := $values.local -}}
    {{- $str := "" -}}
    {{- if kindIs "slice" $accessModes -}}
      {{- $str = join "," $accessModes -}}
    {{- else -}}
      {{- $str := ($accessModes | toString) -}}
    {{- end -}}
    {{- $modes = (include "arkcase.persistence.buildVolume.parseAccessModes" $str | fromYaml) -}}
    {{- if $modes.errors -}}
      {{- fail (printf "Invalid access modes found in the value persistence.accessModes: %s" $modes.errors) -}}
    {{- end -}}
  {{- end -}}
  {{- if $modes.modes -}}
    {{- $modes.modes | compact | join "," -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.persistence.capacity" -}}
  {{- if not (include "arkcase.isRootContext" .) -}}
    {{- fail "The parameter must be the root context (. or $)" -}}
  {{- end -}}
  {{- $values := (include "arkcase.persistence.getDefaultSetting" (dict "ctx" . "name" "capacity") | fromYaml) -}}
  {{- $capacity := "" -}}
  {{- if and (not $capacity) (hasKey $values "global") -}}
    {{- $capacity = (include "arkcase.persistence.buildVolume.parseStorageSize" $values.global | fromYaml) -}}
    {{- if not $capacity -}}
      {{- fail (printf "The value global.persistence.capacity must be a valid persistent volume capacity: [%s]" $values.global) -}}
    {{- end -}}
    {{- $capacity = $values.global -}}
  {{- end -}}
  {{- if and (not $capacity) (hasKey $values "local") -}}
    {{- $capacity = (include "arkcase.persistence.buildVolume.parseStorageSize" $values.local | fromYaml) -}}
    {{- if not $capacity -}}
      {{- fail (printf "The value persistence.capacity must be a valid persistent volume capacity: [%s]" $values.local) -}}
    {{- end -}}
    {{- $capacity = $values.local -}}
  {{- end -}}
  {{- if $capacity -}}
    {{- $capacity -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.persistence.volumeMode" -}}
  {{- if not (include "arkcase.isRootContext" .) -}}
    {{- fail "The parameter must be the root context (. or $)" -}}
  {{- end -}}
  {{- $values := (include "arkcase.persistence.getDefaultSetting" (dict "ctx" . "name" "volumeMode") | fromYaml) -}}
  {{- $volumeMode := "" -}}
  {{- if and (not $volumeMode) (hasKey $values "global") -}}
    {{- $volumeMode = (include "arkcase.persistence.buildVolume.parseVolumeMode" $values.global) -}}
    {{- if not $volumeMode -}}
      {{- fail (printf "The value global.persistence.volumeMode must be a valid persistent volume mode: [%s]" $values.global) -}}
    {{- end -}}
  {{- end -}}
  {{- if and (not $volumeMode) (hasKey $values "local") -}}
    {{- $volumeMode = (include "arkcase.persistence.buildVolume.parseVolumeMode" $values.local) -}}
    {{- if not $volumeMode -}}
      {{- fail (printf "The value persistence.volumeMode must be a valid persistent volume volume mode: [%s]" $values.local) -}}
    {{- end -}}
  {{- end -}}
  {{- if $volumeMode -}}
    {{- $volumeMode -}}
  {{- end -}}
{{- end -}}

{{- /* Get or define the shared persistence settings for this chart */ -}}
{{- define "arkcase.persistence.settings" -}}
  {{- if not (include "arkcase.isRootContext" .) -}}
    {{- fail "The parameter must be the root context (. or $)" -}}
  {{- end -}}

  {{- $cacheKey := "PersistenceSettings" -}}
  {{- $masterCache := dict -}}
  {{- if (hasKey . $cacheKey) -}}
    {{- $masterCache = get . $cacheKey -}}
    {{- if and $masterCache (not (kindIs "map" $masterCache)) -}}
      {{- $masterCache = dict -}}
    {{- end -}}
  {{- end -}}
  {{- $crap := set . $cacheKey $masterCache -}}

  {{- /* We specifically don't use arkcase.fullname here b/c we don't care about part names for this */ -}}
  {{- $chartName := (include "common.fullname" .) -}}
  {{- if not (hasKey $masterCache $chartName) -}}
    {{- $enabled := (eq "true" (include "arkcase.persistence.enabled" . | trim | lower)) -}}
    {{- $hostPathRoot := (include "arkcase.persistence.hostPathRoot" .) -}}
    {{- $storageClassName := (include "arkcase.persistence.storageClassName" .) -}}
    {{- $persistentVolumeReclaimPolicy := (include "arkcase.persistence.persistentVolumeReclaimPolicy" .) -}}
    {{- if not $persistentVolumeReclaimPolicy -}}
      {{- $persistentVolumeReclaimPolicy = "Retain" -}}
    {{- end -}}
    {{- $accessModes := (include "arkcase.persistence.accessModes" .) -}}
    {{- if $accessModes -}}
      {{- $accessModes = splitList "," $accessModes | compact -}}
    {{- end -}}
    {{- if not $accessModes -}}
      {{- /* If no access modes are given by default, use ReadWriteOnce */ -}}
      {{- $accessModes = list "ReadWriteOnce" -}}
    {{- end -}}
    {{- $capacity := (include "arkcase.persistence.capacity" .) -}}
    {{- if not $capacity -}}
      {{- $capacity = "1Gi" -}}
    {{- end -}}
    {{- $volumeMode := (include "arkcase.persistence.volumeMode" .) -}}
    {{- if not $volumeMode -}}
      {{- $volumeMode = "Filesystem" -}}
    {{- end -}}

    {{- $mode := (include "arkcase.persistence.mode" .) -}}
    {{-
      $obj := dict 
        "enabled" $enabled
        "hostPathRoot" $hostPathRoot
        "capacity" $capacity
        "storageClassName" $storageClassName
        "persistentVolumeReclaimPolicy" $persistentVolumeReclaimPolicy
        "accessModes" $accessModes
        "volumeMode" $volumeMode
        "mode" $mode
    -}}
    {{- $masterCache = set $masterCache $chartName $obj -}}
  {{- end -}}
  {{- get $masterCache $chartName | toYaml -}}
{{- end -}}

{{- define "arkcase.persistence.buildVolume.sanitizeAccessMode" -}}
  {{- $M := (. | upper) -}}
  {{- if or (eq "RWO" $M) (eq "RW" $M) (eq "READWRITEONCE" $M) -}}
    {{- "ReadWriteOnce" -}}
  {{- else if or (eq "RWM" $M) (eq "RW+" $M) (eq "READWRITEMANY" $M) -}}
    {{- "ReadWriteMany" -}}
  {{- else if or (eq "ROM" $M) (eq "RO" $M) (eq "RO+" $M) (eq "READONLYMANY" $M) -}}
    {{- "ReadOnlyMany" -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.persistence.buildVolume.parseAccessModes" -}}
  {{- $modes := list -}}
  {{- $errors := dict -}}
  {{- $modeMap := dict -}}
  {{- range $m := splitList "," . -}}
    {{- $M := (include "arkcase.persistence.buildVolume.sanitizeAccessMode" (trim $m)) -}}
    {{- if $M -}}
      {{- if not (hasKey $modeMap $M) -}}
        {{- $modes = append $modes $M -}}
        {{- $modeMap = set $modeMap $M $M -}}
      {{- end -}}
    {{- else if $m -}}
      {{- $errors = set $errors $m $m -}}
    {{- end -}}
  {{- end -}}
  {{- dict "modes" $modes "errors" (keys $errors | sortAlpha) | toYaml -}}
{{- end -}}

{{- define "arkcase.persistence.buildVolume.parseStorageSize" -}}
  {{- $min := "" -}}
  {{- $max := "" -}}
  {{- $data := (. | upper) -}}
  {{- $result := dict -}}
  {{- if regexMatch "^[1-9][0-9]*[EPTGMK]I?(-[1-9][0-9]*[EPTGMK]I?)?$" $data -}}
    {{- $parts := split "-" $data -}}
    {{- $min = $parts._0 | replace "I" "i" | replace "K" "k" -}}
    {{- $max = $parts._1 | replace "I" "i" | replace "K" "k" -}}
    {{- $result = dict "min" $min "max" $max -}}
  {{- end -}}
  {{- $result | toYaml -}}
{{- end -}}

{{- define "arkcase.persistence.buildVolume.parseVolumeMode" -}}
  {{- $mode := (. | toString | lower) -}}
  {{- if or (eq "filesystem" $mode) (eq "block" $mode) -}}
    {{- title $mode -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.persistence.buildVolume.getUndeclaredSize" -}}
  {{- $limitsRequests := (.defaultSize | default "") -}}
  {{- if and $limitsRequests (kindIs "string" $limitsRequests) -}}
    {{- $limitsRequests -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.persistence.buildVolume.parseVolumeString.path" -}}
  {{- $data := .data -}}
  {{- $volumeName := .volumeName -}}
  {{- /* Must be a path ... only valid in development mode */ -}}
  {{- if isAbs $data -}}
    {{- $data = (include "arkcase.tools.normalizePath" $data) -}}
  {{- else -}}
    {{- $data = (include "arkcase.tools.normalizePath" $data) -}}
    {{- if not $data -}}
      {{- fail (printf "The given relative path [%s] for volume '%s' overflows containment (too many '..' components)" .data $volumeName) -}}
    {{- end -}}
  {{- end -}}
  {{- dict "render" (dict "volume" true "claim" true "mode" "hostPath") "hostPath" $data "generated" false | toYaml -}}
{{- end -}}

{{- define "arkcase.persistence.buildVolume.parseVolumeString.pv" -}}
  {{- /* pv://[${storageClassName}]/${capacity}#${accessModes} */ -}}
  {{- /* vol://${existingVolumeName} */ -}}
  {{- /* ${existingVolumeName} */ -}}
  {{- $data := .data -}}
  {{- $volumeName := .volumeName -}}
  {{- $volume := dict -}}
  {{- if hasPrefix "pv://" ($data | lower) -}}
    {{- /* pv://[${storageClassName}]/${capacity}#${accessModes} */ -}}
    {{- $pv := urlParse $data -}}
    {{- /* Perform QC: may have a storageClassName, must have a capacity and accessModes */ -}}
    {{- $storageClassName := $pv.host | default "" -}}
    {{- if and $storageClassName (not (regexMatch "^([a-z0-9][-a-z0-9]*)?[a-z0-9]$" ($storageClassName | lower))) -}}
      {{- fail (printf "Invalid storage class in pv:// URL for volume '%s': [%s]" $volumeName $storageClassName) -}}
    {{- end -}}
    {{- $cap := ($pv.path | default "/" | clean | trimPrefix "/") -}}
    {{- if not $cap -}}
      {{- $cap = (include "arkcase.persistence.buildVolume.getUndeclaredSize" .) -}}
    {{- end -}}
    {{- $mode := $pv.fragment | default "" -}}
    {{- if or (not $cap) (not $mode) -}}
      {{- fail (printf "The pv:// volume declaration for '%s' must be of the form: pv://[${storageClassName}]/${capacity}#${accessModes} where only the ${storageClassName} portion is optional: [%s]" $volumeName $data) -}}
    {{- end -}}
    {{- $mode = (include "arkcase.persistence.buildVolume.parseAccessModes" $mode | fromYaml) -}}
    {{- if $mode.errors -}}
      {{- fail (printf "Invalid access modes %s given for volume spec '%s': [%s]" $mode.errors $volumeName $data) -}}
    {{- end -}}
    {{- $capacity := (include "arkcase.persistence.buildVolume.parseStorageSize" $cap | fromYaml) -}}
    {{- if or (not $capacity) $capacity.max -}}
      {{- fail (printf "Invalid capacity specification '%s' for volume '%s': [%s]" $cap $volumeName $data) -}}
    {{- end -}}
    {{- $volume = dict "render" (dict "volume" true "claim" true "mode" "volume") "storageClassName" $storageClassName "capacity" $capacity.min "accessModes" $mode.modes -}}
  {{- else -}}
    {{- /* vol://${existingVolumeName} */ -}}
    {{- /* ${existingVolumeName} */ -}}
    {{- if not (hasPrefix "vol://" ($data | lower)) -}}
      {{- $data = (printf "vol://%s" $data) -}}
    {{- end -}}
    {{- /* Punt this to a pvc's vol:// parse */ -}}
    {{- $volume = (include "arkcase.persistence.buildVolume.parseVolumeString.pvc" (dict "data" $data "volumeName" $volumeName) | fromYaml) -}}
  {{- end -}}
  {{- $volume | toYaml -}}
{{- end -}}

{{- define "arkcase.persistence.buildVolume.parseVolumeString.pvc" -}}
  {{- /* vol://${volumeName}#${accessModes} */ -}}
  {{- /* pvc://[${storageClassName}]/${minSize}[-${maxSize}][#${accessModes}] */ -}}
  {{- /* pvc:${existingPvcName} */ -}}
  {{- /* ${existingPvcName} */ -}}
  {{- $data := .data -}}
  {{- $volumeName := .volumeName -}}

  {{- $volume := dict -}}
  {{- if or (hasPrefix "vol://" ($data | lower)) (hasPrefix "pvc:" ($data | lower)) -}}
    {{- /* vol://${volumeName}#${accessModes} */ -}}
    {{- /* pvc://[${storageClassName}]/${minSize}[-${maxSize}][#${accessModes}] */ -}}
    {{- /* pvc:${existingPvcName} */ -}}
    {{- $pvc := urlParse $data -}}
    {{- if or $pvc.query $pvc.userinfo -}}
      {{- fail (printf "Malformed URI for volume '%s': [%s] - may not have userInfo or query data" $volumeName $data) -}}
    {{- end -}}

    {{- $mode := dict -}}
    {{- if $pvc.fragment -}}
      {{- $mode = (include "arkcase.persistence.buildVolume.parseAccessModes" $pvc.fragment | fromYaml) -}}
      {{- if $mode.errors -}}
        {{- fail (printf "Invalid access modes %s given for volume spec '%s': [%s]" $mode.errors $volumeName $data) -}}
      {{- end -}}
    {{- end -}}

    {{- if and $pvc.host (not (regexMatch "^([a-z0-9][-a-z0-9]*)?[a-z0-9]$" ($pvc.host | lower))) -}}
      {{- fail (printf "Volume '%s' has an invalid first component '%s': [%s]" $volumeName $pvc.host $data) -}}
    {{- end -}}
    {{- if and $pvc.opaque (not (regexMatch "^([a-z0-9][-a-z0-9]*)?[a-z0-9]$" ($pvc.opaque | lower))) -}}
      {{- fail (printf "Volume '%s' has an invalid first component '%s': [%s]" $volumeName $pvc.opaque $data) -}}
    {{- end -}}

    {{- if eq "vol" ($pvc.scheme | lower) -}}
      {{- /* vol://${volumeName}[#${accessModes}] */ -}}
      {{- if not $pvc.host -}}
        {{- fail (printf "Must provide the name of the volume to connect the PVC to for volume '%s': [%s]" $volumeName $data) -}}
      {{- end -}}
      {{- $volume = dict "render" (dict "volume" false "claim" true "mode" "claim") "volumeName" $pvc.host "accessModes" $mode.modes -}}
    {{- else if eq "pvc" ($pvc.scheme | lower) -}}
      {{- if hasPrefix "pvc://" ($data | lower) -}}
        {{- /* pvc://[${storageClassName}]/${minSize}[-${maxSize}][#${accessModes}] */ -}}
        {{- $limitsRequests := ($pvc.path | default "/" | clean | trimPrefix "/") -}}
        {{- if not $limitsRequests -}}
          {{- $limitsRequests = (include "arkcase.persistence.buildVolume.getUndeclaredSize" .) -}}
        {{- end -}}
        {{- if not $limitsRequests -}}
          {{- fail (printf "No limits-requests specification given for volume '%s': [%s]" $volumeName $data) -}}
        {{- end -}}
        {{- $size := (include "arkcase.persistence.buildVolume.parseStorageSize" $limitsRequests | fromYaml) -}}
        {{- if not $size -}}
          {{- fail (printf "Invalid limits-requests specification '%s' for volume '%s': [%s]" $limitsRequests $volumeName $data) -}}
        {{- end -}}
        {{- $resources := dict "requests" (dict "storage" $size.min) -}}
        {{- if $size.max -}}
          {{- $resources = set $resources "limits" (dict "storage" $size.max) -}}
        {{- end -}}
        {{- $volume = dict "render" (dict "volume" false "claim" true "mode" "claim") "storageClassName" $pvc.host "accessModes" $mode.modes "resources" $resources -}}
      {{- else -}}
        {{- /* pvc:${existingPvcName} */ -}}
        {{- if not $pvc.opaque -}}
          {{- fail (printf "Must provide the name of the existing PVC to connect to for volume '%s': [%s]" $volumeName $data) -}}
        {{- end -}}
        {{- $volume = dict "render" (dict "volume" false "claim" false "mode" "claim") "claimName" $pvc.opaque -}}
      {{- end -}}
    {{- end -}}
  {{- else if $data -}}
    {{- /* ${existingPvcName} */ -}}
    {{- if not (regexMatch "^([a-z0-9][-a-z0-9]*)?[a-z0-9]$" ($data | lower)) -}}
      {{- fail (printf "The PVC name '%s' for volume '%s' is not valid" $data $volumeName) -}}
    {{- end -}}
    {{- $volume = dict "render" (dict "volume" false "claim" false "mode" "claim") "claimName" $data -}}
  {{- else -}}
    {{- fail (printf "The PVC string for volume '%s' cannot be empty" $volumeName) -}}
  {{- end -}}
  {{- $volume | toYaml -}}
{{- end -}}

{{- define "arkcase.persistence.buildVolume.renderUndescribed" -}}
  {{- /* This is an undescribed volume */ -}}
  {{- $result := (dict "render" (dict "volume" true "claim" true "mode" "hostPath" "generated" true)) -}}
  {{- $limitsRequests := (include "arkcase.persistence.buildVolume.getUndeclaredSize" .) -}}
  {{- if $limitsRequests -}}
    {{- $size := (include "arkcase.persistence.buildVolume.parseStorageSize" $limitsRequests | fromYaml) -}}
    {{- $resources := dict "requests" (dict "storage" $size.min) -}}
    {{- if $size.max -}}
      {{- $resources = set $resources "limits" (dict "storage" $size.max) -}}
    {{- end -}}
    {{- $result = set $result "resources" $resources -}}
  {{- end -}}
  {{- $result | toYaml -}}
{{- end -}}

{{- define "arkcase.persistence.buildVolume.parseVolumeString" -}}
  {{- /* Must be a pv:// or a path ... the empty string renders a default volume */ -}}
  {{- $data := .data -}}
  {{- $volumeName := .volumeName -}}
  {{- $volume := dict -}}
  {{- if $data -}}
    {{- if or (hasPrefix "pvc:" ($data | lower)) (hasPrefix "vol://" ($data | lower)) -}}
      {{- $volume = (include "arkcase.persistence.buildVolume.parseVolumeString.pvc" . | fromYaml) -}}
    {{- else if (hasPrefix "pv:" ($data | lower)) -}}
      {{- $volume = (include "arkcase.persistence.buildVolume.parseVolumeString.pv" . | fromYaml) -}}
    {{- else -}}
      {{- $volume = (include "arkcase.persistence.buildVolume.parseVolumeString.path" . | fromYaml) -}}
    {{- end -}}
  {{- else -}}
    {{- $volume = (include "arkcase.persistence.buildVolume.renderUndescribed" . | fromYaml) -}}
  {{- end -}}
  {{- $volume | toYaml -}}
{{- end -}}

{{- define "arkcase.persistence.buildVolume.renderForCache" -}}
  {{- $ctx := .ctx -}}
  {{- $volumeName := .volumeName -}}
  {{- $data := .data -}}
  {{- $mustRender := .mustRender -}}

  {{- $volume := dict -}}
  {{- if kindIs "string" $data -}}
    {{- $volume = (include "arkcase.persistence.buildVolume.parseVolumeString" (dict "ctx" $ctx "data" $data "volumeName" $volumeName) | fromYaml) -}}
  {{- else if kindIs "map" $data -}}
    {{- /* May be a map that has "path", "claim", or "volume" ... but only one! */ -}}
    {{- $data = pick $data "path" "claim" "volume" -}}
    {{- if gt (len (keys $data)) 1 -}}
      {{- fail (printf "The volume declaration for %s may only have one of the keys 'path', 'claim', or 'volume': keys = %s" $volumeName (keys $data)) -}}
    {{- end -}}
    {{- if $data.claim -}}
      {{- if kindIs "string" $data.claim -}}
        {{- $volume = (include "arkcase.persistence.buildVolume.parseVolumeString.pvc" (dict "ctx" $ctx "data" $data.claim "volumeName" $volumeName) | fromYaml) -}}
      {{- else if kindIs "map" $data.claim -}}
        {{- /* The map is a claim spec, so use it */ -}}
        {{- $volume = (dict "render" (dict "volume" false "claim" true) "spec" $data.claim) -}}
      {{- else -}}
        {{- fail (printf "The 'claim' value for the volume '%s' must be either a dict or a string (%s)" $volumeName (kindOf $data.claim)) -}}
      {{- end -}}
      {{- $volume = set $volume "render" (set $volume.render "mode" "claim") -}}
    {{- else if $data.volume -}}
      {{- if kindIs "string" $data.volume -}}
        {{- $volume = (include "arkcase.persistence.buildVolume.parseVolumeString.pv" (dict "ctx" $ctx "data" $data.volume "volumeName" $volumeName) | fromYaml) -}}
      {{- else if kindIs "map" $data.volume -}}
        {{- /* The map is a volume spec, so use it */ -}}
        {{- $volume = (dict "render" (dict "volume" true "claim" true) "spec" $data.volume) -}}
      {{- else -}}
        {{- fail (printf "The 'volume' value for the volume '%s' must be either a dict or a string (%s)" $volumeName (kindOf $data.volume)) -}}
      {{- end -}}
      {{- $volume = set $volume "render" (set $volume.render "mode" "volume") -}}
    {{- else -}}
      {{- if $data.path -}}
        {{- $volume = (include "arkcase.persistence.buildVolume.parseVolumeString.path" (dict "ctx" $ctx "data" $data.path "volumeName" $volumeName) | fromYaml) -}}
      {{- else -}}
        {{- $volume = (include "arkcase.persistence.buildVolume.renderUndescribed" . | fromYaml) -}}
      {{- end -}}
    {{- end -}}
  {{- else if (kindIs "invalid" $data) -}}
    {{- $volume = (include "arkcase.persistence.buildVolume.renderUndescribed" . | fromYaml) -}}
  {{- else -}}
    {{- fail (printf "The volume declaration for %s must be either a string or a map (%s)" $volumeName (kindOf $data)) -}}
  {{- end -}}
  {{- set $volume "render" (merge $volume.render (dict "name" $volumeName "mustRender" $mustRender)) | toYaml -}}
{{- end -}}

{{- /*
Parse a volume declaration and return a map that contains the following (possible) keys:
  claim: the PVC that must be rendered, or the name of the PVC that must be used
  volume: the PV that must be rendered
*/ -}}
{{- define "arkcase.persistence.buildVolume.cached" -}}
  {{- $ctx := .ctx -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The 'ctx' parameter must be the root context (. or $)" -}}
  {{- end -}}

  {{- if not (hasKey . "name") -}}
    {{- fail "Must provide the 'name' parameter for the volume to be built" -}}
  {{- end -}}

  {{- /* The volume's name will be of the form "[${part}-]$name" ($part is optional) */ -}}
  {{- $name := .name -}}
  {{- $globalName := (printf "%s-%s" $ctx.Chart.Name $name) -}}
  {{- $volumeName := (printf "%s-%s" $ctx.Release.Name $globalName) -}}
  {{- $persistence := ($ctx.Values.persistence | default dict) -}}
  {{- $persistenceVolumes := ($persistence.volumes | default dict) -}}

  {{- $globalPersistence := (($ctx.Values.global).persistence | default dict) -}}
  {{- $globalPersistenceVolumes := ($globalPersistence.volumes | default dict) -}}

  {{- $defaultSize := get (($persistence.default).volumeSize | default dict) $name -}}
  {{- if or (not $defaultSize) (not (kindIs "string" $defaultSize)) -}}
    {{- $defaultSize = "" -}}
  {{- end -}}

  {{- $enabled := (not (empty (include "arkcase.persistence.enabled" $ctx))) -}}
  {{- $mustRender := $enabled -}}

  {{- $data := dict -}}
  {{- if hasKey $persistenceVolumes $name -}}
    {{- $data = get $persistenceVolumes $name -}}
    {{- $mustRender = true -}}
  {{- end -}}

  {{- $result := dict -}}
  {{- if hasKey $globalPersistenceVolumes $ctx.Chart.Name -}}
    {{- $globalVolumes := get $globalPersistenceVolumes $ctx.Chart.Name -}}
    {{- if and $globalVolumes (kindIs "map" $globalVolumes) (hasKey $globalVolumes $name) -}}
      {{- /* The global declaration clobbers the local one */ -}}
      {{- $data = (get $globalVolumes $name) -}}
      {{- $mustRender = true -}}
    {{- end -}}
  {{- end -}}

  {{- include "arkcase.persistence.buildVolume.renderForCache" (dict "ctx" $ctx "volumeName" $volumeName "data" $data "defaultSize" $defaultSize "mustRender" $mustRender) -}}
{{- end -}}

{{- define "arkcase.persistence.buildVolume" -}}
  {{- $ctx := .ctx -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The 'ctx' parameter must be the root context (. or $)" -}}
  {{- end -}}

  {{- $name := .name -}}
  {{- if not $name -}}
    {{- fail "The volume name may not be empty" -}}
  {{- end -}}

  {{- $partname := (include "arkcase.part.name" $ctx) -}}
  {{- if $partname -}}
    {{- $name = (printf "%s-%s" $partname $name) -}}
  {{- end -}}

  {{- $cacheKey := "PersistenceVolumes" -}}
  {{- $masterCache := dict -}}
  {{- if (hasKey $ctx $cacheKey) -}}
    {{- $masterCache = get $ctx $cacheKey -}}
    {{- if and $masterCache (not (kindIs "map" $masterCache)) -}}
      {{- $masterCache = dict -}}
    {{- end -}}
  {{- end -}}
  {{- $ctx = set $ctx $cacheKey $masterCache -}}

  {{- $volumeName := (printf "%s-%s" (include "arkcase.fullname" .) $name) -}}
  {{- if not (hasKey $masterCache $volumeName) -}}
    {{- $obj := (include "arkcase.persistence.buildVolume.cached" (set . "name" $name) | fromYaml) -}}
    {{- $masterCache = set $masterCache $volumeName $obj -}}
  {{- end -}}
  {{- get $masterCache $volumeName | toYaml -}}
{{- end -}}

{{- /* Verify that the persistence configuration is good */ -}}
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
Render the entries for volumes:, per configurations
*/ -}}
{{- define "arkcase.persistence.volume" -}}
  {{- $ctx := .ctx -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The 'ctx' parameter must be the root context (. or $)" -}}
  {{- end -}}

  {{- $volumeName := .name -}}
  {{- if not $volumeName -}}
    {{- fail "Must provide the 'name' of the volumes to declare" -}}
  {{- end -}}

  {{- $settings := (include "arkcase.persistence.settings" $ctx | fromYaml) -}}
  {{- if $settings.enabled -}}
    {{- $renderVolume := false -}}
    {{- $volume := (include "arkcase.persistence.buildVolume" (pick . "ctx" "name") | fromYaml) -}}
    {{- $subsystem := (include "arkcase.subsystem.name" $ctx) -}}
    {{- $mode := $volume.render.mode -}}
    {{- $decl := dict -}}
    {{- if eq $mode "hostPath" -}}
      {{- $renderVolume = (eq $settings.mode "development") -}}
      {{- if $renderVolume -}}
        {{- /* The host path is structured as follows */ -}}
        {{- $hostPath := "" -}}
        {{- if (hasKey $volume "hostPath") -}}
          {{- if not $volume.hostPath -}}
            {{- fail (printf "The host path may not be the empty string (volume [%s] for chart %s)" $volumeName $ctx.Chart.Name) -}}
          {{- end -}}
          {{- $hostPath = $volume.hostPath -}}
        {{- else -}}
          {{- $hostPath = $volumeName -}}
          {{- $partname := (include "arkcase.part.name" $ctx) -}}
          {{- if $partname -}}
            {{- $hostPath = (printf "%s-%s" $partname $hostPath) -}}
          {{- end -}}
          {{- $hostPath = (printf "%s/%s/%s/%s" $ctx.Release.Namespace $ctx.Release.Name $subsystem $hostPath) -}}
        {{- end -}}
        {{- if not (isAbs $hostPath) -}}
          {{- $hostPath = printf "%s/%s" $settings.hostPathRoot $hostPath -}}
        {{- end -}}
        {{- $decl = dict "hostPath" (dict "path" $hostPath "type" "DirectoryOrCreate") -}}
      {{- end -}}
    {{- else if eq $mode "claim" -}}
      {{- $renderVolume = and (hasKey $volume "claimName") $volume.claimName -}}
      {{- if $renderVolume -}}
        {{- $decl = dict "persistentVolumeClaim" (dict "claimName" $volume.claimName) -}}
      {{- end -}}
    {{- else if eq $mode "volume" -}}
      {{- $renderVolume = true -}}
      {{- $claimName := (printf "%s-%s-%s" $ctx.Release.Name $subsystem $volumeName) -}}
      {{- $decl = dict "persistentVolumeClaim" (dict "claimName" $claimName) -}}
    {{- else -}}
      {{- fail (printf "Unsupported volume rendering mode [%s] for volume %s (chart %s)" $mode $volumeName $ctx.Chart.Name) -}}
    {{- end -}}
    {{- if $renderVolume -}}
- name: {{ $volumeName | quote }}
      {{- $decl | toYaml | nindent 2 }}
    {{- end -}}
  {{- else }}
- name: {{ $volumeName | quote }}
  emptyDir: {}
  {{- end -}}
{{- end -}}

{{- /*
Render the entries for volumeClaimTemplates:, per configurations
*/ -}}
{{- define "arkcase.persistence.volumeClaimTemplate" -}}
  {{- $ctx := .ctx -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The 'ctx' parameter must be the root context (. or $)" -}}
  {{- end -}}

  {{- $volumeName := .name -}}
  {{- if not $volumeName -}}
    {{- fail "Must provide the 'name' of the volumeClaimTemplates to declare" -}}
  {{- end -}}

  {{- $volumeFullName := $volumeName -}}
  {{- $partname := (include "arkcase.part.name" $ctx) -}}
  {{- if $partname -}}
    {{- $volumeFullName = printf "%s-%s" $partname $volumeFullName -}}
  {{- end -}}

  {{- $settings := (include "arkcase.persistence.settings" $ctx | fromYaml) -}}
  {{- if $settings.enabled -}}
    {{- $renderVolume := false -}}
    {{- $volume := (include "arkcase.persistence.buildVolume" (pick . "ctx" "name") | fromYaml) -}}
    {{- $subsystem := (include "arkcase.subsystem.name" $ctx) -}}
    {{- $claimName := (printf "%s-%s-%s-%s" $ctx.Release.Namespace $ctx.Release.Name $subsystem $volumeFullName) -}}
    {{- $labels := dict "arkcase/persistentVolume" $claimName -}}
    {{- $metadata := dict "name" $volumeName "labels" $labels -}}
    {{- $mode := $volume.render.mode -}}
    {{- $decl := dict -}}
    {{- if eq $mode "hostPath" -}}
      {{- $renderVolume = (ne $settings.mode "development") -}}
      {{- if $renderVolume -}}
        {{- /* Render a template using the default settings */ -}}
        {{- $resources := $volume.resources -}}
        {{- if or (not $resources) (not (kindIs "map" $resources)) -}}
          {{- $resources = dict "requests" (dict "storage" $settings.capacity) -}}
        {{- end -}}
        {{- $spec := dict "accessModes" $settings.accessModes "resources" $resources "volumeMode" $settings.volumeMode -}}
        {{- if $settings.storageClassName -}}
          {{- $spec = set $spec "storageClassName" $settings.storageClassName -}}
        {{- end -}}
        {{- $decl = dict "metadata" $metadata "spec" $spec -}}
      {{- end -}}
    {{- else if hasKey $volume "volumeName" -}}
      {{- /* We're referencing an existing volume - don't care about the mode */ -}}
      {{- $renderVolume = true -}}
      {{- if not $volume.volumeName -}}
        {{- fail (printf "The target volume name may not be the empty string (volume %s, chart %s)" $volumeFullName $ctx.Chart.Name) -}}
      {{- end -}}
      {{- $accessModes := ($volume.accessModes | default $settings.accessModes) -}}
      {{- $spec := dict "storageClassName" "" "volumeName" $volume.volumeName "resources" (dict "requests" (dict "storage" "1Ki")) "accessModes" $accessModes -}}
      {{- $decl = dict "metadata" $metadata "spec" $spec -}}
    {{- else if eq $mode "claim" -}}
      {{- if hasKey $volume "claimName" -}}
        {{- /* Reference an existing claim ... already handled in the volumes handler */ -}}
        {{- $renderVolume = false -}}
      {{- else if hasKey $volume "spec" -}}
        {{- /* The claim template is fully described */ -}}
        {{- $renderVolume = true -}}
        {{- $spec := $volume.spec -}}
        {{- if and (hasKey $spec "metadata") (kindIs "map" $spec.metadata) -}}
          {{- /* We need to merge the metadata set, and preserve the name, namespace, and one label */ -}}
          {{- $specMD := (omit $spec.metadata "name" "namespace") -}}
          {{- $metadata = merge (omit $spec.metadata "name" "namespace") $metadata -}}
          {{- $specLabels := $metadata.labels -}}
          {{- if not (kindIs "map" $specLabels) -}}
            {{- $specLabels = dict -}}
          {{- end -}}
          {{- $metadata = set $metadata "labels" (mergeOverwrite $specLabels $labels) -}}
        {{- end -}}
        {{- if or (not (hasKey $spec "spec")) (not (kindIs "map" $spec.spec)) -}}
          {{- fail (printf "The volume description must contain a spec: stanza (volume %s, chart %s)" $volumeFullName $ctx.Chart.Name) -}}
        {{- end -}}
        {{- $decl = dict "metadata" $metadata "spec" $spec.spec -}}
      {{- else -}}
        {{- /* We were given some of the settings */ -}}
        {{- $renderVolume = true -}}
        {{- $storageClassName := ($volume.storageClassName | default $settings.storageClassName) -}}
        {{- $accessModes := ($volume.accessModes | default $settings.accessModes) -}}
        {{- $resources := ($volume.resources | default (dict "resources" (dict "requests" (dict "storage" $settings.capacity)))) -}}
        {{- $spec := dict "resources" $resources "accessModes" $accessModes -}}
        {{- if $storageClassName -}}
          {{- $spec = set $spec "storageClassName" $storageClassName -}}
        {{- end -}}
        {{- $decl = dict "metadata" $metadata "spec" $spec -}}
      {{- end -}}
    {{- else if eq $mode "volume" -}}
      {{- $renderVolume = false -}}
    {{- else -}}
      {{- fail (printf "Unsupported volume rendering mode [%s] for volume %s (chart %s)" $mode $volumeFullName $ctx.Chart.Name) -}}
    {{- end -}}
    {{- $decl = list $decl -}}
    {{- if $renderVolume -}}
{{ $decl | toYaml }}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{- /*
Render the PersistentVolume and PersistentVolumeClaim objects for a given volume, per configurations
*/ -}}
{{- define "arkcase.persistence.declareResources" -}}
  {{- $ctx := .ctx -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The 'ctx' parameter must be the root context (. or $)" -}}
  {{- end -}}

  {{- $volumeName := .volume -}}
  {{- if not $volumeName -}}
    {{- fail "Must provide the 'volumeName' of the resources to declare" -}}
  {{- end -}}

  {{- $settings := (include "arkcase.persistence.settings" $ctx | fromYaml) -}}
  {{- if $settings.enabled -}}
    {{- $volume := (include "arkcase.persistence.buildVolume" (set . "name" $volumeName) | fromYaml) -}}
    {{- $mode := $volume.render.mode -}}
    {{- if and (eq $mode "volume") (not (hasKey $volume "volumeName")) -}}
      {{- $partname := (include "arkcase.part.name" $ctx) -}}
      {{- if $partname -}}
        {{- $volumeName = printf "%s-%s" $partname $volumeName -}}
      {{- end -}}
      {{- $subsystem := (include "arkcase.subsystem.name" $ctx) -}}
      {{- $pvcName := (printf "%s-%s-%s" $ctx.Release.Name $subsystem $volumeName) -}}
      {{- $pvName := (printf "%s-%s" $ctx.Release.Namespace $pvcName) -}}
      {{- $volumeData := omit $volume "render" -}}
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: {{ $pvName | quote }}
  namespace: {{ $ctx.Release.Namespace | quote }}
  labels: {{- include "arkcase.labels" $ctx | nindent 4 }}
      {{- with $ctx.Values.labels }}
        {{- toYaml . | nindent 4 }}
      {{- end }}
      {{- with $volumeData.labels }}
        {{- toYaml . | nindent 4 }}
      {{- end }}
    arkcase/persistentVolume: {{ $pvName | quote }}
  annotations:
      {{- with $ctx.Values.annotations  }}
        {{- toYaml . | nindent 4 }}
      {{- end }}
      {{- with $volumeData.annotations  }}
        {{- toYaml . | nindent 4 }}
      {{- end }}
      {{- $pvSpec := dict -}}
      {{- $pvcSpec := dict -}}
spec:
  claimRef:
    namespace: {{ $ctx.Release.Namespace | quote }}
    name: {{ $pvcName | quote }}
      {{- if hasKey $volumeData "spec" }}
        {{- /* We were given a volume declaration, so quote it */ -}}
        {{- $pvSpec = $volumeData.spec -}}
      {{- else -}}
        {{- $storageClassName := ($volumeData.storageClassName | default $settings.storageClassName) -}}
        {{- if $storageClassName -}}
          {{- $pvSpec = set $pvSpec "storageClassName" $volumeData.storageClassName -}}
        {{- end -}}
        {{- $pvSpec = set $pvSpec "capacity" (dict "storage" ($volumeData.capacity | default $settings.capacity)) -}}
        {{- $pvSpec = set $pvSpec "accessModes" ($volumeData.accessModes | default $settings.accessModes) -}}
        {{- $pvSpec = set $pvSpec "volumeMode" $settings.volumeMode -}}
        {{- $pvSpec = set $pvSpec "persistentVolumeReclaimPolicy" $settings.persistentVolumeReclaimPolicy -}}
      {{- end -}}
      {{- toYaml $pvSpec | nindent 2 }}
---
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: {{ $pvcName | quote }}
  namespace: {{ $ctx.Release.Namespace | quote }}
  labels: {{- include "arkcase.labels" $ctx | nindent 4 }}
      {{- with $ctx.Values.labels }}
        {{- toYaml . | nindent 4 }}
      {{- end }}
      {{- with $volumeData.labels }}
        {{- toYaml . | nindent 4 }}
      {{- end }}
    arkcase/persistentVolume: {{ $pvName | quote }}
    arkcase/persistentVolumeClaim: {{ $pvcName | quote }}
  annotations:
      {{- with $ctx.Values.annotations  }}
        {{- toYaml . | nindent 4 }}
      {{- end }}
      {{- with $volumeData.annotations  }}
        {{- toYaml . | nindent 4 }}
      {{- end }}
spec:
  storageClassName: ""
  volumeName: {{ $pvName | quote }}
  selector:
    matchLabels:
      arkcase/persistentVolume: {{ $pvName | quote }}
    {{- end -}}
  {{- end -}}
{{- end -}}
