{{- /*
Return a map which contains the "ctx", "subsystem" and "value" keys as required by other API calls
*/ -}}
{{- define "ark-subsys.subsystem" -}}
  {{- $ctx := . -}}
  {{- $subsysName := "" -}}
  {{- $param := "" -}}
  {{- if hasKey $ctx "Values" -}}
    {{- /* we're fine, we're auto-detecting */ -}}
  {{- else if and (hasKey $ctx "subsystem") (hasKey $ctx "ctx") -}}
    {{- $subsysName = (toString $ctx.subsystem) -}}
    {{- /* Does it also have a value specification? */ -}}
    {{- if (hasKey $ctx "value") -}}
      {{- $param = (toString $ctx.value | required "The 'value' parameter may not be the empty string") -}}
    {{- end -}}
    {{- $ctx = $ctx.ctx -}}
  {{- else -}}
    {{- fail "The provided dictionary must either have 'Values', or both 'subsys' and 'ctx' parameters" -}}
  {{- end -}}

  {{- /* If we've not been given a subsystem name, we detect it */ -}}
  {{- if (empty $subsysName) -}}
    {{- if (hasKey $ctx.Values "arkcase-subsystem") -}}
      {{- $subsysName = get $ctx "arkcase-subsystem" -}}
    {{- else -}}
      {{- /* Check to see that the subsystem data is there */ -}}
      {{- if not (hasKey $ctx.Values.global "subsystem") -}}
        {{- fail "Subsystem data is not defined. Cannot continue." -}}
      {{- end -}}

      {{- /* Check to see that the subsystem mappings are there */ -}}
      {{- if not (hasKey $ctx.Values.global.subsystem "mappings") -}}
        {{- fail "Subsystem mappings are not defined. Cannot continue." -}}
      {{- end -}}

      {{- /* Check to see that there's a mapping for this chart */ -}}
      {{- if not (hasKey $ctx.Values.global.subsystem.mappings .Chart.Name) -}}
        {{- fail (printf "Subsystem mappings don't have an entry for the chart [%s]. Cannot continue." .Chart.Name ) -}}
      {{- end -}}

      {{- $subsysName = (get $ctx.Values.global.subsystem.mappings .Chart.Name) -}}
      {{- $marker := set $ctx "arkcase-subsystem" $subsysName -}}
    {{- end -}}
  {{- end -}}
  {{- /* Start structuring our return value */ -}}
  {{- $map := (dict "ctx" $ctx "name" $subsysName) -}}

  {{- /* Cache the information */ -}}
  {{- $subsys := dict -}}
  {{- if (hasKey $ctx "Subsystem") -}}
    {{- $subsys = get $ctx "Subsystem" -}}
  {{- else -}}
    {{- $crap := set $ctx "Subsystem" $subsys -}}
  {{- end -}}

  {{- $data := dict -}}
  {{- if (hasKey $subsys $subsysName) -}}
    {{- /* Retrieve the cached data */ -}}
    {{- $data = get $subsys $subsysName -}}
  {{- else -}}
    {{- /* Make a copy of the common subsystem data into the "data" dict */ -}}
    {{- if (hasKey $ctx.Values.global.subsystem "common") -}}
      {{- $data = ($ctx.Values.global.subsystem.common | mustDeepCopy) -}}
    {{- end -}}
    {{- if (hasKey $ctx.Values.global.subsystem $subsysName) -}}
      {{- $data = (get $ctx.Values.global.subsystem $subsysName | mustDeepCopy | mustMergeOverwrite $data) -}}
    {{- end -}}

    {{- /* Cache the computed data */ -}}
    {{- $crap := set $subsys $subsysName $data -}}
  {{- end -}}
  {{- $map = (set $map "data" $data) -}}

  {{- /* Set the parameter specification, if any */ -}}
  {{- if (not (empty $param)) -}}
    {{- $param = (set $map "value" $param) -}}
  {{- end -}}

  {{- $map | toYaml | nindent 0 -}}
{{- end -}}

