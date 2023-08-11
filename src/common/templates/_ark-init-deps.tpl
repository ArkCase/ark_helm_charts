{{- /*
Render the boot order configuration file to be consumed by the init container
that checks the boot order
*/ -}}
{{- define "arkcase.initDependencies.render" -}}
  {{- $declaration := dict -}}
  {{- if hasKey .Values "initDependencies" -}}
    {{- $declaration = $.Values.initDependencies -}}
  {{- end -}}
  {{- if not (kindIs "map" $declaration) -}}
    {{- fail (printf "The .Values.initDependencies value must be a map data structure (%s)" (kindOf $declaration)) -}}
  {{- end -}}

  {{- $cluster := (include "arkcase.cluster" $ | fromYaml) -}}

  {{- $globalMode := "" -}}
  {{- if hasKey $declaration "mode" -}}
    {{- $globalMode = ($declaration.mode | toString | lower) -}}
    {{- if and (ne $globalMode "all") (ne $globalMode "any") -}}
      {{- fail (printf "Unknown value for the general dependency tracking mode: [%s] - must be either 'all' or 'any'" $globalMode) -}}
    {{- end -}}
  {{- end -}}

  {{- $template := dict -}}
  {{- if hasKey $declaration "template" -}}
    {{- $template = $declaration.template -}}
  {{- end -}}
  {{- if not (kindIs "map" $template) -}}
    {{- fail (printf "The .Values.initDependencies.template value must be a map data structure (%s)" (kindOf $template)) -}}
  {{- end -}}

  {{- if hasKey $template "mode" -}}
    {{- $tempVar := ($template.mode | toString | lower) -}}
    {{- if and (ne $tempVar "all") (ne $tempVar "any") -}}
      {{- fail (printf "Unknown value for the dependency template tracking mode: [%s] - must be either 'all' or 'any'" $tempVar) -}}
    {{- end -}}
    {{- $template = set $template "mode" $tempVar -}}
  {{- end -}}

  {{- if hasKey $template "initialDelay" -}}
    {{- $tempVar := ($template.initialDelay | int) -}}
    {{- if lt $tempVar 0 -}}
      {{- $template = set $template "initialDelay" 0 -}}
    {{- end -}}
  {{- end -}}

  {{- if hasKey $template "delay" -}}
    {{- $tempVar := ($template.delay | int) -}}
    {{- if lt $tempVar 0 -}}
      {{- $template = set $template "delay" 1 -}}
    {{- end -}}
  {{- end -}}

  {{- if hasKey $template "timeout" -}}
    {{- $tempVar := ($template.timeout | int) -}}
    {{- if lt $tempVar 0 -}}
      {{- $template = set $template "timeout" 1 -}}
    {{- end -}}
  {{- end -}}

  {{- if hasKey $template "attempts" -}}
    {{- $tempVar := ($template.attempts | int) -}}
    {{- if lt $tempVar 0 -}}
      {{- $template = set $template "attempts" 1 -}}
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

    {{- /* Resolve this hostname to the service's actual hostname. If there's no 'url' or */ -}}
    {{- /* 'hostname' attribute in the requisite section, then keep using the original value */ -}}

    {{- $targetHostName := $hostname -}}
    {{- $targetPort := $value -}}
    {{- $replacement := (include "arkcase.dependency.target" (dict "ctx" $ "hostname" $hostname) | fromYaml) -}}
    {{- if $replacement -}}
      {{- $newHostName := "" -}}
      {{- $portSource := dict -}}
      {{- if (hasKey $replacement "url") -}}
        {{- $url := $replacement.url -}}
        {{- if hasKey $url "host" -}}
          {{- $newHostName = $url.hostname -}}
          {{- $portSource = ((hasKey $url "port") | ternary $url $portSource) -}}
        {{- end -}}
      {{- else -}}
        {{- $newHostName = ((hasKey $replacement "hostname") | ternary ($replacement.hostname | toString) "") -}}
        {{- $portSource = ((hasKey $replacement "port") | ternary $replacement $portSource) -}}
      {{- end -}}

      {{- if and (hasKey $portSource "port") $portSource.port -}}
        {{- if (kindIs "map" $targetPort) -}}
          {{- $targetPort = set $targetPort "ports" (list $portSource.port) -}}
        {{- else -}}
          {{- $targetPort = list $portSource.port -}}
        {{- end -}}
      {{- end -}}

      {{- if $newHostName -}}
        {{- $targetHostName = $newHostName -}}
      {{- end -}}
    {{- end -}}

    {{- if (eq $targetHostName "content-main:8080") -}}
      {{- fail ($replacement | toYaml | nindent 0) -}}
    {{- end -}}

    {{- if not (include "arkcase.tools.checkHostname" $targetHostName) -}}
      {{- if eq $targetHostName $hostname -}}
        {{- fail (printf "The hostname '%s' is not a valid hostname per RFC-1123" $hostname) -}}
      {{- else -}}
        {{- fail (printf "The initDependency '%s' resolves to the invalid hostname '%s' - it's not a valid hostname per RFC-1123" $hostname $targetHostName) -}}
      {{- end -}}
    {{- end -}}

    {{- if or (kindIs "string" $targetPort) (kindIs "int" $targetPort) (kindIs "int64" $targetPort) (kindIs "float64" $targetPort) -}}
      {{- $newPort := (include "arkcase.tools.checkPort" $targetPort) -}}
      {{- if not $newPort -}}
        {{- fail (printf "The port specification [%s] for the initDependency '%s' must either be a valid service spec (from /etc/services) or a port number between 1 and 65535" $targetPort $hostname) -}}
      {{- end -}}
      {{- $targetPort = list $newPort -}}
      {{- /* We keep going b/c the rest of the code will handle things */ -}}
    {{- end -}}

    {{- if $targetPort -}}
      {{- $dependency := dict -}}
      {{- if kindIs "slice" $targetPort -}}
        {{- /* We already know the list isn't empty, we just need to validate the contents */ -}}
        {{- $ports := list -}}
        {{- range $port := $targetPort -}}
          {{- $newPort := (include "arkcase.tools.checkPort" $port) -}}
          {{- if not $newPort -}}
            {{- fail (printf "The port specification [%s] for the initDependency '%s' must either be a valid service spec (from /etc/services) or a port number between 1 and 65535" $port $hostname) -}}
          {{- end -}}
          {{- /* Add the valid port into the ports list */ -}}
          {{- $ports = append $ports ($newPort | atoi) -}}
        {{- end -}}
        {{- /* The contents have been validated and cleaned up, now fill in the rest of it */ -}}
        {{- $dependency = set $dependency "ports" $ports -}}
      {{- else if kindIs "map" $targetPort -}}
        {{- $ports := list -}}
        {{- if $targetPort.ports -}}
          {{- $ports = $targetPort.ports -}}
        {{- end -}}
        {{- if not (kindIs "slice" $ports) -}}
          {{- fail (printf "The 'ports' entry for '%s' must be a list of ports (%s)" $hostname (typeOf $ports)) -}}
        {{- end -}}

        {{- if $ports -}}
          {{- /* Validate the configuration values for this dependency */ -}}
          {{- if hasKey $targetPort "mode" -}}
            {{- $tempVar := ($targetPort.mode | toString | lower) -}}
            {{- if and (ne $tempVar "all") (ne $tempVar "any") -}}
              {{- fail (printf "Unknown value for the dependency [%s] tracking mode: [%s] - must be either 'all' or 'any'" $hostname $tempVar) -}}
            {{- end -}}
            {{- $targetPort = set $dependency "mode" $tempVar -}}
          {{- end -}}

          {{- if hasKey $targetPort "initialDelay" -}}
            {{- $tempVar := ($targetPort.initialDelay | int) -}}
            {{- if lt $tempVar 0 -}}
              {{- $tempVar = 0 -}}
            {{- end -}}
            {{- $crap := set $dependency "initialDelay" $tempVar -}}
          {{- end -}}

          {{- if hasKey $targetPort "delay" -}}
            {{- $tempVar := ($targetPort.delay | int) -}}
            {{- if lt $tempVar 0 -}}
              {{- $tempVar = 0 -}}
            {{- end -}}
            {{- $crap := set $dependency "delay" $tempVar -}}
          {{- end -}}

          {{- if hasKey $targetPort "timeout" -}}
            {{- $tempVar := ($targetPort.timeout | int) -}}
            {{- if lt $tempVar 0 -}}
              {{- $tempVar = 1 -}}
            {{- end -}}
            {{- $crap := set $dependency "attempts" $tempVar -}}
          {{- end -}}

          {{- if hasKey $targetPort "attempts" -}}
            {{- $tempVar := ($targetPort.attempts | int) -}}
            {{- if lt $tempVar 0 -}}
              {{- $tempVar = 1 -}}
            {{- end -}}
            {{- $crap := set $dependency "attempts" $tempVar -}}
          {{- end -}}

          {{- if hasKey $targetPort "clusterOnly" -}}
            {{- $tempVar := (include "arkcase.toBoolean" $targetPort.clusterOnly) -}}
            {{- $crap := set $dependency "clusterOnly" (not (empty $tempVar)) -}}
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

      {{- $onlyInCluster := and (kindIs "map" $targetPort) (hasKey $targetPort "clusterOnly") (not (empty (include "arkcase.toBoolean" $targetPort.clusterOnly))) -}}

      {{- if and $onlyInCluster (not $cluster.enabled) -}}
        {{- /* If we're supposed to skip this dependency when clustering is not in use, we do so */ -}}
        {{- $dependency = dict -}}
      {{- else -}}
        {{- $dependency = omit $dependency "clusterOnly" -}}
      {{- end -}}

      {{- /* If there's a dependency to check, then we add it */ -}}
      {{- if $dependency -}}
        {{- $initDependencies = set $initDependencies $targetHostName $dependency -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}

  {{- if $initDependencies -}}
    {{- $initDependencies = dict "dependencies" $initDependencies -}}
    {{- if $globalMode -}}
      {{- $initDependencies = set $initDependencies "mode" $globalMode -}}
    {{- end -}}
    {{- if $template -}}
      {{- $initDependencies = set $initDependencies "template" $template -}}
    {{- end -}}
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
    {{- $enabled := (and (hasKey .Values "initDependencies") (kindIs "map" .Values.initDependencies) (not (empty .Values.initDependencies))) -}}
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
  {{- $result := get $masterCache $chartName -}}
  {{- $partname := (include "arkcase.part.name" .) -}}
  {{- if or (hasKey $result "common") (and $partname (hasKey $result $partname)) -}}
    {{- include "arkcase.values" (dict "ctx" . "base" $result) -}}
  {{- else -}}
    {{- $result | toYaml -}}
  {{- end -}}
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

  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "You must supply the 'ctx' parameter, pointing to the root context that contains 'Values' et al." -}}
  {{- end -}}

  {{- if (include "arkcase.hasInitDependencies" $ctx) -}}
    {{- $yaml := (include "arkcase.initDependencies.yaml" $ctx | fromYaml) -}}
    {{- if $yaml -}}
