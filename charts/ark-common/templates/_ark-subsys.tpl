{{- /*
Return a map which contains the subsystem data map as required by other API calls:

   data:
     ctx: .ctx
     name: $subsystemName
     enabled: true|false

*/ -}}
{{- define "arkcase.subsystem" -}}
  {{- $ctx := . -}}
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
  {{- if (hasKey $ctx "ArkCaseSubsystem") -}}
    {{- $subsys = get $ctx "ArkCaseSubsystem" -}}
  {{- else -}}
    {{- $crap := set $ctx "ArkCaseSubsystem" $subsys -}}
  {{- end -}}

  {{- $data := dict -}}
  {{- if (hasKey $subsys $subsysName) -}}
    {{- /* Retrieve the cached data */ -}}
    {{- $data = get $subsys $subsysName -}}
  {{- else -}}
    {{- $enabled := (include "arkcase.tools.get" (dict "ctx" $ctx "name" (printf ".Values.global.subsystem.%s" $subsysName))) -}}
    {{- /* Set the "enabled" flag, which defaults to TRUE if it's not set */ -}}
    {{- $enabled = or (empty $enabled) (eq "true" (toString $enabled | lower)) -}}
    {{- if not (kindIs "bool" $enabled) -}}
      {{- $enabled = (eq "true" (toString $enabled | lower)) -}}
    {{- end -}}
    {{- $crap := set $data "enabled" $enabled -}}

    {{- /* Cache the computed data */ -}}
    {{- $crap = set $subsys $subsysName $data -}}
  {{- end -}}
  {{- $crap := set $map "data" $data -}}

  {{- $map | toYaml | nindent 0 -}}
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
  {{- $root := . }}
  {{- $topLevel := true }}
  {{- if and .ctx (kindIs "map" .ctx) (hasKey . "data") }}
    {{- $root = get . "ctx" }}
    {{- $topLevel = false }}
  {{- end }}
  {{- $map := (include "arkcase.subsystem" $root | fromYaml) }}
  {{- $data := ($map.ctx.Values.service | default dict) }}
  {{- if not $topLevel }}
    {{- $data = .data }}
  {{- end }}
  {{- if (or ($map.data.enabled) ($data.external)) }}
    {{- true }}
  {{- end }}
{{- end }}

{{- define "arkcase.subsystem.service.render" }}
  {{- $ctx := .ctx }}
  {{- $data := .data }}
  {{- if (include "arkcase.subsystem.enabledOrExternal" (dict "ctx" $ctx "data" $data)) }}
    {{- $external := (coalesce $data.external "") }}

    {{- $ports := (coalesce $data.ports list) }}
    {{- $type := (coalesce $data.type "ClusterIP") }}
    {{- if and (empty $ports) (not $external) }}
      {{- fail (printf "No ports are defined for chart %s, and no external server was given" (include "common.name" $ctx)) }}
    {{- end }}
    {{- $name := "" }}
    {{- $name := ($data.name | default "") | toString }}
    {{- if not $name }}
      {{- $name =  (include "common.name" $ctx) }}
      {{- if .name }}
        {{- $name = (printf "%s-%s" $name .name) }}
      {{- end }}
    {{- end }}
---
apiVersion: v1
kind: Service
metadata:
  name: {{ $name | quote }}
  namespace: {{ $ctx.Release.Namespace | quote }}
  labels: {{- include "common.labels" $ctx | nindent 4 }}
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
spec:
    {{- if or (not $external) (include "arkcase.tools.isIp" $external) }}
  # This is either an internal service, or an external service using an IP address
  type: {{ coalesce $type "ClusterIP" }}
  ports:
      {{- if (empty $ports) }}
        {{- fail "There are no ports defined to be proxied for this external service" }}
      {{- end }}
      {{- range $ports }}
    - name: {{ (required "Port specifications must contain a name" .name) | quote }}
      protocol: {{ coalesce .protocol "TCP" }}
      port: {{ required (printf "Port [%s] doesn't have a port number" .name) .port }}
        {{- if .targetPort }}
      targetPort: {{ int .targetPort }}
        {{- end }}
        {{- if and (eq $type "NodePort") .nodePort }}
      nodePort: {{ int .nodePort }}
        {{- end }}
      {{- end }}
  selector: {{ include "common.labels.matchLabels" $ctx | nindent 4 }}
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
  name: {{ $name | quote }}
  namespace: {{ $ctx.Release.Namespace | quote }}
  labels: {{- include "common.labels" $ctx | nindent 4 }}
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
      {{- end }}
    {{- end }}
  {{- end }}
{{- end }}

