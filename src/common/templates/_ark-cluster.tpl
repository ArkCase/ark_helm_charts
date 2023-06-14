{{- define "arkcase.cluster.info.render" -}}
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
      {{- /* If "global.cluster" isn't a map, it must be a boolean value */ -}}
      {{- $cluster = dict "enabled" (not (empty (include "arkcase.toBoolean" $c))) -}}
    {{- end -}}
  {{- end -}}

  {{- /* Set/sanitize the general "enabled" value */ -}}
  {{- if not (hasKey $cluster "enabled") -}}
    {{- $cluster = set $cluster "enabled" false -}}
  {{- else -}}
    {{- $cluster = set $cluster "enabled" (not (empty (include "arkcase.toBoolean" $cluster.enabled))) -}}
  {{- end -}}

  {{- if $cluster.enabled -}}
    {{- /* Set/sanitize the general "onePerHost" value */ -}}
    {{- if (hasKey $cluster "onePerHost") -}}
      {{- $cluster = set $cluster "onePerHost" (not (empty (include "arkcase.toBoolean" $cluster.onePerHost))) -}}
    {{- else -}}
      {{- $cluster = set $cluster "onePerHost" false -}}
    {{- end -}}

    {{- $subsystems := omit $cluster "enabled" "onePerHost" -}}
    {{- $cluster = pick $cluster "enabled" "onePerHost" -}}

    {{- /* Sanitize the maps for each subsystem */ -}}
    {{- range $k, $v := $subsystems -}}
      {{- /* if it's a short syntax, turn it into a single map with the "enabled" flag */ -}}
      {{- $m := dict -}}

      {{- /* Sanitize the "enabled" flag */ -}}
      {{- if not (kindIs "map" $v) -}}
        {{- $m = set $m "enabled" (not (empty (include "arkcase.toBoolean" $v))) -}}
      {{- else -}}
        {{- $m = pick $v "enabled" "onePerHost" "nodes" -}}

        {{- if hasKey $m "enabled" -}}
          {{- $m = set $m "enabled" (not (empty (include "arkcase.toBoolean" $m.enabled))) -}}
        {{- else -}}
          {{- $m = set $m "enabled" true -}}
        {{- end -}}
      {{- end -}}

      {{- /* Sanitize the "onePerHost" flag */ -}}
      {{- if hasKey $m "onePerHost" -}}
        {{- $m = set $m "onePerHost" (not (empty (include "arkcase.toBoolean" $m.onePerHost))) -}}
      {{- else -}}
        {{- $m = set $m "onePerHost" $cluster.onePerHost -}}
      {{- end -}}

      {{- /* Sanitize the "nodes" count */ -}}
      {{- if $m.enabled -}}
        {{- $nodes := 2 -}}
        {{- if hasKey $m "nodes" -}}
          {{- $nodes = ($m.nodes | toString) -}}
          {{- if not (regexMatch "^[1-9][0-9]*$" $nodes) -}}
            {{- fail (printf "The node count for global.cluster.%s is not valid: [%s] is not a valid number" $k $nodes) -}}
          {{- end -}}
          {{- $nodes = max 1 (atoi $nodes | int) -}}
        {{- end -}}
        {{- $m = set $m "nodes" $nodes -}}
      {{- else -}}
        {{- $m = set $m "nodes" 1 -}}
      {{- end -}}

      {{- $cluster = set $cluster $k $m -}}
    {{- end -}}
  {{- else -}}
    {{- /* Make life simpler */ -}}
    {{- $cluster = dict "enabled" false "onePerHost" false -}}
  {{- end -}}

  {{- $cluster | toYaml -}}
{{- end -}}

{{- define "arkcase.cluster.info" -}}
  {{- if not (include "arkcase.isRootContext" $) -}}
    {{- fail "The parameter value must be the root context" -}}
  {{- end -}}

  {{- $cacheKey := "Clustering" -}}
  {{- $masterCache := dict -}}
  {{- if (hasKey $ $cacheKey) -}}
    {{- $masterCache = get $ $cacheKey -}}
    {{- if and $masterCache (not (kindIs "map" $masterCache)) -}}
      {{- $masterCache = dict -}}
    {{- end -}}
  {{- end -}}
  {{- $crap := set $ $cacheKey $masterCache -}}

  {{- $chartName := (include "arkcase.fullname" $) -}}
  {{- if not (hasKey $masterCache $chartName) -}}
    {{- $obj := (include "arkcase.cluster.info.render" $ | fromYaml) -}}
    {{- if not $obj -}}
      {{- $obj = dict -}}
    {{- end -}}
    {{- $masterCache = set $masterCache $chartName $obj -}}
  {{- end -}}
  {{- get $masterCache $chartName | toYaml -}}
{{- end -}}

{{- define "arkcase.cluster" -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $) -}}
    {{- fail "The parameter value must be the root context" -}}
  {{- end -}}

  {{- $subsys := (include "arkcase.name" $) -}}
  {{- $info := (include "arkcase.cluster.info" $ | fromYaml) -}}
  {{- if hasKey $info $subsys -}}
    {{- $info = get $info $subsys -}}
  {{- else -}}
    {{- $info = pick $info "enabled" "onePerHost" -}}
    {{- $info = set $info "nodes" ($info.enabled | ternary 2 1) -}}
  {{- end -}}
  {{- $info | toYaml -}}
{{- end -}}

{{- define "arkcase.cluster.enabled" -}}
  {{- $config := (include "arkcase.cluster" $ | fromYaml) -}}
  {{- if $config.enabled -}}
    {{- true -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.cluster.nodes" -}}
  {{- $config := (include "arkcase.cluster" $ | fromYaml) -}}
  {{- if hasKey $config "nodes" -}}
    {{- $config.nodes -}}
  {{- else -}}
    {{- 1 -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.cluster.onePerHost" -}}
  {{- $config := (include "arkcase.cluster" $ | fromYaml) -}}
  {{- $config.onePerHost | ternary "true" "" -}}
{{- end -}}

{{- define "arkcase.cluster.zookeeper" -}}
  {{- $config := (include "arkcase.cluster" $ | fromYaml) -}}
  {{- if $config.enabled -}}
    {{- $url := (include "arkcase.tools.conf" (dict "ctx" $ "value" "zookeeper.url") | default "zookeeper:2181") -}}
    {{- $zk := list -}}
    {{- range $u := (splitList "," $url | compact) -}}
      {{- /* $u must be of the form hostname[:port] */ -}}
      {{- if (not (regexMatch "^([^:]+)(:([1-9][0-9]*))?$" $u)) -}}
        {{- fail (printf "Bad ZooKeeper coordinate [%s] from URL spec: %s" $u $url) -}}
      {{- end -}}
      {{- $p := (splitList ":" $u) -}}
      {{- $port := 2181 -}}
      {{- $host := (include "arkcase.tools.mustSingleHostname" (first $p)) -}}
      {{- if gt (len $p) 1 -}}
        {{- $port = (last $p | toString | atoi) -}}
        {{- if or (lt $port 1) (gt $port 65535) -}}
          {{- fail (printf "Configuration error - the zookeeper port number [%d] must be in the range [1..65535] (from %s)" $port $u) -}}
        {{- end -}}
      {{- end -}}
      {{- $zk = append $zk (printf "%s:%d" $host $port) -}}
    {{- end -}}
    {{- join "," $zk -}}
  {{- end -}}
{{- end -}}