{{- /*
Identify the subsystem being used

Parameter: "optional" (not used)
*/ -}}
{{- define "ark-subsys.subsystem.name" -}}
  {{- get (include "ark-subsys.subsystem" . | fromYaml) "name" -}}
{{- end -}}

{{- /*
Check whether a subsystem is configured for external provisioning.

Parameter: either the root context (i.e. "." or "$"), or
           a dict with two keys:
             - ctx = the root context (either "." or "$")
             - subsystem = a string with the name of the subsystem to query
*/ -}}
{{- define "ark-subsys.subsystem.external" -}}
  {{- $map := (include "ark-subsys.subsystem" . | fromYaml) -}}
  {{- $ctx := $map.ctx -}}
  {{- $subsysName := $map.name -}}
  {{- $enabled := (eq 1 0) -}}
  {{- if (hasKey $ctx.Values.global.subsystem $subsysName) -}}
    {{- $map := get $ctx.Values.global.subsystem $subsysName -}}
    {{- if (hasKey $map "external") -}}
      {{- $external := get $map "external" -}}
      {{- if (hasKey $external "enabled") -}}
        {{- $enabled = get $external "enabled" -}}
        {{- if not (kindIs "bool" $enabled) -}}
          {{- if (eq "true" (toString $enabled | lower)) -}}
            {{- $enabled = true -}}
          {{- end -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
  {{- if $enabled -}}
    true
  {{- end -}}
{{- end -}}

{{- /*
Retrieve a configuration value for a given subsystem's configuration. If the value is scalar, it will be output verbatim. If it's a structured value (i.e. map or a list) it will be output in YAML format, with 0 indent.

Parameter: either the root context (i.e. "." or "$"), or
           a dict with two keys:
             - ctx = the root context (either "." or "$")
             - subsystem = a string with the name of the subsystem to query
             - value = a string with the name/path of the value to query
*/ -}}
{{- define "ark-subsys.subsystem.value" -}}
  {{- $map := (include "ark-subsys.subsystem" . | fromYaml) -}}
  {{- $ctx := $map.ctx -}}
  {{- $subsysName := $map.name -}}
  {{- if not (hasKey $map "value") -}}
    {{- fail "Must provide the 'value' parameter in the dict" -}}
  {{- end -}}
  {{- $value := $map.value -}}
  {{- if eq "." $value -}}
    {{- fail "The value '.' is forbidden. Please use a full value name" -}}
  {{- end -}}

  {{- /* Everything has been cached already, so use that */ -}}
  {{- $currentMap := get $ctx.Subsystem $subsysName -}}
  {{- $currentKey := list -}}
  {{- $parts := (splitList "." $value) -}}
  {{- $failed := (eq 1 0) -}}
  {{- range $parts -}}
    {{- if not $failed -}}
      {{- if not (hasKey $currentMap .) -}}
        {{- fail (printf "No key found with the path [%s] for subsystem [%s]" ($currentKey | join ".") $subsysName) -}}
      {{- end -}}
      {{- $next := get $currentMap . -}}
      {{- if or (kindIs "map" $next) (eq (len $currentKey) (sub (len $parts) 1)) -}}
        {{- /* If this is the last element, then it's OK for it to not be a map */ -}}
        {{- $currentKey = append $currentKey . -}}
        {{- $currentMap = $next -}}
      {{- else -}}
        {{- fail (printf "Failed to resolve the key [%s] for subsystem [%s] - got as far as [%s] (%s)" $value $subsysName ($currentKey | join ".") (kindOf $currentMap)) -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}

  {{- $value := $currentMap -}}
  {{- /* If the value is a scalar, then just spit it out, otherwise toYaml it for consumption on the other end */ -}}
  {{- $kind := (kindOf $value) -}}
  {{- if or (eq "string" $kind) (eq "bool" $kind) (eq "int" $kind) (eq "float64" $kind) -}}
    {{- $value -}}
  {{- else -}}
    {{- $value | toYaml | nindent 0 -}}
  {{- end -}}
{{- end -}}
