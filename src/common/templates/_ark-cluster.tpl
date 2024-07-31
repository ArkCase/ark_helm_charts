{{- define "arkcase.cluster.info.rules" -}}
  {{- /* Find the chart's own clustering rules */ -}}

  {{- $rules := (.Files.Get "cluster.yaml" | fromYaml) -}}
  {{- if (not (kindIs "map" $rules)) -}}
    {{- $rules = dict -}}
  {{- end -}}

  {{- $result := dict -}}
  {{- $result = set $result "supported" ((hasKey $rules "supported") | ternary (not (empty (include "arkcase.toBoolean" $rules.supported))) true) -}}

  {{- $nodes := dict "min" 1 "def" 1 "max" 1 -}}
  {{- if $result.supported -}}
    {{- $nodes = dict "min" 1 "def" 2 "max" 0 -}}
    {{- if (hasKey $rules "nodes") -}}
      {{- $nodes = ($rules.nodes | default dict) -}}

      {{- $min := 1 -}}
      {{- if (hasKey $nodes "min") -}}
        {{- $min = ($nodes.min | default 1 | toString) -}}
        {{- $min = (regexMatch "^[1-9][0-9]*$" $min | ternary ($min | atoi | int) 1 | int) -}}
      {{- end -}}

      {{- $def := 0 -}}
      {{- if (hasKey $nodes "def") -}}
        {{- $def = ($nodes.def | default 2 | toString) -}}
        {{- $def = (regexMatch "^[1-9][0-9]*$" $def | ternary ($def | atoi | int) 2 | int) -}}
        {{- $def = (eq $def 0 | ternary $def (max $def $min)) -}}
      {{- end -}}

      {{- $max := 0 -}}
      {{- if (hasKey $nodes "max") -}}
        {{- $max = ($nodes.max | default 0 | toString) -}}
        {{- $max = (regexMatch "^[1-9][0-9]*$" $max | ternary ($max | atoi | int) 0 | int) -}}
        {{- $max = (eq $max 0 | ternary $max (max $max $min)) -}}
      {{- end -}}

      {{- $nodes = dict "min" $min "def" $def "max" $max -}}
    {{- end -}}
  {{- end -}}
  {{- $result = set $result "nodes" $nodes -}}

  {{- $result | toYaml -}}
{{- end -}}

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
  {{- $cluster = set $cluster "enabled" ((hasKey $cluster "enabled") | ternary (not (empty (include "arkcase.toBoolean" $cluster.enabled))) false) -}}

  {{- if $cluster.enabled -}}
    {{- /* Set/sanitize the general "onePerHost" value */ -}}
    {{- $cluster = set $cluster "onePerHost" ((hasKey $cluster "onePerHost") | ternary (not (empty (include "arkcase.toBoolean" $cluster.onePerHost))) false) -}}

    {{- $subsystems := omit $cluster "enabled" "onePerHost" -}}
    {{- $cluster = pick $cluster "enabled" "onePerHost" -}}

    {{- /* Sanitize the maps for each subsystem */ -}}
    {{- range $k, $v := $subsystems -}}
      {{- /* if it's a short syntax, turn it into a single map with the "enabled" flag */ -}}
      {{- $m := dict -}}

      {{- /* Can't use a list here */ -}}
      {{- if (kindIs "slice" $v) -}}
        {{- fail (printf "The cluster configuration value global.cluster.%s may not be a list" $k) -}}
      {{- end -}}

      {{- /* Support both map format, and a scalar value */ -}}
      {{- if (kindIs "map" $v) -}}
        {{- $m = pick $v "enabled" "onePerHost" "nodes" -}}

        {{- /* Sanitize the "enabled" flag */ -}}
        {{- $m = set $m "enabled" (hasKey $m "enabled" | ternary (not (empty (include "arkcase.toBoolean" $m.enabled))) true) -}}
      {{- else -}}
        {{- $v = $v | toString -}}
        {{- if (regexMatch "^[1-9][0-9]*$" $v) -}}
          {{- /* If it's a number, it's the node count we want (min == 1) */ -}}
          {{- $v = (atoi $v | int) -}}
          {{- $m = set $m "nodes" (max $v 1) -}}
          {{- $m = set $m "enabled" (gt $m.nodes 1) -}}
        {{- else -}}
          {{- /* If it's a non-number, fold it into a boolean using toBoolean and use it as the "enabled" flag */ -}}
          {{- $m = set $m "enabled" (not (empty (include "arkcase.toBoolean" $v))) -}}
        {{- end -}}
      {{- end -}}

      {{- /* Sanitize the "onePerHost" flag */ -}}
      {{- $m = set $m "onePerHost" ((hasKey $m "onePerHost") | ternary (not (empty (include "arkcase.toBoolean" $m.onePerHost))) $cluster.onePerHost) -}}

      {{- /* Sanitize the "nodes" count */ -}}
      {{- $nodes := 1 -}}
      {{- if $m.enabled -}}
        {{- $nodes = 2 -}}
        {{- if hasKey $m "nodes" -}}
          {{- $nodes = ($m.nodes | toString) -}}
          {{- if not (regexMatch "^[1-9][0-9]*$" $nodes) -}}
            {{- fail (printf "The node count for global.cluster.%s is not valid: [%s] is not a valid number" $k $nodes) -}}
          {{- end -}}
          {{- $nodes = (atoi $nodes | int) -}}
        {{- end -}}
      {{- end -}}
      {{- $m = set $m "nodes" $nodes -}}

      {{- $cluster = set $cluster $k $m -}}
    {{- end -}}
  {{- else -}}
    {{- /* Make life simpler */ -}}
    {{- $cluster = dict "enabled" false "onePerHost" false "nodes" 1 -}}
  {{- end -}}

  {{- $cluster | toYaml -}}
{{- end -}}

