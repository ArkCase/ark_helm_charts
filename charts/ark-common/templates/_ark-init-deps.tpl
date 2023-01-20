{{- /*
Render the boot order configuration file to be consumed by the init container
that checks the boot order
*/ -}}
{{- define "arkcase.initDependencies.render" -}}
  {{- $declaration := dict -}}
  {{- if hasKey .Values "initDependencies" -}}
    {{- $declaration = .Values.initDependencies -}}
  {{- end -}}
  {{- if not (kindIs "map" $declaration) -}}
    {{- fail (printf "The .Values.initDependencies value must be a map data structure (%s)" (kindOf $declaration)) -}}
  {{- end -}}

  {{- $globalMode := "" -}}
  {{- if hasKey $declaration "mode" -}}
    {{- $globalMode = ($declaration.mode | toString) -}}
  {{- else -}}
    {{- $globalMode = "all" -}}
  {{- end -}}
  {{- if and (ne $globalMode "all") (ne $globalMode "any") -}}
    {{- fail (printf "Unknown value for the general dependency tracking mode: [%s] - must be either 'all' or 'any'" $globalMode) -}}
  {{- end -}}

  {{- $template := dict -}}
  {{- if hasKey $declaration "template" -}}
    {{- $template = $declaration.template -}}
  {{- end -}}
  {{- if not (kindIs "map" $template) -}}
    {{- fail (printf "The .Values.initDependencies.template value must be a map data structure (%s)" (kindOf $template)) -}}
  {{- end -}}

  {{- if hasKey $template "mode" -}}
    {{- $tempVar := ($declaration.mode | toString) -}}
    {{- if and (ne $tempVar "all") (ne $tempVar "any") -}}
      {{- fail (printf "Unknown value for the dependency template tracking mode: [%s] - must be either 'all' or 'any'" $tempVar) -}}
    {{- end -}}
  {{- end -}}

  {{- if hasKey $template "initialDelay" -}}
    {{- $tempVar := ($template.initialDelay | int) -}}
    {{- if lt $tempVar 0 -}}
      {{- $crap := set $template "initialDelay" 0 -}}
    {{- end -}}
  {{- end -}}

  {{- if hasKey $template "delay" -}}
    {{- $tempVar := ($template.delay | int) -}}
    {{- if lt $tempVar 0 -}}
      {{- $crap := set $template "delay" 1 -}}
    {{- end -}}
  {{- end -}}

  {{- if hasKey $template "timeout" -}}
    {{- $tempVar := ($template.timeout | int) -}}
    {{- if lt $tempVar 0 -}}
      {{- $crap := set $template "timeout" 1 -}}
    {{- end -}}
  {{- end -}}

  {{- if hasKey $template "attempts" -}}
    {{- $tempVar := ($template.attempts | int) -}}
    {{- if lt $tempVar 0 -}}
      {{- $crap := set $template "attempts" 1 -}}
    {{- end -}}
  {{- end -}}

  {{- $dependencies := dict -}}
  {{- if $declaration.dependencies -}}
    {{- $dependencies = $declaration.dependencies -}}
  {{- end -}}
  {{- if not (kindIs "map" $declaration) -}}
    {{- fail "The .Values.initDependencies.dependencies value must be a map data structure" -}}
  {{- end -}}

  {{- $initDependencies := dict -}}
  {{- range $hostname, $value := $dependencies -}}

    {{- if not (include "arkcase.tools.checkHostname" $hostname) -}}
      {{- fail (printf "The hostname '%s' is not a valid hostname per RFC-1123" $hostname) -}}
    {{- end -}}

    {{- if or (kindIs "string" $value) (kindIs "int" $value) (kindIs "int64" $value) (kindIs "float64" $value) -}}
      {{- $newPort := (include "arkcase.tools.checkPort" $value) -}}
      {{- if not $newPort -}}
        {{- fail (printf "The port specification [%s] for the initDependency '%s' must either be a valid service spec (from /etc/services) or a port number between 1 and 65535" $value $hostname) -}}
      {{- end -}}
      {{- $value = list $newPort -}}
      {{- /* We keep going b/c the rest of the code will handle things */ -}}
    {{- end -}}

    {{- if $value -}}
      {{- $dependency := dict -}}
      {{- if kindIs "slice" $value -}}
        {{- /* We already know the list isn't empty, we just need to validate the contents */ -}}
        {{- $ports := list -}}
        {{- range $port := $value -}}
          {{- $newPort := (include "arkcase.tools.checkPort" $port) -}}
          {{- if not $newPort -}}
            {{- fail (printf "The port specification [%s] for the initDependency '%s' must either be a valid service spec (from /etc/services) or a port number between 1 and 65535" $port $hostname) -}}
          {{- end -}}
          {{- /* Add the valid port into the ports list */ -}}
          {{- $ports = append $ports $newPort -}}
        {{- end -}}
        {{- /* The contents have been validated and cleaned up, now fill in the rest of it */ -}}
        {{- $dependency = set $dependency "ports" $ports -}}
      {{- else if kindIs "map" $value -}}
        {{- $ports := list -}}
        {{- if $value.ports -}}
          {{- $ports = $value.ports -}}
        {{- end -}}
        {{- if not (kindIs "slice" $ports) -}}
          {{- fail (printf "The 'ports' entry for '%s' must be a list of ports (%s)" $hostname (typeOf $ports)) -}}
        {{- end -}}

        {{- if $ports -}}
          {{- /* Validate the configuration values for this dependency */ -}}
          {{- if hasKey $value "mode" -}}
            {{- $tempVar := ($declaration.mode | toString) -}}
            {{- if and (ne $tempVar "all") (ne $tempVar "any") -}}
              {{- fail (printf "Unknown value for the dependency [%s] tracking mode: [%s] - must be either 'all' or 'any'" $hostname $tempVar) -}}
            {{- end -}}
            {{- $crap := set $dependency "mode" $tempVar -}}
          {{- end -}}

          {{- if hasKey $value "initialDelay" -}}
            {{- $tempVar := ($value.initialDelay | int) -}}
            {{- if lt $tempVar 0 -}}
              {{- $tempVar = 0 -}}
            {{- end -}}
            {{- $crap := set $dependency "initialDelay" $tempVar -}}
          {{- end -}}

          {{- if hasKey $value "delay" -}}
            {{- $tempVar := ($value.delay | int) -}}
            {{- if lt $tempVar 0 -}}
              {{- $tempVar = 0 -}}
            {{- end -}}
            {{- $crap := set $dependency "delay" $tempVar -}}
          {{- end -}}

          {{- if hasKey $value "timeout" -}}
            {{- $tempVar := ($value.timeout | int) -}}
            {{- if lt $tempVar 0 -}}
              {{- $tempVar = 1 -}}
            {{- end -}}
            {{- $crap := set $dependency "attempts" $tempVar -}}
          {{- end -}}

          {{- if hasKey $value "attempts" -}}
            {{- $tempVar := ($value.attempts | int) -}}
            {{- if lt $tempVar 0 -}}
              {{- $tempVar = 1 -}}
            {{- end -}}
            {{- $crap := set $dependency "attempts" $tempVar -}}
          {{- end -}}

          {{- /* We have ports to work upon, so validate them */ -}}
          {{- range $port := $ports -}}
            {{- $newPort := (include "arkcase.tools.checkPort" $port) -}}
            {{- if not $newPort -}}
              {{- fail (printf "The port specification [%s] for the initDependency '%s' must either be a valid service spec (from /etc/services) or a port number between 1 and 65535" $port $hostname) -}}
            {{- end -}}
          {{- end -}}

          {{- $dependency = set $dependency "ports" $ports -}}
        {{- end -}}
      {{- end -}}

      {{- /* If there's a dependency to check, then we add it */ -}}
      {{- if $dependency -}}
        {{- $initDependencies = set $initDependencies $hostname $dependency -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}

  {{- if $initDependencies -}}
    {{- $initDependencies = dict "dependencies" $initDependencies -}}
    {{- $initDependencies = set $initDependencies "mode" $globalMode -}}
    {{- (dict "result" $initDependencies) | toYaml -}}
  {{- else -}}
    {{- (dict "result" "") | toYaml -}}
  {{- end -}}
{{- end -}}

{{- /*
Either render and cache, or fetch the cached rendering of the init dependencies configuration
in JSON format
*/ -}}
{{- define "arkcase.initDependencies.cached" -}}
  {{- $masterCache := dict -}}
  {{- if (hasKey $ "InitDependencies") -}}
    {{- $masterCache = $.InitDependencies -}}
    {{- if and $masterCache (not (kindIs "map" $masterCache)) -}}
      {{- $masterCache = dict -}}
    {{- end -}}
  {{- end -}}
  {{- $crap := set $ "InitDependencies" $masterCache -}}

  {{- $chartName := (include "common.fullname" $) -}}
  {{- if not (hasKey $masterCache $chartName) -}}
    {{- $obj := dict -}}
    {{- $enabled := (and (hasKey .Values "initDependencies") (kindIs "map" .Values.initDependencies) (not (empty .Values.initDependencies)) -}}
    {{- if $enabled -}}
      {{- $enabled = (or (not (hasKey .Values.initDependencies "enabled")) (eq "true" (.Values.initDependencies.enabled | toString | lower))) -}}
    {{- end -}}
    {{- if $enabled -}}
      {{- $obj = get (include "arkcase.initDependencies.render" . | fromYaml) "result" -}}
      {{- if not $obj -}}
        {{- $obj = dict -}}
      {{- end -}}
    {{- end -}}
    {{- $crap := set $masterCache $chartName $obj -}}
  {{- end -}}
  {{- get $masterCache $chartName | toYaml -}}
{{- end -}}

{{- define "arkcase.initDependencies.yaml" -}}
  {{- include "arkcase.initDependencies.cached" . -}}
{{- end -}}

{{- define "arkcase.initDependencies.json" -}}
  {{- include "arkcase.initDependencies.yaml" . | fromYaml | mustToPrettyJson -}}
{{- end -}}

{{- define "arkcase.initDependencies" -}}
  {{- include "arkcase.initDependencies.json" . -}}
{{- end -}}

{{- /*
Render the boot order configuration file to be consumed by the init container
that checks the boot order (remember to |bool the outcome!)
*/ -}}
{{- define "arkcase.hasInitDependencies" -}}
  {{- $yaml := (include "arkcase.initDependencies.yaml" . | fromYaml) -}}
  {{- if $yaml -}}
    {{- true -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.initDependencies.container" -}}
  {{- if not (kindIs "map" .) -}}
    {{- fail "The parameter object must be a dict with a 'ctx' and a 'name' values" -}}
  {{- end -}}
  {{- /* If we're given a parameter map, analyze it */ -}}
  {{- $containerName := "" -}}
  {{- if hasKey . "name" -}}
    {{- $containerName := (.name | toString) -}}
  {{- end -}}
  {{- if not $containerName -}}
    {{- $containerName = "init-dependencies" -}}
  {{- end -}}
  {{- $ctx := . -}}
  {{- if hasKey . "ctx" -}}
    {{- $ctx = .ctx -}}
  {{- else -}}
    {{- $ctx = $ -}}
  {{- end -}}

  {{- if or (not (hasKey $ctx "Values")) (not (hasKey $ctx "Chart")) (not (hasKey $ctx "Release")) -}}
    {{- fail "You must supply the 'ctx' parameter, pointing to the root context that contains 'Values' et al." -}}
  {{- end -}}

  {{- if (include "arkcase.hasInitDependencies" $ctx) -}}
    {{- $yaml := (include "arkcase.initDependencies.yaml" $ctx | fromYaml) -}}
    {{- if $yaml -}}
- name: {{ $containerName | quote }}
  image: {{ include "arkcase.tools.image" (dict "ctx" $ctx "registry" (coalesce (($ctx.Values.image).nettest).registry ($ctx.Values.image).registry) "repository" (coalesce (($ctx.Values.image).nettest).repository "ark_nettest") "tag" (coalesce (($ctx.Values.image).nettest).tag "latest") ) | quote }}
  command: [ "/wait-for-ports" ]
  env: {{- include "arkcase.tools.baseEnv" $ctx | nindent 2 }}
    - name: INIT_DEPENDENCIES
      value: |-
        {{- $yaml | toYaml | nindent 8 }}
    {{- end -}}
  {{- end -}}
{{- end -}}
