{{- define "arkcase.cluster.info.rules" -}}
  {{- /* Find the chart's own clustering rules */ -}}

  {{- $rules := (.Files.Get "clustering.yaml" | fromYaml) -}}
  {{- if (not (kindIs "map" $rules)) -}}
    {{- $rules = dict -}}
  {{- end -}}

  {{- $result := dict -}}
  {{- $result = set $result "supported" ((hasKey $rules "supported") | ternary (not (empty (include "arkcase.toBoolean" $rules.supported))) true) -}}

  {{- $replicas := dict "min" 1 "def" 1 "max" 1 -}}
  {{- if $result.supported -}}
    {{- $replicas = dict "min" 1 "def" 2 "max" 0 -}}
    {{- if (hasKey $rules "replicas") -}}
      {{- $replicas = ($rules.replicas | default dict) -}}

      {{- $min := 1 -}}
      {{- if (hasKey $replicas "min") -}}
        {{- $min = ($replicas.min | default 1 | toString) -}}
        {{- $min = (regexMatch "^[1-9][0-9]*$" $min | ternary ($min | atoi | int) 1 | int) -}}
      {{- end -}}

      {{- $def := 0 -}}
      {{- if (hasKey $replicas "def") -}}
        {{- $def = ($replicas.def | default 2 | toString) -}}
        {{- $def = (regexMatch "^[1-9][0-9]*$" $def | ternary ($def | atoi | int) 2 | int) -}}
        {{- $def = (eq $def 0 | ternary $def (max $def $min)) -}}
      {{- end -}}

      {{- $max := 0 -}}
      {{- if (hasKey $replicas "max") -}}
        {{- $max = ($replicas.max | default 0 | toString) -}}
        {{- $max = (regexMatch "^[1-9][0-9]*$" $max | ternary ($max | atoi | int) 0 | int) -}}
        {{- $max = (eq $max 0 | ternary $max (max $max $min)) -}}
      {{- end -}}

      {{- $replicas = dict "min" $min "def" $def "max" $max -}}
    {{- end -}}
  {{- end -}}
  {{- $result = set $result "replicas" $replicas -}}

  {{- $result | toYaml -}}
{{- end -}}

{{- define "__arkcase.cluster.info.compute" -}}
  {{- $global := dict -}}

  {{- /* First, find the "global" values */ -}}
  {{- if hasKey $.Values "global" -}}
    {{- $g := $.Values.global -}}
    {{- if (kindIs "map" $g) -}}
      {{- $global = $g -}}
    {{- end -}}
  {{- end -}}

  {{- /* Next, find the "global.cluster" value */ -}}
  {{- $cluster := dict -}}
  {{- if hasKey $global "cluster" -}}
    {{- $c := $global.cluster -}}
    {{- if (kindIs "map" $c) -}}
      {{- $cluster = $c -}}
    {{- else -}}
      {{- /* If "global.cluster" isn't a map, it may only be the word "single" */ -}}
      {{- $cluster = dict "enabled" true "single" (eq "single" ($cluster | toString | lower)) -}}
    {{- end -}}
  {{- end -}}

  {{- /* Set/sanitize the general "enabled" value */ -}}
  {{- $cluster = set $cluster "enabled" true -}}

  {{- /* Set/sanitize the general "onePerHost" value */ -}}
  {{- $cluster = set $cluster "onePerHost" ((hasKey $cluster "onePerHost") | ternary (not (empty (include "arkcase.toBoolean" $cluster.onePerHost))) false) -}}

  {{- /* Set/sanitize the general "single" value */ -}}
  {{- $cluster = set $cluster "single" ((hasKey $cluster "single") | ternary (not (empty (include "arkcase.toBoolean" $cluster.single))) false) -}}

  {{- $subsystems := omit $cluster "enabled" "onePerHost" "single" -}}
  {{- $cluster = pick $cluster "enabled" "onePerHost" "single" -}}

  {{- /* Sanitize the maps for each subsystem */ -}}
  {{- range $k, $v := $subsystems -}}
    {{- /* if it's a short syntax, turn it into a single map with the "enabled" flag */ -}}
    {{- $m := dict "enabled" true -}}

    {{- /* Can't use a list here */ -}}
    {{- if (kindIs "slice" $v) -}}
      {{- fail (printf "The cluster configuration value global.cluster.%s may not be a list" $k) -}}
    {{- end -}}

    {{- /* Support both map format, and a scalar value */ -}}
    {{- if (kindIs "map" $v) -}}
      {{- $m = pick $v "onePerHost" "single" "replicas" -}}
    {{- else -}}
      {{- $v = $v | toString -}}
      {{- if (eq "single" ($v | lower)) -}}
        {{- $m = set $m "replicas" 1 -}}
      {{- else if (regexMatch "^[1-9][0-9]*$" $v) -}}
        {{- /* If it's a number, it's the replica count we want (min == 1) */ -}}
        {{- $v = (atoi $v | int) -}}
        {{- $m = set $m "replicas" (max $v 1) -}}
        {{- $m = set $m "single" false -}}
      {{- end -}}
    {{- end -}}

    {{- /* Sanitize the "onePerHost" flag */ -}}
    {{- $m = set $m "onePerHost" ((hasKey $m "onePerHost") | ternary (not (empty (include "arkcase.toBoolean" $m.onePerHost))) $cluster.onePerHost) -}}

    {{- /* Sanitize the "single" flag */ -}}
    {{- $m = set $m "single" ((hasKey $m "single") | ternary (not (empty (include "arkcase.toBoolean" $m.single))) $cluster.single) -}}

    {{- /* Sanitize the "replicas" count */ -}}
    {{- $replicas := 2 -}}
    {{- if $m.single -}}
      {{- /* If in single mode, we will only deploy one replica */ -}}
      {{- $replicas = 1 -}}
    {{- else -}}
      {{- if hasKey $m "replicas" -}}
        {{- $replicas = ($m.replicas | toString) -}}
        {{- if not (regexMatch "^[1-9][0-9]*$" $replicas) -}}
          {{- fail (printf "The replica count for global.cluster.%s is not valid: [%s] is not a valid number" $k $replicas) -}}
        {{- end -}}
        {{- $replicas = (atoi $replicas | int) -}}
      {{- end -}}
    {{- end -}}
    {{- $m = set $m "replicas" $replicas -}}

    {{- $cluster = set $cluster $k $m -}}
  {{- end -}}
  {{- $cluster | toYaml -}}
{{- end -}}