{{- /*
Render subsystem service declarations based on whether an external host declaration is provided or not

Parameter: the root context (i.e. "." or "$")
*/ -}}
{{- define "arkcase.subsystem.service" }}
  {{- $ctx := . }}
  {{- $split := false }}
  {{- $container := "" }}
  {{- if and (hasKey $ctx "ctx") (or (hasKey $ctx "split") (hasKey $ctx "container")) }}
    {{- $ctx = .ctx }}
    {{- if hasKey . "container" }}
      {{- $container = (.container | toString) }}
      {{- $split = false }}
    {{- else if hasKey . "split" }}
      {{- $split = .split }}
      {{- if not (kindIs "bool" $split) }}
        {{- $split = eq "true" (.split | toString | lower) }}
      {{- end }}
    {{- else }}
      {{- $split = true }}
    {{- end }}
  {{- end }}

  {{- /* Gather the global ports */ -}}
  {{- $global := pick $ctx.Values.service "ports" "type" "probes" "external" }}
  {{- $globalPorts := list }}
  {{- if $global.ports }}
    {{- if (not (kindIs "slice" $global.ports)) }}
      {{- fail (printf "The declaration for .Values.service.ports must be a list of ports (maps) (%s)" (kindOf $global.ports)) }}
    {{- end }}
    {{- $globalPorts = $global.ports }}
  {{- end }}

  {{- $containers := omit $ctx.Values.service "ports" "type" "probes" "external" }}

  {{- /* Render the work to be performed */ -}}
  {{- $work := list }}
  {{- if $split }}
    {{- /* Render the per-container work items, as necessary */ -}}
    {{- range $container, $spec := $containers }}
      {{- $work = append $work (dict "ctx" $ctx "data" $spec "name" $container) }}
    {{- end }}
  {{- else if $container }}
    {{- /* Render a single container as the global service, as necessary */ -}}
    {{- if hasKey $containers $container }}
      {{- /* The single-container option supplants the global service */ -}}
      {{- $work = append $work (dict "ctx" $ctx "data" (get $containers $container) "name" "") }}
    {{- end }}
  {{- else }}
    {{- /* Render a global service with all declared ports, as necessary */ -}}
    {{- $containerPorts := list }}
    {{- range $container, $spec := $containers }}
      {{- if if (kindIs "map" $spec) $spec.ports }}
        {{- if (not (kindIs "slice" $spec.ports)) }}
          {{- fail (printf "The declaration for .Values.service.%s.ports must be a list of ports (maps) (%s)" $container (kindOf $spec.ports)) }}
        {{- end }}
        {{- $containerPorts = concat $containerPorts $spec.ports }}
      {{- end }}
    {{- end }}
    {{- /* It will fall to the values author to avoid duplication */ -}}
    {{- $data := pick $global "type" "external" }}
    {{- $data = set $data "ports" (concat $globalPorts $containerPorts) }}
    {{- /* Add the work item */ -}}
    {{- $work = append $work (dict "ctx" $ctx "data" $data "name" "") }}
  {{- end }}
  {{- range $item := $work }}
    {{- include "arkcase.subsystem.service.render" . }}
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
  {{- $root := . -}}
  {{- if $root -}}
    {{- if not (kindIs "map" $root) -}}
      {{- fail "The parameter given must be a map" -}}
    {{- end -}}
    {{- /* This is a simple detection of whether we were given the root, or a specific map */ -}}
    {{- if (($root.Values).service | default dict).ports -}}
      {{- $root = $root.Values.service -}}
    {{- end -}}
    {{- with $root }}
      {{- with .ports -}}
ports:
        {{- range . }}
  - name: {{ (required "Port specifications must contain a name" .name) | quote }}
    protocol: {{ coalesce .protocol "TCP" }}
    containerPort: {{ required (printf "Port [%s] doesn't have a port number" .name) .port }}
        {{- end }}
      {{- end }}
      {{- $probes := (coalesce .probes dict) }}
      {{- $common := (coalesce $probes.spec dict) }}
      {{- $startup := (coalesce $probes.startup dict) }}
      {{- $readiness := (coalesce $probes.readiness dict) }}
      {{- $liveness := (coalesce $probes.liveness dict) }}
      {{- if or ($probes.enabled) (not (hasKey $probes "enabled")) }}
        {{- if or ($startup.enabled) (not (hasKey $startup "enabled")) -}}
          {{- with (mergeOverwrite $common $startup) }}
            {{- if (include "arkcase.subsystem.probeIsValid" .) }}
startupProbe: {{- toYaml (unset . "enabled") | nindent 2 }}
            {{- end -}}
          {{- end }}
        {{- end }}
        {{- if or ($readiness.enabled) (not (hasKey $readiness "enabled")) -}}
          {{- with (mergeOverwrite $common $readiness) }}
            {{- if (include "arkcase.subsystem.probeIsValid" .) }}
readinessProbe: {{- toYaml (unset . "enabled") | nindent 2 }}
            {{- end }}
          {{- end }}
        {{- end }}
        {{- if or ($liveness.enabled) (not (hasKey $liveness "enabled")) -}}
          {{- with (mergeOverwrite $common $liveness) }}
            {{- if (include "arkcase.subsystem.probeIsValid" .) }}
livenessProbe: {{- toYaml (unset . "enabled") | nindent 2 }}
            {{- end }}
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
