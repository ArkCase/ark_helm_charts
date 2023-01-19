{{- /*
Render the boot order configuration file to be consumed by the init container
that checks the boot order
*/ -}}
{{- define "arkcase.initDependencies.render" -}}
  {{- $declaration := dict -}}
  {{- if .Values.initDependencies -}}
    {{- $declaration = .Values.initDependencies -}}
  {{- end -}}
  {{- if not (kindIs "map" $declaration) -}}
    {{- fail (printf "The .Values.initDependencies value must be a map data structure (%s)" (kindOf $declaration)) -}}
  {{- end -}}

  {{- $globalMode := (coalesce $declaration.mode "all" | toString | lower) -}}
  {{- if and (ne $globalMode "all") (ne $globalMode "any") -}}
    {{- fail (printf "Unknown value for the general dependency tracking mode: [%s] - must be either 'all' or 'any'" $globalMode) -}}
  {{- end -}}

  {{- $template := dict -}}
  {{- if $declaration.template -}}
    {{- $template = $declaration.template -}}
  {{- end -}}
  {{- if not (kindIs "map" $template) -}}
    {{- fail (printf "The .Values.initDependencies.template value must be a map data structure (%s)" (kindOf $template)) -}}
  {{- end -}}

  {{- $templateMode := (coalesce $template.mode "all" | toString | lower) -}}
  {{- if and (ne $templateMode "all") (ne $templateMode "any") -}}
    {{- fail (printf "Unknown value for the port template tracking mode: [%s] - must be either 'all' or 'any'" $templateMode) -}}
  {{- end -}}

  {{- $templateInitialDelay :=  (include "arkcase.tools.mustInt" (coalesce $template.initialDelay 0) | int) -}}
  {{- if lt $templateInitialDelay 0 -}}
    {{- $templateInitialDelay = 0 -}}
  {{- end -}}

  {{- $templateDelay :=  (include "arkcase.tools.mustInt" (coalesce $template.delay 5) | int) -}}
  {{- if lt $templateDelay 0 -}}
    {{- $templateDelay = 0 -}}
  {{- end -}}

  {{- $templateTimeout := (include "arkcase.tools.mustInt" (coalesce $template.timeout 5) | int) -}}
  {{- if le $templateTimeout 0 -}}
    {{- $templateTimeout = 5 -}}
  {{- end -}}

  {{- $templateAttempts := (include "arkcase.tools.mustInt" (coalesce $template.attempts 3) | int) -}}
  {{- if le $templateAttempts 0 -}}
    {{- $templateAttempts = 3 -}}
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
        {{- $dependency = set $dependency "mode" $templateMode -}}
        {{- $dependency = set $dependency "initialDelay" $templateInitialDelay -}}
        {{- $dependency = set $dependency "delay" $templateDelay -}}
        {{- $dependency = set $dependency "timeout" $templateTimeout -}}
        {{- $dependency = set $dependency "attempts" $templateAttempts -}}
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
          {{- /* We have ports to work upon, so validate them */ -}}

          {{- /* First, validate the general values... */ -}}
          {{- $mode := (coalesce $value.mode $templateMode "all" | toString) -}}
          {{- if and (ne $mode "all") (ne $mode "any") -}}
            {{- fail (printf "Unknown value for the '%s' dependency tracking mode: [%s]" $hostname $mode) -}}
          {{- end -}}
          {{- $initialDelay := (include "arkcase.tools.mustInt" (coalesce $value.initialDelay $templateInitialDelay) | int) -}}
          {{- if lt $initialDelay 0 -}}
            {{- $initialDelay = 0 -}}
          {{- end -}}
          {{- $delay := (include "arkcase.tools.mustInt" (coalesce $value.delay $templateDelay) | int) -}}
          {{- if lt $delay 0 -}}
            {{- $delay = 0 -}}
          {{- end -}}
          {{- $timeout := (include "arkcase.tools.mustInt" (coalesce $value.timeout $templateTimeout) | int) -}}
          {{- if lt $timeout 0 -}}
            {{- $timeout = 0 -}}
          {{- end -}}
          {{- $attempts := (include "arkcase.tools.mustInt" (coalesce $value.attempts $templateAttempts) | int) -}}
          {{- if lt $attempts 0 -}}
            {{- $attempts = 0 -}}
          {{- end -}}
  
          {{- range $port := $ports -}}
            {{- $newPort := (include "arkcase.tools.checkPort" $port) -}}
            {{- if not $newPort -}}
              {{- fail (printf "The port specification [%s] for the initDependency '%s' must either be a valid service spec (from /etc/services) or a port number between 1 and 65535" $port $hostname) -}}
            {{- end -}}
          {{- end -}}
  
          {{- /* Add the sanitized values */ -}}
          {{- $dependency = set $dependency "mode" $mode -}}
          {{- $dependency = set $dependency "initialDelay" $initialDelay -}}
          {{- $dependency = set $dependency "delay" $delay -}}
          {{- $dependency = set $dependency "timeout" $timeout -}}
          {{- $dependency = set $dependency "attempts" $attempts -}}
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
    {{- $initDependencies = dict "hosts" $initDependencies -}}
    {{- $initDependencies = set $initDependencies "mode" $globalMode -}}
    {{- $initDependencies | mustToPrettyJson -}}
  {{- end -}}
{{- end -}}

{{- /*
Either render and cache, or fetch the cached rendering of the init dependencies configuration
in JSON format
*/ -}}
{{- define "arkcase.initDependencies" -}}
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
    {{- $crap := set $masterCache $chartName (include "arkcase.initDependencies.render" .) -}}
  {{- end -}}
  {{- (get $masterCache $chartName) -}}
{{- end -}}

{{- /*
Render the boot order configuration file to be consumed by the init container
that checks the boot order (remember to |bool the outcome!)
*/ -}}
{{- define "arkcase.hasDependencies" -}}
  {{- $json := (include "arkcase.initDependencies" .) -}}
  {{- if $json -}}
    {{- true -}}
  {{- else -}}
    {{- false -}}
  {{- end -}}
{{- end -}}