{{- define "arkcase.cluster.info" -}}
  {{- $args :=
    dict
      "ctx" $
      "template" "__arkcase.cluster.info.compute"
  -}}
  {{- include "__arkcase.tools.getCachedValue" $args -}}
{{- end -}}

{{- define "arkcase.cluster" -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $) -}}
    {{- fail "The parameter value must be the root context" -}}
  {{- end -}}

  {{- $subsys := (include "arkcase.name" $) -}}
  {{- $rules := (include "arkcase.cluster.info.rules" $ | fromYaml) -}}
  {{- $cluster := dict "enabled" true "onePerHost" false "replicas" 1 "single" false -}}
  {{- if $rules.supported -}}
    {{- $info := (include "arkcase.cluster.info" $ | fromYaml) -}}
    {{- if and $info (hasKey $info $subsys) -}}
      {{- $info = get $info $subsys -}}
    {{- else -}}
      {{- $replicas := ($rules.replicas.def | int) -}}
      {{- $info = dict "enabled" true "onePerHost" false "replicas" $replicas "single" $info.single -}}
    {{- end -}}

    {{- /* apply the rules */ -}}
    {{- $replicas := 1 -}}
    {{- if not $info.single -}}
      {{- $replicas = (max ($info.replicas | int) ($rules.replicas.min | int)) -}}
      {{- $replicas = (le ($rules.replicas.max | int) 0 | ternary $replicas (min ($rules.replicas.max | int) $replicas)) -}}
    {{- end -}}
    {{- $cluster = set $info "replicas" $replicas -}}
  {{- end -}}
  {{- $cluster | toYaml -}}
{{- end -}}

{{- define "arkcase.cluster.env" -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The only parameter value must be the root context" -}}
  {{- end -}}

  {{- $config := (include "arkcase.cluster" $ctx | fromYaml) -}}
  {{- $env := list (dict "name" "CLUSTER_ENABLED" "value" "true") -}}
  {{- if $config.enabled -}}
    {{- $env = concat $env (include "arkcase.subsystem-access.env" (dict "ctx" $ "subsys" "zookeeper" "key" "zkHost" "name" "ZK_HOST") | fromYamlArray) -}}
  {{- end -}}
  {{- $env | toYaml -}}
{{- end -}}

{{- define "arkcase.cluster.tomcat.env" -}}
  {{- if not (include "arkcase.isRootContext" $) -}}
    {{- fail "The parameter value must be the root context" -}}
  {{- end -}}
  {{- $result := list -}}
  {{- range $k, $v := (include "arkcase.labels.matchLabels" $ | fromYaml) -}}
    {{- $result = append $result (printf "%s=%s" $k $v) -}}
  {{- end -}}
  {{- if $result }}
- name: KUBERNETES_NAMESPACE
  value: {{ $.Release.Namespace | quote }}
- name: KUBERNETES_LABELS
  value: {{ join "," $result | quote }}
- name: KUBERNETES_SERVICE
  value: {{ include "arkcase.service.name" $ | quote }}
- name: KUBERNETES_SERVICE_HEADLESS
  value: {{ include "arkcase.service.headless" $ | quote }}
  {{- end }}
{{- end -}}

{{- define "arkcase.cluster.statefulUpdateStrategy" -}}
  {{- if not (include "arkcase.isRootContext" $) -}}
    {{- fail "The parameter value must be the root context" -}}
  {{- end -}}
  {{- $type := ($.Values.updateStrategy | default "" | toString | default "RollingUpdate") -}}
type: {{ $type | quote }}
{{- end -}}

{{- define "arkcase.cluster.discovery.env" -}}
  {{- $ctx := $.ctx -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The parameter 'ctx' must be the root context" -}}
  {{- end -}}

  {{- $dnsPort := ($.port | toString | required "Must provide the name of the DNS port to search for") -}}
  {{- $dnsService := ($.service | default (include "arkcase.service.headless" $ctx)) -}}

- name: DNS_NAMESPACE
  value: {{ $ctx.Release.Namespace | quote }}
- name: DNS_SERVICE
  value: {{ $dnsService | quote }}
- name: DNS_PORT
  value: {{ $dnsPort | quote }}
{{- end -}}
