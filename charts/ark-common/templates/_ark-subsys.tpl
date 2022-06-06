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
  {{- if (and ($map.data.enabled) (($map.ctx.Values.service).external)) -}}
    {{- true -}}
  {{- end -}}
{{- end -}}

{{- /*
Render subsystem service declarations based on whether an external host declaration is provided or not

Parameter: the root context (i.e. "." or "$")
*/ -}}
{{- define "arkcase.subsystem.service" -}}
{{- if (include "arkcase.subsystem.enabledOrExternal" .) -}}
{{- if (empty (.Values.service).ports) -}}
{{- fail (printf "No ports are defined for chart %s" (include "common.name" .)) -}}
{{- end -}}
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
  {{- if or (empty .Values.service.external) (include "arkcase.tools.isIp" (.Values.service).external) }}
  # This is either an internal service, or an external service using an IP address
  type: ClusterIP
  ports:
    {{- range .Values.service.ports }}
    - name: {{ (required "Port specifications must contain a name" .name) | quote }}
      protocol: {{ default "TCP" .protocol }}
      port: {{ required (printf "Port [%s] doesn't have a port number" .name) .port }}
    {{- end }}
  selector: {{ include "common.labels.matchLabels" . | nindent 4 }}
  {{- else }}
  # This is an external service, but using a hostname. This will cause a CNAME to
  # be created to route service requests to the external hostname
  type: ExternalName
  externalName: {{ .Values.service.external | quote }}
  {{- end }}

{{- if and (not (empty .Values.service.external)) (include "arkcase.tools.isIp" .Values.service.external) }}
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
      {{- range (uniq (sortAlpha (splitList "," .Values.service.external))) }}
      - ip: {{ . }}
      {{- end }}
    ports:
      {{- range .Values.service.ports }}
      - name: {{ (required "Port specifications must contain a name" .name) | quote }}
        protocol: {{ default "TCP" .protocol }}
        port: {{ required (printf "Port [%s] doesn't have a port number" .name) .port }}
      {{- end }}
{{- end }}
{{- end }}
{{- end -}}

{{- /*
Render subsystem service declarations based on whether an external host declaration is provided or not

Parameter: the root context (i.e. "." or "$")
*/ -}}
{{- define "arkcase.subsystem.ports" -}}
{{- with (.Values.service) -}}
{{- with .ports -}}
ports:
  {{- range . }}
  - name: {{ (required "Port specifications must contain a name" .name) | quote }}
    protocol: {{ default "TCP" .protocol }}
    containerPort: {{ required (printf "Port [%s] doesn't have a port number" .name) .port }}
  {{- end }}
{{- end }}
{{- if (.probes).enabled -}}
{{- with (mergeOverwrite ((.probes).spec | default dict) ((.probes).readiness | default dict)) }}
readinessProbe: {{- toYaml . | nindent 2 }}
{{- end }}
{{- with (mergeOverwrite ((.probes).spec | default dict) ((.probes).liveness | default dict)) }}
livenessProbe: {{- toYaml . | nindent 2 }}
{{- end }}
{{- end -}}
{{- end -}}
{{- end -}}