- name: {{ $containerName | quote }}
  {{- include "arkcase.image" (dict "ctx" $ctx "name" "nettest" "repository" "arkcase/nettest") | nindent 2 }}
  command: [ "/wait-for-ports" ]
  env: {{- include "arkcase.tools.baseEnv" $ctx | nindent 4 }}
    - name: INIT_DEPENDENCIES
      value: |- {{- $yaml | toYaml | nindent 8 }}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{- /* Will return a YAML map with either "url" (dict), or "host" (string) and "port" (int) entries */ -}}
{{- /* If the "url" member is present, neither "host" nor "port" will be present. */ -}}
{{- /* If either of the "host" or "port" members are present, then the "url" member will not be present */ -}}
{{- /* The map may empty, indicating that there is no override value */ -}}
{{- define "arkcase.dependency.target" -}}
  {{- $ctx := $.ctx -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "You must supply the 'ctx' parameter, pointing to the root context that contains 'Values' et al." -}}
  {{- end -}}

  {{- $hostname := $.hostname -}}
  {{- if or (not $hostname) (not (kindIs "string" $hostname)) -}}
    {{- fail (printf "You must supply a string value for the 'hostname' parameter (%s)" (kindOf $hostname)) -}}
  {{- end -}}

  {{- $global := (include "arkcase.tools.get" (dict "ctx" $ctx "name" (printf "Values.global.conf.%s" $hostname)) | fromYaml) -}}
  {{- $local := (include "arkcase.tools.get" (dict "ctx" $ctx "name" (printf "Values.configuration.%s" $hostname)) | fromYaml) -}}

  {{- $result := dict -}}
  {{- range $replacement := (list $global $local) -}}
    {{- if and (empty $result) $replacement $replacement.found (kindIs "map" $replacement.value) -}}
      {{- if (hasKey $replacement.value "url") -}}
        {{- $url := (include "arkcase.tools.parseUrl" ($replacement.value.url | toString) | fromYaml) -}}
        {{- if $url -}}
          {{- $result = dict "url" $url -}}
        {{- end -}}
      {{- else if or (hasKey $replacement.value "hostname") (hasKey $replacement.value "port") -}}
        {{- $newHostName := "" -}}
        {{- $newPort := 0 -}}
        {{- if (hasKey $replacement.value "hostname") -}}
          {{- $newHostName = ($replacement.value.hostname | toString) -}}
          {{- if $newHostName -}}
            {{- $result = set $result "host" $newHostName -}}
          {{- end -}}
        {{- end -}}
        {{- if (hasKey $replacement.value "port") -}}
          {{- $newPort = (include "arkcase.tools.checkNumericPort" $replacement.value.port | atoi) -}}
          {{- if $newPort -}}
            {{- $result = set $result "port" $newPort -}}
          {{- end -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
  {{- $result | toYaml -}}
{{- end -}}
