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
Check whether a subsystem is enabled for provisioning. If it's not enabled, attempting to access its configurations
should result in an error.

Parameter: either the root context (i.e. "." or "$"), or
           a dict with two keys:
             - ctx = the root context (either "." or "$")
             - subsystem = a string with the name of the subsystem to query
*/ -}}
{{- /*
{{- define "arkcase.subsystem.enabled" -}}
  {{- $map := (include "arkcase.subsystem" . | fromYaml) -}}
  {{- if ($map.data.enabled) -}}
    {{- true -}}
  {{- end -}}
{{- end -}}
*/ -}}

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
{{- define "arkcase.subsystem.enabledOrExternal" -}}
  {{- $map := (include "arkcase.subsystem" . | fromYaml) -}}
  {{- if (or ($map.data.enabled) (($map.ctx.Values.service).external)) -}}
    {{- true -}}
  {{- end -}}
{{- end -}}

{{- /*
Render subsystem service declarations based on whether an external host declaration is provided or not

Parameter: the root context (i.e. "." or "$")
*/ -}}
{{- define "arkcase.subsystem.service" }}
{{- if (include "arkcase.subsystem.enabledOrExternal" .) }}
{{- $external := (coalesce (.Values.service).external "") }}
{{- $ports := (coalesce (.Values.service).ports list) }}
{{- $type := (coalesce (.Values.service).type "ClusterIP") }}
{{- if and (empty $ports) (not $external) }}
  {{- fail (printf "No ports are defined for chart %s, and no external server was given" (include "common.name" .)) }}
{{- end }}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "common.name" . | quote }}
  namespace: {{ .Release.Namespace | quote }}
  labels: {{- include "common.labels" . | nindent 4 }}
    {{- with .Values.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
    {{- with (.Values.service).labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  annotations:
    {{- with .Values.annotations }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
    {{- with (.Values.service).annotations }}
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
  selector: {{ include "common.labels.matchLabels" . | nindent 4 }}
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
  name: {{ include "common.name" . | quote }}
  namespace: {{ .Release.Namespace | quote }}
  labels: {{- include "common.labels" . | nindent 4 }}
    {{- with .Values.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
    {{- with (.Values.service).labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  annotations:
    {{- with .Values.annotations }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
    {{- with (.Values.service).annotations }}
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

Parameter: the root context (i.e. "." or "$")
*/ -}}
{{- define "arkcase.subsystem.ports" }}
  {{- with (.Values.service) }}
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
      {{- if or ($startup.enabled) (not (hasKey $readiness "enabled")) -}}
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