{{- define "arkcase.cluster.info" -}}
  {{- if not (include "arkcase.isRootContext" $) -}}
    {{- fail "The parameter value must be the root context" -}}
  {{- end -}}

  {{- $cacheKey := "ArkCase-Clustering" -}}
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
  {{- $rules := (include "arkcase.cluster.info.rules" $ | fromYaml) -}}
  {{- $cluster := dict "enabled" false "onePerHost" false "nodes" 1 -}}
  {{- if $rules.supported -}}
    {{- $info := (include "arkcase.cluster.info" $ | fromYaml) -}}

    {{- /* Clustering has to be enabled globally first! */ -}}
    {{- $enabled := and (hasKey $info "enabled") (not (empty (include "arkcase.toBoolean" $info.enabled))) -}}

    {{- if $enabled -}}
      {{- if and $info (hasKey $info $subsys) -}}
        {{- $info = get $info $subsys -}}
      {{- else -}}
        {{- $nodes := ($rules.nodes.def | int) -}}
        {{- $info = dict "enabled" (gt $nodes 1) "onePerHost" false "nodes" $nodes -}}
      {{- end -}}

      {{- /* apply the rules */ -}}
      {{- if $info.enabled -}}
        {{- $nodes := (max ($info.nodes | int) ($rules.nodes.min | int)) -}}
        {{- $nodes = (le ($rules.nodes.max | int) 0 | ternary $nodes (min ($rules.nodes.max | int) $nodes)) -}}
        {{- $cluster = set $info "nodes" $nodes -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
  {{- $cluster | toYaml -}}
{{- end -}}

{{- define "arkcase.cluster.env" -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The only parameter value must be the root context" -}}
  {{- end -}}

  {{- $config := (include "arkcase.cluster" $ctx | fromYaml) -}}
  {{- if $config.enabled -}}
- name: ZK_HOST
  valueFrom:
    configMapKeyRef:
      name: {{ printf "%s-zookeeper" $ctx.Release.Name | quote }}
      key: ZK_HOST
      optional: false
  {{- end -}}
{{- end -}}

{{- define "arkcase.cluster.tomcat.nodeId" -}}
  {{- $result := list -}}
  {{- range (until 15) -}}
    {{- $result = append $result (randInt -128 127) -}}
  {{- end -}}
  {{- $result = append $result "${NODE_ID}" -}}
  {{- printf "{%s}" (join "," $result) -}}
{{- end -}}

{{- define "arkcase.cluster.tomcat" -}}
  {{- if not (kindIs "map" $) -}}
    {{- fail "The parameter must either be the root context ($ or .), or a map with the 'ctx' value pointing to the root context" -}}
  {{- end -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- if or (not (hasKey $ "ctx")) (not (include "arkcase.isRootContext" $.ctx)) -}}
      {{- fail "The 'ctx' dictionary parameter value must be the root context" -}}
    {{- end -}}
    {{- $ctx = $.ctx -}}
  {{- end -}}

  {{- $cluster := (include "arkcase.cluster" $ctx | fromYaml) }}

  {{- /* Allow the caller to specify the maximum number of nodes to render for */ -}}
  {{- /* (if no value is given, use 255 as the upper limit */ -}}
  {{- $max := ((hasKey $ "max") | ternary ($.max | toString | atoi | max 1) 255 | int) -}}

  {{- /* Enforce the upper limit of $max nodes */ -}}
  {{- $nodes := min $max ($cluster.nodes | toString | atoi | int) }}
  {{- /* Enforce the lower limit of 1 node */ -}}
  {{- $nodes = (max 1 $nodes | int) -}}
  {{- if and $cluster.enabled (gt $nodes 1) }}
<Cluster className="org.apache.catalina.ha.tcp.SimpleTcpCluster"
         channelStartOptions="3"
         channelSendOptions="8">
  <Manager className="org.apache.catalina.ha.session.DeltaManager"
           expireSessionsOnShutdown="false"
           notifyListenersOnReplication="true"/>
  <Channel className="org.apache.catalina.tribes.group.GroupChannel">
    <Receiver className="org.apache.catalina.tribes.transport.nio.NioReceiver"
              address="auto"
              port="4000"
              autoBind="100"
              selectorTimeout="5000"
              maxThreads="6" />
    <Sender className="org.apache.catalina.tribes.transport.ReplicationTransmitter">
      <Transport className="org.apache.catalina.tribes.transport.nio.PooledParallelSender" />
    </Sender>
    <Interceptor className="org.apache.catalina.tribes.group.interceptors.TcpFailureDetector" />
    <Interceptor className="org.apache.catalina.tribes.group.interceptors.TcpPingInterceptor" />
    <Interceptor className="org.apache.catalina.tribes.group.interceptors.MessageDispatchInterceptor" />
    <Interceptor className="org.apache.catalina.tribes.group.interceptors.StaticMembershipInterceptor">
      {{- $service := (include "arkcase.name" $) }}
      {{- $pod := (include "arkcase.fullname" $) }}
      {{- $nodeId := (include "arkcase.cluster.tomcat.nodeId" $) }}
      <LocalMember className="org.apache.catalina.tribes.membership.StaticMember"
                   domain="{{ $pod }}"
                   uniqueId="{{ $nodeId }}" />

      {{- range $n := (until $nodes) }}
      <Member className="org.apache.catalina.tribes.membership.StaticMember"
              port="4000"
              securePort="-1"
              host="{{ printf "%s-%d.%s" $pod $n $service }}"
              domain="{{ $pod }}"
              uniqueId="{{ $nodeId | replace "${NODE_ID}" ($n | toString) }}" />
      {{- end }}
    </Interceptor>
  </Channel>
  <Valve className="org.apache.catalina.ha.tcp.ReplicationValve"
         filter="" />
  <Valve className="org.apache.catalina.ha.session.JvmRouteBinderValve" />
  <ClusterListener className="org.apache.catalina.ha.session.ClusterSessionListener" />
</Cluster>
  {{- end }}
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
  {{- end }}
{{- end -}}

{{- define "arkcase.cluster.statefulUpdateStrategy" -}}
  {{- if not (include "arkcase.isRootContext" $) -}}
    {{- fail "The parameter value must be the root context" -}}
  {{- end -}}
  {{- $type := ($.Values.updateStrategy | default "" | toString | default "RollingUpdate") -}}
  {{- $cluster := (include "arkcase.cluster" $ | fromYaml) -}}
  {{- $nodes := ($cluster.nodes | default 1 | int) -}}
type: {{ $type | quote }}
  {{- if and ($cluster.enabled) (eq $type "RollingUpdate") (gt $nodes 1) }}
# We're allowed to lose up to half our nodes ({{ $nodes }}) in a rolling update
rollingUpdate:
  partition: {{ div $nodes 2 }}
  {{- end }}
{{- end -}}
