{{- /*
Return a map which contains the subsystem data map as required by other API calls:

   data:
     ctx: .ctx
     name: $subsystemName
     enabled: true|false

*/ -}}
{{- define "arkcase.subsystem" -}}
  {{- $ctx := $ -}}
  {{- $subsysName := "" -}}
  {{- $value := "" -}}
  {{- if hasKey $ctx "Values" -}}
    {{- /* we're fine, we're auto-detecting */ -}}
  {{- else if and (hasKey $ctx "subsystem") (hasKey $ctx "ctx") -}}
    {{- $subsysName = (toString $ctx.subsystem) -}}
    {{- /* Does it also have a value specification? */ -}}
    {{- if (hasKey $ctx "value") -}}
      {{- $value = (toString $ctx.value | required "The 'value' parameter may not be the empty string") -}}
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
      {{- $subsysName = .Chart.Name -}}
      {{- $marker := set $ctx "arkcase-subsystem" $subsysName -}}
    {{- end -}}
  {{- end -}}

  {{- /* Start structuring our return value */ -}}
  {{- $map := (dict "ctx" $ctx "name" $subsysName) -}}

  {{- /* Cache the information */ -}}
  {{- $subsys := dict -}}
  {{- $cacheKey := "ArkCase-Subsystem" -}}
  {{- if (hasKey $ctx $cacheKey) -}}
    {{- $subsys = get $ctx $cacheKey -}}
  {{- else -}}
    {{- $crap := set $ctx $cacheKey $subsys -}}
  {{- end -}}

  {{- $data := dict -}}
  {{- if (hasKey $subsys $subsysName) -}}
    {{- /* Retrieve the cached data */ -}}
    {{- $data = get $subsys $subsysName -}}
  {{- else -}}
    {{- /* Set the "enabled" flag, which defaults to TRUE if it's not set */ -}}
    {{- $enabled := true -}}
    {{- if (hasKey $ctx.Values "enabled") -}}
      {{- $enabled = $ctx.Values.enabled -}}
    {{- end -}}
    {{- if not (kindIs "bool" $enabled) -}}
      {{- $enabled = (eq "true" (toString $enabled | lower)) -}}
    {{- end -}}
    {{- $crap := set $data "enabled" $enabled -}}

    {{- /* Cache the computed data */ -}}
    {{- $crap = set $subsys $subsysName $data -}}
  {{- end -}}
  {{- $crap := set $map "data" $data -}}

  {{- $map | toYaml -}}
{{- end -}}

{{- /*
Identify the subsystem being used

Parameter: "optional" (not used)
*/ -}}
{{- define "arkcase.subsystem.name" -}}
  {{- get (include "arkcase.subsystem" . | fromYaml) "name" -}}
{{- end -}}

{{- /*
Check whether a subsystem is enabled for provisioning, but not for external service.

Parameter: either the root context (i.e. "." or "$"), or
           a dict with two keys:
             - ctx = the root context (either "." or "$")
             - subsystem = a string with the name of the subsystem to query
*/ -}}
{{- define "arkcase.subsystem.enabled" -}}
  {{- $map := (include "arkcase.subsystem" . | fromYaml) -}}
  {{- if (and ($map.data.enabled) (not (($map.ctx.Values.service).external))) -}}
    {{- true -}}
  {{- end -}}
{{- end -}}

{{- /*
Check whether a subsystem is enabled for provisioning, or for external service.

Parameter: either the root context (i.e. "." or "$"), or
           a dict with two keys:
             - ctx = the root context (either "." or "$")
             - subsystem = a string with the name of the subsystem to query
*/ -}}
{{- define "arkcase.subsystem.enabledOrExternal" }}
  {{- $map := (include "arkcase.subsystem" $ | fromYaml) }}
  {{- $data := ($map.ctx.Values.service | default dict) }}
  {{- $external := (include "arkcase.subsystem.external" $) -}}
  {{- if or ($map.data.enabled) $external }}
    {{- true }}
  {{- end }}
{{- end }}

