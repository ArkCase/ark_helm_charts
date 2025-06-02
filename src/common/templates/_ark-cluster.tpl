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
      {{- /* If "global.cluster" isn't a map, it may only be the word "true" or "false" */ -}}
      {{- $cluster = dict "enabled" $cluster -}}
    {{- end -}}
  {{- end -}}

  {{- /* Set/sanitize the general "enabled" value */ -}}
  {{- $cluster = set $cluster "enabled" (hasKey $cluster "enabled" | ternary (not (empty (include "arkcase.toBoolean" $cluster.enabled))) true) -}}

  {{- /* Set/sanitize the general "onePerHost" value */ -}}
  {{- $cluster = set $cluster "onePerHost" ((hasKey $cluster "onePerHost") | ternary (not (empty (include "arkcase.toBoolean" $cluster.onePerHost))) false) -}}

  {{- $subsystems := omit $cluster "enabled" "onePerHost" -}}
  {{- $cluster = pick $cluster "enabled" "onePerHost" -}}

  {{- /* Sanitize the maps for each subsystem */ -}}
  {{- range $k, $v := $subsystems -}}

    {{- /* Can't use a list here */ -}}
    {{- if (kindIs "slice" $v) -}}
      {{- fail (printf "The cluster configuration value global.cluster.%s may not be a list" $k) -}}
    {{- end -}}

    {{- /* Support both map format, and a scalar value */ -}}
    {{- $m := dict -}}
    {{- if (kindIs "map" $v) -}}
      {{- $m = pick $v "enabled" "onePerHost" "replicas" -}}
    {{- else -}}
      {{- /* if it's a short syntax, then it can either be "true", "false", or the replica count */ -}}
      {{- $v = $v | toString -}}
      {{- if (regexMatch "^[1-9][0-9]*$" $v) -}}
        {{- /* If it's a number, it's the replica count we want (min == 1) */ -}}
        {{- $v = (atoi $v | int) -}}
        {{- $m = set $m "replicas" (max $v 1) -}}
        {{- $m = set $m "enabled" true -}}
      {{- else -}}
        {{- /* If it's not a number, it's parsed as a boolean value and used as "enabled" */ -}}
        {{- $m = set $m "enabled" (not (empty (include "arkcase.toBoolean" $v))) -}}
      {{- end -}}
    {{- end -}}

    {{- /* Sanitize the "onePerHost" flag */ -}}
    {{- $m = set $m "onePerHost" ((hasKey $m "onePerHost") | ternary (not (empty (include "arkcase.toBoolean" $m.onePerHost))) $cluster.onePerHost) -}}

    {{- /* Sanitize the "enabled" flag */ -}}
    {{- $m = set $m "enabled" ((hasKey $m "enabled") | ternary (not (empty (include "arkcase.toBoolean" $m.enabled))) $cluster.enabled) -}}

    {{- /* Sanitize the "replicas" count */ -}}
    {{- $replicas := 2 -}}
    {{- if $m.enabled -}}
      {{- if hasKey $m "replicas" -}}
        {{- $replicas = ($m.replicas | toString) -}}
        {{- if not (regexMatch "^[1-9][0-9]*$" $replicas) -}}
          {{- fail (printf "The replica count for global.cluster.%s is not valid: [%s] is not a valid number" $k $replicas) -}}
        {{- end -}}
        {{- $replicas = (atoi $replicas | int) -}}
      {{- end -}}
    {{- else -}}
      {{- /* If not enabled mode, we will only deploy one replica */ -}}
      {{- $replicas = 1 -}}
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
  {{- $cluster := dict "enabled" false "onePerHost" false "replicas" 1 -}}
  {{- if $rules.supported -}}
    {{- $info := (include "arkcase.cluster.info" $ | fromYaml) -}}
    {{- if and $info (hasKey $info $subsys) -}}
      {{- $info = get $info $subsys -}}
    {{- else -}}
      {{- $info = dict "enabled" false "onePerHost" false "replicas" ($rules.replicas.def | int) -}}
    {{- end -}}

    {{- /* apply the rules */ -}}
    {{- $replicas := 1 -}}
    {{- if $info.enabled -}}
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
