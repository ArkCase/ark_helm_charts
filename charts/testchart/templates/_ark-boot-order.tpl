{{- /*
Render the boot order configuration file to be consumed by the init container
that checks the boot order
*/ -}}
{{- define "arkcase.initDependencies" -}}
  {{- $declaration := (coalesce .Values.initDependencies dict) -}}
  {{- if not (kindIs "map" $declaration) -}}
    {{- fail "The .Values.initDependencies value must be a map data structure" -}}
  {{- end -}}

  {{- $globalDelay := (coalesce $declaration.delay 5 | int) -}}
  {{- if lt $globalDelay 0 -}}
    {{- $globalDelay = 0 -}}
  {{- end -}}

  {{- $globalTimeout := (coalesce $declaration.timeout 5 | int) -}}
  {{- if le $globalTimeout 0 -}}
    {{- $globalTimeout = 5 -}}
  {{- end -}}

  {{- $globalAttempts := (coalesce $declaration.attempts 3 | int) -}}
  {{- if le $globalAttempts 0 -}}
    {{- $globalAttempts = 3 -}}
  {{- end -}}

  {{- $globalMode := (coalesce $declaration.mode "all" | toString | lower) -}}
  {{- if and (ne $globalMode "all") (ne $globalMode "any") -}}
    {{- fail (printf "Unknown value for the general dependency tracking mode: [%s]" $globalMode) -}}
  {{- end -}}

  {{- $dependencies := (coalesce $declaration.dependencies dict) -}}
  {{- if not (kindIs "map" $declaration) -}}
    {{- fail "The .Values.initDependencies.dependencies value must be a map data structure" -}}
  {{- end -}}

  {{- $initDependencies := dict -}}
  {{- range $hostname, $value := $dependencies -}}
    {{- $valueKind := (kindOf $value) -}}

    {{- if eq "string" $valueKind -}}
      {{- /* If the value is a string, then it gets coerced as an int */ -}}
      {{- $value = ($value | int) -}}
      {{- /* We keep going b/c the int checker will validate the value */ -}}
      {{- $valueKind = "int" -}}
    {{- end -}}

    {{- if eq "int" $valueKind -}}
      {{- /* If the value is an int, then it must be between 1 and 65535 */ -}}
      {{- if or (lt $value 1) (gt $value 65535) -}}
        {{- fail (printf "The port number for the initDependency '%s' must be between 1 and 65535 (%d)" $hostname $value) -}}
      {{- end -}}
      {{- /* We keep going b/c the rest of the code will handle things */ -}}
      {{- $value = list $value -}}
      {{- $valueKind = "list" -}}
    {{- end -}}

    {{- if $value -}}
      {{- $dependency := dict -}}
      {{- if eq "list" $valueKind -}}
        {{- /* We already know the list isn't empty, we just need to validate the contents */ -}}
        {{- $ports := list -}}
        {{- range $port := $value -}}
          {{- if kindIs "string" $port -}}
            {{- $port = ($port | int) -}}
          {{- end -}}
          {{- if kindIs "int" $port -}}
            {{- if or (lt $port 1) (gt $port 65535) -}}
              {{- fail (printf "The port number for the initDependency '%s' must be between 1 and 65535 (%d)" $hostname $port) -}}
            {{- end -}}
            {{- /* Add the valid port into the ports list */ -}}
            {{- $ports = append $ports $port -}}
          {{- else -}}
            {{- fail (printf "The port number for the initDependency '%s' must be a number (in string or value form) between 1 and 65535, not a %s (%s)" $hostname (typeOf $port) $port) -}}
          {{- end -}}
        {{- end -}}
        {{- /* The contents have been validated and cleaned up, now fill in the rest of it */ -}}
        {{- $dependency = set $dependency "mode" $globalMode -}}
        {{- $dependency = set $dependency "delay" $globalDelay -}}
        {{- $dependency = set $dependency "timeout" $globalTimeout -}}
        {{- $dependency = set $dependency "attempts" $globalAttempts -}}
        {{- $dependency = set $dependency "ports" $ports -}}
      {{- else if eq "map" $valueKind -}}
        {{- $ports := (coalesce $value.ports list) -}}
        {{- if not (kindIs "list" $ports) -}}
          {{- fail "The 'ports' entry for '%s' must be a list of ports (%s)" $hostname (typeOf $ports) -}}
        {{- end -}}

        {{- if $ports -}}
          {{- /* We have ports to work upon, so validate them */ -}}

          {{- /* First, validate the general values... */ -}}
          {{- $mode = (coalesce $value.mode $globalMode "all" | toString) -}}
          {{- if and (ne $mode "all") (ne $mode "any") -}}
            {{- fail (printf "Unknown value for the '%s' dependency tracking mode: [%s]" $hostname $mode) -}}
          {{- end -}}
          {{- $delay = (coalesce $value.delay $globalDelay 5 | int) -}}
          {{- if lt $delay 0 -}}
            {{- $delay = 0 -}}
          {{- end -}}
          {{- $timeout = (coalesce $value.timeout $globalTimeout 5 | int) -}}
          {{- if lt $timeout 0 -}}
            {{- $timeout = 0 -}}
          {{- end -}}
          {{- $attempts = (coalesce $value.attempts $globalAttempts 3 | int) -}}
          {{- if lt $attempts 0 -}}
            {{- $attempts = 0 -}}
          {{- end -}}
  
          {{- range $port := $ports -}}
            {{- if kindIs "string" $port -}}
              {{- $port = ($port | int) -}}
            {{- end -}}
            {{- if kindIs "int" $port -}}
              {{- if or (lt $port 1) (gt $port 65535) -}}
                {{- fail (printf "The port number for the initDependency '%s' must be between 1 and 65535 (%d)" $hostname $port) -}}
              {{- end -}}
            {{- else -}}
              {{- fail (printf "The port number for the initDependency '%s' must be a number (in string or value form) between 1 and 65535, not a %s (%s)" $hostname (typeOf $port) $port) -}}
            {{- end -}}
          {{- end -}}
  
          {{- /* Add the sanitized values */ -}}
          {{- $dependency = set $dependency "mode" $mode -}}
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

  {{- $initDependencies | mustToPrettyJson -}}
{{- end -}}