{{- define "arkcase.subsystem.external" -}}
  {{- $property := (printf "%s.url" (include "arkcase.name" $)) -}}
  {{- $url := (include "arkcase.tools.conf" (dict "ctx" $ "value" $property "detailed" true) | fromYaml) -}}
  {{- if and $url $url.global -}}
    {{- true -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.service.name" }}
  {{- include "arkcase.name" $ -}}
{{- end -}}

{{- define "arkcase.service.headless" }}
  {{- $cluster := (include "arkcase.cluster" $ | fromYaml) -}}
  {{- $name := (include "arkcase.service.name" $) -}}
  {{- $cluster.enabled | ternary (printf "%s-dns" $name) $name -}}
{{- end -}}

{{- define "arkcase.subsystem.service.render" -}}
  {{- $ctx := $.ctx -}}
  {{- $data := $.data -}}
  {{- $global := $.global -}}
  {{- if (include "arkcase.subsystem.enabledOrExternal" $ctx) -}}
    {{- $external := (coalesce $data.external $ctx.Values.service.external "") -}}
    {{- $ports := (coalesce $data.ports list) -}}
    {{- $type := (coalesce $data.type "ClusterIP") -}}
    {{- $enableDebug := false -}}
    {{- if (include "arkcase.toBoolean" $data.canDebug) -}}
      {{- $dev := (include "arkcase.dev" $ctx | fromYaml) -}}
      {{- $enableDebug = and (not (empty $dev)) (not (empty $dev.debug)) -}}
    {{- end -}}
    {{- $cluster := (include "arkcase.cluster" $ctx | fromYaml) -}}
    {{- if and (empty $ports) (not $external) -}}
      {{- fail (printf "No ports are defined for chart %s, and no external server was given" (include "common.name" $ctx)) -}}
    {{- end -}}
    {{- $name := (include "arkcase.name" $ctx) -}}
    {{- $overrides := (include "arkcase.subsystem.service.global" $ctx | fromYaml) -}}
    {{- if hasKey $overrides $name -}}
      {{- $overrides = get $overrides $name -}}
    {{- else -}}
      {{- $overrides = dict -}}
    {{- end -}}
    {{- if and (hasKey $overrides "type") ($overrides.type) -}}
      {{- $type = $overrides.type -}}
    {{- end -}}
    {{- $serviceName := (include "arkcase.service.name" $ctx) -}}
    {{- $headlessName := (include "arkcase.service.headless" $ctx) -}}
    {{- if not $external -}}
      {{- if ne $serviceName $headlessName }}
---
apiVersion: v1
kind: Service
metadata:
  name: {{ $headlessName | quote }}
  namespace: {{ $ctx.Release.Namespace | quote }}
  labels: {{- include "arkcase.labels" $ctx | nindent 4 }}
    {{- with $ctx.Values.labels }}
      {{- toYaml . | nindent 4 }}
    {{- end }}
    {{- with $data.labels }}
      {{- toYaml . | nindent 4 }}
    {{- end }}
    {{- with $overrides.labels }}
      {{- toYaml . | nindent 4 }}
    {{- end }}
  annotations:
    {{- with $ctx.Values.annotations }}
      {{- toYaml . | nindent 4 }}
    {{- end }}
    {{- with $data.annotations }}
      {{- toYaml . | nindent 4 }}
    {{- end }}
    {{- with $overrides.annotations }}
      {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  publishNotReadyAddresses: true
  type: "ClusterIP"
  clusterIP: "None"
  ports:
          {{- if (empty $ports) }}
            {{- fail (printf "There are no ports defined for the %s service" $serviceName) }}
          {{- end }}
          {{- $portOverrides := ($overrides.ports | default dict) -}}
          {{- range $ports }}
    - name: {{ (required "Port specifications must contain a name" .name) | quote }}
      protocol: {{ coalesce .protocol "TCP" }}
      port: {{ required (printf "Port [%s] doesn't have a port number" .name) .port }}
            {{- if .targetPort }}
      targetPort: {{ int .targetPort }}
            {{- end }}
          {{- end }}
  selector: {{- include "arkcase.labels.matchLabels.service" $ctx | nindent 4 }}
        {{- end }}
      {{- end }}
---
apiVersion: v1
kind: Service
metadata:
  name: {{ $serviceName | quote }}
  namespace: {{ $ctx.Release.Namespace | quote }}
  labels: {{- include "arkcase.labels" $ctx | nindent 4 }}
    {{- with $ctx.Values.labels }}
      {{- toYaml . | nindent 4 }}
    {{- end }}
    {{- with $data.labels }}
      {{- toYaml . | nindent 4 }}
    {{- end }}
    {{- with $overrides.labels }}
      {{- toYaml . | nindent 4 }}
    {{- end }}
  annotations:
    {{- with $ctx.Values.annotations }}
      {{- toYaml . | nindent 4 }}
    {{- end }}
    {{- with $data.annotations }}
      {{- toYaml . | nindent 4 }}
    {{- end }}
    {{- with $overrides.annotations }}
      {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  publishNotReadyAddresses: {{ $enableDebug }}
    {{- if or (not $external) (include "arkcase.tools.isIp" $external) }}
  # This is either an internal service, or an external service using an IP address
  type: {{ coalesce $type "ClusterIP" }}
  {{- if (eq $type "LoadBalancer") }}
    {{- with $overrides.loadBalancerClass }}
  loadBalancerClass: {{ . | quote }}
    {{- end }}
    {{- with $overrides.loadBalancerIP }}
  loadBalancerIP: {{ . | quote }}
    {{- end }}
    {{- if (hasKey $overrides "allocateNodePorts") }}
  allocateLoadBalancerNodePorts: {{ $overrides.allocateNodePorts }}
    {{- end }}
  {{- end }}
  ports:
      {{- if (empty $ports) }}
        {{- fail (printf "There are no ports defined for the %s service" $serviceName) }}
      {{- end }}
      {{- $portOverrides := ($overrides.ports | default dict) -}}
      {{- range $ports }}
    - name: {{ (required "Port specifications must contain a name" .name) | quote }}
      protocol: {{ coalesce .protocol "TCP" }}
      port: {{ required (printf "Port [%s] doesn't have a port number" .name) .port }}
        {{- if .targetPort }}
      targetPort: {{ int .targetPort }}
        {{- end }}
        {{- if (eq $type "NodePort") }}
          {{- $nodePort := coalesce ((hasKey $portOverrides .name) | ternary (get $portOverrides .name) 0) (.nodePort | default 0) }}
          {{- if $nodePort }}
      nodePort: {{ int $nodePort }}
          {{- end }}
        {{- end }}
      {{- end }}
  selector: {{- include "arkcase.labels.matchLabels.service" $ctx | nindent 4 }}
    {{- else }}
  # This is an external service, but using a hostname. This will cause a CNAME to
  # be created to route service requests to the external hostname
  type: ExternalName
  externalName: {{ include "arkcase.tools.mustSingleHostname" $external | quote }}
    {{- end }}

    {{- if and ($external) (include "arkcase.tools.isIp" $external) }}
---
# This is an external service to an IP address. We MUST create an endpoint
# with the same name as the service, and this will cause the Kubernetes mesh
# to proxy connections to the given IP+ports
apiVersion: v1
kind: Endpoints
metadata:
  name: {{ include "arkcase.name" $ctx | quote }}
  namespace: {{ $ctx.Release.Namespace | quote }}
  labels: {{- include "arkcase.labels" $ctx | nindent 4 }}
      {{- with $ctx.Values.labels }}
        {{- toYaml . | nindent 4 }}
      {{- end }}
      {{- with $data.labels }}
        {{- toYaml . | nindent 4 }}
      {{- end }}
  annotations:
      {{- with $ctx.Values.annotations }}
        {{- toYaml . | nindent 4 }}
      {{- end }}
      {{- with $data.annotations }}
        {{- toYaml . | nindent 4 }}
      {{- end }}
subsets:
  - addresses:
      {{- if (kindIs "string" $external) }}
        {{- $external = (splitList "," $external) }}
      {{- end }}
      {{- range (sortAlpha $external | uniq | compact) }}
      - ip: {{ . }}
      {{- end }}
    ports:
      {{- range $ports }}
      - name: {{ (required "Port specifications must contain a name" .name) | quote }}
        protocol: {{ coalesce .protocol "TCP" }}
        port: {{ required (printf "Port [%s] doesn't have a port number" .name) .port }}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.subsystem.service.parseType" -}}
  {{- $type := (kindIs "string" .) | ternary . (. | toString) | default "ClusterIP" | lower -}}
  {{- if or (eq "np" $type) (eq "nodeport" $type) -}}
    {{- $type = "NodePort" -}}
  {{- else if or (eq "lb" $type) (eq "loadbalancer" $type) -}}
    {{- $type = "LoadBalancer" -}}
  {{- else if or (eq "def" $type) (eq "default" $type) (eq "clusterip" $type) -}}
    {{- $type = "ClusterIP" -}}
  {{- else -}}
    {{- fail (printf "Unrecognized service type: [%s]" .) -}}
  {{- end -}}
  {{- $type -}}
{{- end -}}

{{- define "arkcase.subsystem.service.global.compute" -}}
  {{- $ctx := . }}
  {{- if hasKey . "ctx" -}}
    {{- $ctx = .ctx -}}
  {{- end -}}

  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "Incorrect context given - either submit the root context as the only parameter, or a 'ctx' parameter pointing to it" -}}
  {{- end -}}

  {{- $globalService := (($ctx.Values.global).service | default dict) -}}
  {{- if or (not $globalService) (not (kindIs "map" $globalService)) -}}
    {{- $globalService = dict -}}
  {{- end -}}

  {{- $result := dict -}}
  {{- range $name, $service := $globalService -}}
    {{- /* TODO: validate the name as a valid RFC-1123 hostname part */ -}}
    {{- $n := (include "arkcase.tools.hostnamePart" $name) -}}
    {{- if not $n -}}
      {{- fail (printf "The service name [%s] (in global.service) is not valid" $name) -}}
    {{- end -}}

    {{- $s := dict -}}
    {{- if (kindIs "string" $service) -}}
      {{- /* May only be one of: (NodePort|NP|LoadBalancer|LB|def|default|ClusterIP|"") */ -}}
      {{- $s = set $s "type" (include "arkcase.subsystem.service.parseType" $service) -}}
      {{- $s = set $s "ports" dict -}}
    {{- else if (kindIs "map" $service) -}}
      {{- $s = set $s "type" (include "arkcase.subsystem.service.parseType" ($service.type | default "")) -}}
      {{- if (eq "LoadBalancer" $s.type) -}}
        {{- $loadBalancerIP := ($service.loadBalancerIP | default "" | toString) -}}
        {{- if (include "arkcase.tools.checkIp" $loadBalancerIP) -}}
          {{- $s = set $s "loadBalancerIP" $loadBalancerIP -}}
        {{- else if $loadBalancerIP -}}
          {{- fail (printf "The value global.service.%s.loadBalancerIP is not valid: %s" $name $loadBalancerIP) -}}
        {{- end -}}

        {{- $loadBalancerClass := ($service.loadBalancerClass | default "" | toString) -}}
        {{- if (include "arkcase.tools.hostnamePart" $loadBalancerClass) -}}
          {{- $s = set $s "loadBalancerClass" $loadBalancerClass -}}
        {{- else if $loadBalancerClass -}}
          {{- fail (printf "The value global.service.%s.loadBalancerClass is not valid: %s" $name $loadBalancerClass) -}}
        {{- end -}}

        {{- if hasKey $service "allocateNodePorts" -}}
          {{- $allocateNodePorts := get $service "allocateNodePorts" -}}
          {{- if not (kindIs "bool" $allocateNodePorts) -}}
            {{- $allocateNodePorts = $allocateNodePorts | toString -}}
            {{- if or (eq "true" $allocateNodePorts) (eq "false" $allocateNodePorts) -}}
              {{- $allocateNodePorts = (eq "true" $allocateNodePorts) -}}
            {{- else -}}
              {{- fail (printf "The value global.service.%s.allocateNodePorts is not valid - must be either 'true' or 'false': [%s]" $name $allocateNodePorts) -}}
            {{- end -}}
          {{- end -}}
          {{- $s = set $s "allocateNodePorts" $allocateNodePorts -}}
        {{- end -}}
      {{- else if (eq "NodePort" $s.type) -}}
        {{- $ports := ($service.ports | default dict) -}}
        {{- if not (kindIs "map" $ports) -}}
          {{- $ports = dict -}}
        {{- end -}}
        {{- $finalPorts := dict -}}
        {{- range $port, $nodePort := $ports -}}
          {{- $p := (include "arkcase.tools.hostnamePart" $port) -}}
          {{- if not $p -}}
            {{- fail (printf "The port name [%s] in the value global.service.%s.ports is not valid" $port $name) -}}
          {{- end -}}
          {{- $np := ($nodePort | default "" | toString) -}}
          {{- if not (regexMatch "^[1-9][0-9]*$" $np) -}}
            {{- fail (printf "Invalid port number given for global.service.%s.ports.%s: [%s]" $name $port $nodePort) -}}
          {{- end -}}
          {{- $np = (atoi $np) -}}
          {{- if and $np (ge $np 1) (le $np 65535) -}}
            {{- $finalPorts = set $finalPorts $p $np -}}
          {{- else -}}
            {{- fail (printf "Invalid port number for global.service.%s.ports.%s - out of range [1..65535]: [%d]" $name $port $np) -}}
          {{- end -}}
        {{- end -}}
        {{- $s = set $s "ports" $finalPorts -}}
      {{- end -}}

      {{- if hasKey $service "labels" -}}
        {{- $labels := $service.labels -}}
        {{- if and $labels (not (kindIs "map" $labels)) -}}
          {{- fail (printf "The value global.service.%s.labels must be a map (it's a %s)" $name (kindOf $labels)) -}}
        {{- else if $labels -}}
          {{- $a := dict -}}
          {{- range $k, $v := $labels -}}
            {{- $a = set $a ($k | toString) ($v | toString) -}}
          {{- end -}}
          {{- $labels = $a -}}
        {{- else -}}
          {{- $labels = dict -}}
        {{- end -}}
        {{- $s = set $s "labels" $labels -}}
      {{- else -}}
        {{- $s = set $s "labels" dict -}}
      {{- end -}}

      {{- if hasKey $service "annotations" -}}
        {{- $annotations := $service.annotations -}}
        {{- if and $annotations (not (kindIs "map" $annotations)) -}}
          {{- fail (printf "The value global.service.%s.annotations must be a map (it's a %s)" $name (kindOf $annotations)) -}}
        {{- else if $annotations -}}
          {{- $a := dict -}}
          {{- range $k, $v := $annotations -}}
            {{- $a = set $a ($k | toString) ($v | toString) -}}
          {{- end -}}
          {{- $annotations = $a -}}
        {{- else -}}
          {{- $annotations = dict -}}
        {{- end -}}
        {{- $s = set $s "annotations" $annotations -}}
      {{- else -}}
        {{- $s = set $s "annotations" dict -}}
      {{- end -}}
    {{- else -}}
      {{- fail (printf "The value global.service.%s must be either a string or a map (%s)" $name (kindOf $service)) -}}
    {{- end -}}
    {{- /* add to the return value */ -}}
    {{- $result = set $result $n $s -}}
  {{- end -}}
  {{- $result | toYaml -}}
{{- end -}}

{{- define "arkcase.subsystem.service.global" -}}
  {{- $ctx := . -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The parameter given must be the root context (. or $)" -}}
  {{- end -}}

  {{- $cacheKey := "ArkCase-GlobalServiceOverrides" -}}
  {{- $masterCache := dict -}}
  {{- if (hasKey $ctx $cacheKey) -}}
    {{- $masterCache = get $ctx $cacheKey -}}
    {{- if and $masterCache (not (kindIs "map" $masterCache)) -}}
      {{- $masterCache = dict -}}
    {{- end -}}
  {{- end -}}
  {{- $ctx = set $ctx $cacheKey $masterCache -}}

  {{- $masterKey := $ctx.Release.Name -}}
  {{- $yamlResult := dict -}}
  {{- if not (hasKey $masterCache $masterKey) -}}
    {{- $yamlResult = (include "arkcase.subsystem.service.global.compute" $ctx) -}}
    {{- $masterCache = set $masterCache $masterKey ($yamlResult | fromYaml) -}}
  {{- else -}}
    {{- $yamlResult = get $masterCache $masterKey | toYaml -}}
  {{- end -}}
  {{- $yamlResult -}}
{{- end -}}

{{- /*
Render subsystem service declarations based on whether an external host declaration is provided or not

Parameter: the root context (i.e. "." or "$")
*/ -}}
{{- define "arkcase.subsystem.service" }}
  {{- $partname := (include "arkcase.part.name" $) -}}
  {{- $ctx := $ }}
  {{- if hasKey $ "ctx" -}}
    {{- $ctx = $.ctx -}}
    {{- if hasKey $ "subname" -}}
      {{- $partname = (.subname | toString | lower) -}}
    {{- end -}}
  {{- end -}}

  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "Incorrect context given - either submit the root context as the only parameter, or a 'ctx' parameter pointing to it" -}}
  {{- end -}}

  {{- if (include "arkcase.subsystem.enabledOrExternal" $ctx) }}
    {{- /* Gather the global ports */ -}}
    {{- $service := pick $ctx.Values.service "ports" "type" "probes" "external" "canDebug" }}
    {{- $ports := list }}
    {{- if $service.ports }}
      {{- if not (kindIs "slice" $service.ports) }}
        {{- fail (printf "The declaration for .Values.service.ports must be a list of ports (maps) (%s)" (kindOf $service.ports)) }}
      {{- end }}
      {{- $ports = $service.ports }}
    {{- end }}

    {{- $parts := omit $ctx.Values.service "ports" "type" "probes" "external" "canDebug" }}
    {{- $external := ($service.external | default "") -}}

    {{- /* Render the work to be performed */ -}}
    {{- $work := list }}
    {{- if $partname }}
      {{- /* Render a single part as the global service, as necessary */ -}}
      {{- if hasKey $parts $partname }}
        {{- /* The single-part option supplants the global service */ -}}
        {{- $work = append $work (dict "ctx" $ctx "data" (get $parts $partname) "global" $service "subname" $partname) }}
      {{- end }}
    {{- else }}
      {{- /* Render a global service with all the ports */ -}}
      {{- $data := pick $service "type" "external" "canDebug" }}
      {{- range $pn, $p := $parts -}}
        {{- $ports = concat $ports $p.ports -}}
      {{- end -}}
      {{- $data = set $data "ports" $ports }}
      {{- /* Add the work item */ -}}
      {{- $work = append $work (dict "ctx" $ctx "data" $data "subname" $partname) }}
    {{- end }}
    {{- range $w := $work }}
      {{- include "arkcase.subsystem.service.render" $w }}
    {{- end }}
  {{- end }}
{{- end }}

{{- /*
Check to see if a given probe specification is valid. For a probe to be valid it must contain
exactly one of the exec, grpc, httpGet, or tcpSocket specifications. If more than one is contained,
the template will be failed to notify of the issue.

This template should be invoked with a reference to the map describing the probe as the argument.

*/ -}}
{{- define "arkcase.subsystem.probeIsValid" -}}
  {{- $valid := list -}}
  {{- with .exec -}}
    {{- if .command -}}
      {{- $valid = (append $valid "exec") -}}
    {{- end -}}
  {{- end -}}
  {{- with .grpc -}}
    {{- if .port -}}
      {{- $valid = (append $valid "grpc") -}}
    {{- end -}}
  {{- end -}}
  {{- with .httpGet -}}
    {{- if or .port .path -}}
      {{- $valid = (append $valid "httpGet") -}}
    {{- end -}}
  {{- end -}}
  {{- with .tcpSocket -}}
    {{- if .port -}}
      {{- $valid = (append $valid "tcpSocket") -}}
    {{- end -}}
  {{- end -}}
  {{- if $valid -}}
    {{- if eq (len $valid) 1 -}}
      {{- true -}}
    {{- else -}}
      {{- fail (printf "Invalid probe specification - multiple probe modes specified: %s" (toString $valid)) -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{- /*
Render container port declarations based on what's declared in the values file. Probes will also be rendered if enabled.

Parameter: the root context (i.e. "." or "$"), or a map which descibes the ports and probes
*/ -}}
{{- define "arkcase.subsystem.ports" }}
  {{- $service := . -}}
  {{- if (include "arkcase.isRootContext" .) -}}
    {{- /* No parameters given, so deduce everything */ -}}
    {{- $partname := (include "arkcase.part.name" .) -}}
    {{- $ctx := . }}
    {{- if not (include "arkcase.isRootContext" $ctx) -}}
      {{- fail "Incorrect context given - either submit the root context as the only parameter, or a 'ctx' parameter pointing to it" -}}
    {{- end -}}
    {{- $service = pick $ctx.Values.service "ports" "type" "probes" "external" -}}
    {{- $parts := omit $ctx.Values.service "ports" "type" "probes" "external" }}
    {{- if $partname -}}
      {{- if not (hasKey $parts $partname) -}}
        {{- fail (printf "No part named [%s] found in the Values.service declaration" $partname) -}}
      {{- end -}}
      {{- $service = get $parts $partname -}}
    {{- else -}}
      {{- $ports := $service.ports | default list -}}
      {{- range $partname, $p := $parts -}}
        {{- $ports = concat $ports $p.ports -}}
      {{- end -}}
      {{- $service = set $service "ports" $ports -}}
    {{- end -}}
  {{- end -}}

  {{- with $service }}
    {{- with .ports -}}
ports:
      {{- range . }}
  - name: {{ (required "Port specifications must contain a name" .name) | quote }}
    protocol: {{ coalesce .protocol "TCP" }}
    containerPort: {{ required (printf "Port [%s] doesn't have a port number" .name) .port }}
      {{- end }}
    {{- end }}
    {{- $probes := (coalesce .probes dict) }}
    {{- $commonBase := omit (coalesce $probes.spec dict) "httpGet" "grpc" "tcpSocket" "exec" -}}
    {{- $commonTask := pick (coalesce $probes.spec dict) "httpGet" "grpc" "tcpSocket" "exec" -}}
    {{- $startup := (coalesce $probes.startup dict) }}
    {{- $readiness := (coalesce $probes.readiness dict) }}
    {{- $liveness := (coalesce $probes.liveness dict) }}
    {{- if or ($probes.enabled) (not (hasKey $probes "enabled")) }}
      {{- if or ($startup.enabled) (not (hasKey $startup "enabled")) -}}
        {{- $base := omit $startup "httpGet" "grpc" "tcpSocket" "exec" -}}
        {{- $task := pick $startup "httpGet" "grpc" "tcpSocket" "exec" -}}
        {{- with (merge $base $commonBase ((empty $task) | ternary $commonTask $task)) -}}
          {{- if (include "arkcase.subsystem.probeIsValid" .) }}
startupProbe: {{- toYaml (unset . "enabled") | nindent 2 }}
          {{- end -}}
        {{- end }}
      {{- end }}
      {{- if or ($readiness.enabled) (not (hasKey $readiness "enabled")) -}}
        {{- $base := omit $readiness "httpGet" "grpc" "tcpSocket" "exec" -}}
        {{- $task := pick $readiness "httpGet" "grpc" "tcpSocket" "exec" -}}
        {{- with (merge $base $commonBase ((empty $task) | ternary $commonTask $task)) -}}
          {{- if (include "arkcase.subsystem.probeIsValid" .) }}
readinessProbe: {{- toYaml (unset . "enabled") | nindent 2 }}
          {{- end }}
        {{- end }}
      {{- end }}
      {{- if or ($liveness.enabled) (not (hasKey $liveness "enabled")) -}}
        {{- $base := omit $liveness "httpGet" "grpc" "tcpSocket" "exec" -}}
        {{- $task := pick $liveness "httpGet" "grpc" "tcpSocket" "exec" -}}
        {{- with (merge $base $commonBase ((empty $task) | ternary $commonTask $task)) -}}
          {{- if (include "arkcase.subsystem.probeIsValid" .) }}
livenessProbe: {{- toYaml (unset . "enabled") | nindent 2 }}
          {{- end }}
        {{- end }}
      {{- end }}
    {{- end }}
  {{- end }}
{{- end }}

{{- /*
Render an ingress port declaration based on what's provided as parameters. Will only be rendered if the subsystem in question is enabled or external.

Parameter: a dict with two keys:
             - ctx = the root context (either "." or "$")
             - subsystem = a string with the name of the subsystem to query
             - port = the port number that the ingress will be pointed to
*/ -}}
{{- define "arkcase.subsystem.ingressPath" -}}
  {{- $ctx := (required "Must provide a 'ctx' parameter with the root context" .ctx) -}}
  {{- $subsystem := (required "Must provide a 'subsystem' parameter with the name of the subsystem to render" .subsystem) -}}
  {{- $port := (required "Must provide a 'port' parameter with the port number for the service" (int .port)) -}}
  {{- if (include "arkcase.subsystem.enabledOrExternal" (dict "ctx" $ctx "subsystem" $subsystem)) -}}
- pathType: Prefix
  path: {{ printf "/%s" $subsystem | quote }}
  backend:
    service:
      name: {{ $subsystem | quote }}
      port:
        number: {{ $port }}
  {{- end }}
{{- end -}}

{{- /* Render the volume mount specification for the target subsystem's $type secrets */ -}}
{{- define "arkcase.subsystem.secret.volumeMount" -}}
  {{- $ctx := $.ctx -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
      {{- fail "Must provide the root context ($ or .) as the 'ctx' parameter" -}}
  {{- end -}}
  {{- $subsys := (include "arkcase.subsystem.name" $ctx) -}}
  {{- $subsys = ((hasKey $ "subsys") | ternary ($.subsys | default "" | toString) $subsys) | default $subsys -}}
  {{- $mountPath := "/srv/arkcase" -}}
  {{- $mountPath = ((hasKey $ "mountPath") | ternary ($.mountPath | default "" | toString) $mountPath) | default $mountPath -}}
  {{- $type := ($.type | default "" | toString | lower) -}}
  {{- if or (not $type) (not (regexMatch "^[a-z0-9]+(-[a-z0-9]+)*$" $type)) -}}
    {{- fail (printf "Invalid subsystem secret type [%s]" $type) -}}
  {{- end -}}
  {{- $name := (include "arkcase.subsyste.secret.name" $) -}}
- mountPath: {{ printf "/svr/arkcase/%s/%s" $subsys $type | quote }}
  name: {{ $name | quote }}
  readOnly: true
{{- end -}}

{{- /* Render the volume mount specification for the target subsystem's $type secrets */ -}}
{{- define "arkcase.subsystem.secret.volume" -}}
  {{- $ctx := $.ctx -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
      {{- fail "Must provide the root context ($ or .) as the 'ctx' parameter" -}}
  {{- end -}}
  {{- $subsys := (include "arkcase.subsystem.name" $ctx) -}}
  {{- $subsys = ((hasKey $ "subsys") | ternary ($.subsys | default "" | toString) $subsys) | default $subsys -}}
  {{- $type := ($.type | default "" | toString | lower) -}}
  {{- if or (not $type) (not (regexMatch "^[a-z0-9]+(-[a-z0-9]+)*$" $type)) -}}
    {{- fail (printf "Invalid subsystem secret type [%s]" $type) -}}
  {{- end -}}
  {{- $optional := ((hasKey $ "optional") | ternary (not (empty (include "tools.toBoolean" $.optional))) false) -}}
  {{- $name := (include "arkcase.subsyste.secret.name" $) -}}
- name: {{ $name | quote }}
  secret:
    secretName: {{ $name | quote }}
    defaultMode: 0444
    optional: {{ $optional }}
{{- end -}}

{{- define "arkcase.subsystem.secret.name" -}}
  {{- $ctx := $.ctx -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
      {{- fail "Must provide the root context ($ or .) as the 'ctx' parameter" -}}
  {{- end -}}
  {{- $subsys := (include "arkcase.subsystem.name" $ctx) -}}
  {{- $subsys = ((hasKey $ "subsys") | ternary ($.subsys | default "" | toString) $subsys) | default $subsys -}}
  {{- $type := ($.type | default "" | toString | lower) -}}
  {{- if or (not $type) (not (regexMatch "^[a-z0-9]+(-[a-z0-9]+)*$" $type)) -}}
    {{- fail (printf "Invalid subsystem secret type [%s]" $type) -}}
  {{- end -}}
  {{- printf "%s-%s-%s" $ctx.Release.Name $subsys $type -}}
{{- end -}}
