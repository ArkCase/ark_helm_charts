{{- /* Will return a YAML map with either "url" (dict), or "hostname" (string) and "port" (int) entries */ -}}
{{- /* If the "url" member is present, neither "hostname" nor "port" will be present. */ -}}
{{- /* If either of the "hostname" or "port" members are present, then the "url" member will not be present */ -}}
{{- /* The map may empty, indicating that there is no override value */ -}}
{{- define "__arkcase.dependency.target" -}}
  {{- $ctx := $.ctx -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "You must supply the 'ctx' parameter, pointing to the root context that contains 'Values' et al." -}}
  {{- end -}}

  {{- $hostname := $.hostname -}}
  {{- if or (not $hostname) (not (kindIs "string" $hostname)) -}}
    {{- fail (printf "You must supply a string value for the 'hostname' parameter (%s)" (kindOf $hostname)) -}}
  {{- end -}}

  {{- $global := (include "arkcase.tools.get" (dict "ctx" $ctx "name" (printf "Values.global.subsys.%s" $hostname)) | fromYaml) -}}
  {{- $local := (include "arkcase.tools.get" (dict "ctx" $ctx "name" (printf "Values.configuration.%s" $hostname)) | fromYaml) -}}

  {{- $result := dict -}}
  {{- range $replacement := (list $global $local) -}}
    {{- if or $result (not $replacement) (not $replacement.found) (not (kindIs "map" $replacement.value)) -}}
      {{- break -}}
    {{- end -}}

    {{- /* If this dependency is specified by URL, then parse it */ -}}
    {{- if (hasKey $replacement.value "url") -}}
      {{- $url := (include "arkcase.tools.parseUrl" ($replacement.value.url | toString) | fromYaml) -}}
      {{- if $url -}}
        {{- $result = dict "url" $url -}}
      {{- end -}}
      {{- break -}}
    {{- end -}}

    {{- /* If it's provided using hostname and port, then use those (port is optional, which lets us use the default "OOTB" value) */ -}}
    {{- if or (hasKey $replacement.value "hostname") (hasKey $replacement.value "port") -}}
      {{- $newHostName := "" -}}
      {{- if (hasKey $replacement.value "hostname") -}}
        {{- $newHostName = ($replacement.value.hostname | toString) -}}
        {{- if $newHostName -}}
          {{- $result = set $result "hostname" $newHostName -}}
        {{- end -}}
      {{- end -}}

      {{- $newPort := 0 -}}
      {{- if (hasKey $replacement.value "port") -}}
        {{- $newPort = (include "arkcase.tools.checkNumericPort" $replacement.value.port | atoi) -}}
        {{- if $newPort -}}
          {{- $result = set $result "port" $newPort -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
  {{- $result | toYaml -}}
{{- end -}}

{{- define "__arkcase.initDependencies.networkName" -}}
  {{- $sep := "/" -}}
  {{- printf "network%s%s" $sep $ | trimSuffix $sep -}}
{{- end -}}

{{- /*
Render the boot order configuration file to be consumed by the init container
that checks the boot order
*/ -}}
{{- define "__arkcase.initDependencies" -}}
  {{- $ctx := $.ctx -}}
  {{- $dependencySet := $.dependencySet -}}
  {{- $explicit := $.explicit -}}
  {{- $subsysDeps := ($ctx.Files.Get "subsys-deps.yaml" | fromYaml | default dict) -}}
  {{- $cluster := (include "arkcase.cluster" $ctx | fromYaml) -}}

  {{- /*
    Allow for "network:", "network.something:", "network.other:", etc.

    We also allow for automatic selection of the right part-based set, as well as
    explicit selection of a specific set.

    If the selection is explicit, we seek only that one. Otherwise, we try using
    the part name and if that fails, use the default "network:" section
  */ -}}

  {{- $candidates := list -}}
  {{- if $explicit -}}
    {{- $candidates = list (include "__arkcase.initDependencies.networkName" $dependencySet) -}}
  {{- else -}}
    {{- /* If the choice isn't explicit, allow fallback to the "common" section */ -}}
    {{- range $suffix := (list (include "arkcase.part.name" $ctx) "" | mustUniq) -}}
      {{- $candidates = append $candidates (include "__arkcase.initDependencies.networkName" $suffix) -}}
    {{- end -}}
  {{- end -}}

  {{- /* Find the best option! */ -}}
  {{- $network := dict -}}
  {{- range $candidate := $candidates -}}
    {{- $network = get $subsysDeps $candidate -}}
    {{- if (kindIs "map" $network) -}}
      {{- break -}}
    {{- end -}}
  {{- end -}}

  {{- /* Safety net */ -}}
  {{- if (not (kindIs "map" $network)) -}}
    {{- $network = dict -}}
  {{- end -}}

  {{- $dependencies := ($network.dependencies | default dict) -}}
  {{- if (not (kindIs "map" $dependencies)) -}}
    {{- $dependencies = dict -}}
  {{- end -}}
  {{- $network = omit $network "dependencies" -}}

  {{- $result := dict -}}
  {{- range $host, $settings := $dependencies -}}
    {{- if and (not $cluster.enabled) $settings.clusterOnly -}}
      {{- /* This dependency is only applicable when clustering is enabled */ -}}
      {{- continue -}}
    {{- end -}}

    {{- /* Normalize */ -}}
    {{- if (hasKey $settings "port") -}}
      {{- $settings = omit $settings "ports" -}}
    {{- else if (hasKey $settings "ports") -}}
      {{- $ports := $settings.ports -}}
      {{- $settings = omit $settings "ports" -}}
      {{- $settings = set $settings "port" $ports -}}
    {{- end -}}

    {{- if and (hasKey $settings "url") (or (hasKey $settings "host") (hasKey $settings "port")) -}}
      {{- fail (printf "The dependency declaration for %s has conflicting settings: may only have URL or host/port specs" $host) -}}
    {{- end -}}

    {{- if and (not (hasKey $settings "url")) (not (hasKey $settings "port")) -}}
      {{- fail (printf "The dependency declaration for %s doesn't have any port information - no URL or port given" $host) -}}
    {{- end -}}

    {{- $result = set $result $host (omit $settings "clusterOnly") -}}
  {{- end -}}

  {{- if $result -}}
    {{- merge (dict "dependencies" $result) $network | toYaml -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.initDependencies.container" -}}
  {{- if not (kindIs "map" $) -}}
    {{- fail "The parameter object must be a dict with a 'ctx' and a 'name' values" -}}
  {{- end -}}

  {{- $ctx := $ -}}
  {{- $containerName := "init-dependencies" -}}
  {{- $dependencySet := "" -}}
  {{- $explicit := false -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- $ctx = $.ctx -}}
    {{- if not (include "arkcase.isRootContext" $ctx) -}}
      {{- fail "You must supply the root context as either the 'ctx' parameter or the only parameter" -}}
    {{- end -}}
    {{- $containerName = (hasKey $ "containerName" | ternary ($.name | toString) "" | default $containerName) -}}
    {{- $explicit = (hasKey $ "dependencies") -}}
    {{- $dependencySet = ($explicit | ternary ($.dependencySet | toString) "" | default $dependencySet) -}}
  {{- end -}}

  {{- $yaml := (include "__arkcase.initDependencies" (dict "ctx" $ctx "explicit" $explicit "dependencySet" $dependencySet) | fromYaml) -}}
  {{- if $yaml -}}
- name: {{ $containerName | quote }}
  {{- include "arkcase.image" (dict "ctx" $ctx "name" "nettest" "repository" "arkcase/nettest") | nindent 2 }}
  command: [ "/usr/local/bin/wait-for-ports" ]
  env: {{- include "arkcase.tools.baseEnv" $ctx | nindent 4 }}
    {{- include "arkcase.acme.env" $ctx | nindent 4 }}
    {{- include "arkcase.subsystem-access.env" $ctx | nindent 4 }}
    - name: INIT_DEPENDENCIES
      value: |- {{- $yaml | toYaml | nindent 8 }}
  {{- end -}}
{{- end -}}

