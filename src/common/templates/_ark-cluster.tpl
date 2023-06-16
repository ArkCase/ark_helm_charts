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

      {{- /* Can't use a list here */ -}}
      {{- if (kindIs "slice" $v) -}}
        {{- fail (printf "The cluster configuration value global.cluster.%s may not be a list" $k) -}}
      {{- end -}}

      {{- /* Support both map format, and a scalar value */ -}}
      {{- if (kindIs "map" $v) -}}
        {{- $m = pick $v "enabled" "onePerHost" "nodes" -}}

        {{- /* Sanitize the "enabled" flag */ -}}
        {{- if hasKey $m "enabled" -}}
          {{- $m = set $m "enabled" (not (empty (include "arkcase.toBoolean" $m.enabled))) -}}
        {{- else -}}
          {{- $m = set $m "enabled" true -}}
        {{- end -}}
      {{- else -}}
        {{- $v = $v | toString -}}
        {{- if (regexMatch "^[0-9]+$" $v) -}}
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

{{- define "arkcase.cluster.tomcat.nodeId" -}}
  {{- $result := list -}}
  {{- range (until 15) -}}
    {{- $result = append $result (randInt -128 127) -}}
  {{- end -}}
  {{- $result = append $result "${NODE_ID}" -}}
  {{- printf "{%s}" (join "," $result) -}}
{{- end -}}

{{- define "arkcase.cluster.tomcat" -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $) -}}
    {{- fail "The parameter value must be the root context" -}}
  {{- end -}}
  {{- $cluster := (include "arkcase.cluster" $ | fromYaml) }}
  {{- $nodes := ($cluster.nodes | int) }}
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
