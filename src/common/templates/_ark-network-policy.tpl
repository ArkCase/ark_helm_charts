{{- /*
Network policies lock down a release's pods, and then open access to them one service at a time:

  * The chart that deploys the release (i.e. "app") renders the baseline (arkcase.network-policy.baseline):
      - "${fullname}-baseline": selects all the release's pods, denies all their incoming
        traffic, and allows their outgoing traffic only towards the release's pods, and
        towards name resolution
      - "${fullname}-external": allows egress to public IP addresses for the release's pods that
        bear the arkcase.com/external-access label (arkcase.network-policy.labels.external),
        which only the workload pods of charts that set networkPolicy.externalAccess do. Public
        addresses are all but the non-public ones (see __arkcase.network-policy.non-public). Public
        addresses may be denied via global.networkPolicy.external.denyPublic (a list of public
        CIDRs), and non-public ones allowed via global.networkPolicy.external.allowPrivate (a list
        of non-public CIDRs). Only IPv4 is supported for now: IPv6 egress stays closed.
      - "${fullname}-kube-api": allows egress to the Kubernetes API for the release's pods that
        bear the arkcase.com/kube-api-access label (arkcase.network-policy.labels.kube-api),
        which only the workload pods of charts that set networkPolicy.kubeApiAccess do. The API's
        endpoints aren't pods, and NetworkPolicies usually see the endpoints the "kubernetes"
        Service's address is translated to, which may change at any time (i.e. control plane
        nodes or network interfaces being replaced). If Kyverno is available, it tracks them and keeps
        the NetworkPolicy in sync (see __arkcase.network-policy.kube-api.policy). Otherwise, it "fails
        open" as "${fullname}-kube-api-fail-open": all ports on the private network ranges (see
        __arkcase.network-policy.kube-api).

  * Each internal service (via arkcase.subsystem.service) renders "${service}-ingress", which
    allows access to the service's pods on the service's declared ports, from the release's pods.
    The release's pods may reach each other, but only on the ports each one opened. Ports the service doesn't publish (i.e. clustering, monitoring) may be
    opened for its pods via service[.${part}].ingress, a list of:

        - name: "cluster"         # Optional, for documentation
          protocol: "TCP"         # Optional, TCP by default
          port: 61617             # The pod's port
          from: "release"         # Optional: "release" (the default: any of the release's pods),
                                  # "peers" (only the pods behind the same service), or a list of
                                  # NetworkPolicyPeer declarations (i.e. a monitoring namespace)

  * The chart that renders an Ingress renders "${ingress}-ingress-${service}" for each of its
    backend services, allowing access to the backend ports from anywhere
    (arkcase.network-policy.ingress), since the ingress controller's whereabouts (namespace,
    pod labels, cloud load balancer addresses) aren't known.

Nothing outside of the release (not even other pods in its namespace) is reachable other than name
resolution, unless the pod is allowed external access: not even the Kubernetes API, nor externally-provided
subsystems. Nothing outside of the release may reach its pods, other than on the ports published through
an Ingress.

The policies are rendered by default, and may be disabled via global.networkPolicy.enabled (or by
setting global.networkPolicy to false). The name resolution peers may be set in global.networkPolicy.dns
as a list of NetworkPolicyPeer declarations (the default is the kube-dns pods in kube-system).
*/ -}}

{{- define "arkcase.network-policy.conf" -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The parameter given must be the root context (. or $)" -}}
  {{- end -}}

  {{- $conf := ($ctx.Values.global | default dict).networkPolicy -}}
  {{- if (kindIs "invalid" $conf) -}}
    {{- $conf = dict -}}
  {{- else if not (kindIs "map" $conf) -}}
    {{- $conf = dict "enabled" $conf -}}
  {{- end -}}

  {{- $enabled := (or (not (hasKey $conf "enabled")) (not (empty (include "arkcase.toBoolean" $conf.enabled)))) -}}

  {{- $dns := list (dict "namespaceSelector" (dict "matchLabels" (dict "kubernetes.io/metadata.name" "kube-system")) "podSelector" (dict "matchLabels" (dict "k8s-app" "kube-dns"))) -}}
  {{- if (hasKey $conf "dns") -}}
    {{- if not (kindIs "slice" $conf.dns) -}}
      {{- fail (printf "The value global.networkPolicy.dns must be a list of NetworkPolicyPeer declarations (it's a %s)" (kindOf $conf.dns)) -}}
    {{- end -}}
    {{- $dns = $conf.dns -}}
  {{- end -}}

  {{- $external := ($conf.external | default dict) -}}
  {{- if not (kindIs "map" $external) -}}
    {{- fail (printf "The value global.networkPolicy.external must be a map (it's a %s)" (kindOf $external)) -}}
  {{- end -}}
  {{- range $k := (list "denyPublic" "allowPrivate") -}}
    {{- if and (hasKey $external $k) (not (kindIs "slice" (get $external $k))) -}}
      {{- fail (printf "The value global.networkPolicy.external.%s must be a list of CIDRs (it's a %s)" $k (kindOf (get $external $k))) -}}
    {{- end -}}
  {{- end -}}
  {{- $external = dict "denyPublic" ($external.denyPublic | default list) "allowPrivate" ($external.allowPrivate | default list) -}}

  {{- dict "enabled" $enabled "dns" $dns "external" $external | toYaml -}}
{{- end -}}

{{- /*
The ranges the Kubernetes API's in-cluster endpoints live in, unless the API's endpoint is public
(i.e. for clusters whose control plane is in the same private network as the nodes, or reachable
through it: kubeadm, k3s, OpenShift, EKS, private AKS/GKE). Link-local addresses (169.254.0.0/16,
where cloud instance metadata services live) are deliberately left out.
*/ -}}
{{- define "__arkcase.network-policy.kube-api" -}}
- comment: "RFC 1918: private networks"
  cidrs: [ "10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16" ]
- comment: "RFC 6598: shared address space (carrier-grade NAT)"
  cidrs: [ "100.64.0.0/10" ]
{{- end -}}

{{- /*
The IPv4 ranges that aren't publicly routable, grouped by the RFC that reserves them: the ones
for private use (RFC 1918, RFC 6598), the ones a host uses locally (link-local, loopback, "this
network"), and the rest of IANA's special-purpose ranges that aren't globally reachable.
*/ -}}
{{- define "__arkcase.network-policy.non-public" -}}
- comment: "RFC 1918: private networks"
  cidrs: [ "10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16" ]
- comment: "RFC 6598: shared address space (carrier-grade NAT)"
  cidrs: [ "100.64.0.0/10" ]
- comment: "RFC 3927: link-local (dynamic configuration, cloud instance metadata at 169.254.169.254)"
  cidrs: [ "169.254.0.0/16" ]
- comment: "RFC 1122: \"this network\", and loopback"
  cidrs: [ "0.0.0.0/8", "127.0.0.0/8" ]
- comment: "RFC 6890: IETF protocol assignments"
  cidrs: [ "192.0.0.0/24" ]
- comment: "RFC 5737: documentation"
  cidrs: [ "192.0.2.0/24", "198.51.100.0/24", "203.0.113.0/24" ]
- comment: "RFC 2544: benchmarking"
  cidrs: [ "198.18.0.0/15" ]
- comment: "RFC 5771: multicast"
  cidrs: [ "224.0.0.0/4" ]
- comment: "RFC 1112: reserved for future use (including the 255.255.255.255 broadcast address)"
  cidrs: [ "240.0.0.0/4" ]
{{- end -}}

{{- define "__arkcase.network-policy.pow2" -}}
  {{- $result := 1 -}}
  {{- range (until (int $)) -}}
    {{- $result = (mul $result 2) -}}
  {{- end -}}
  {{- $result -}}
{{- end -}}

{{- /*
Parse an IPv4 CIDR into a map with its canonical form ("cidr", host bits cleared), its network
address as an integer ("base"), and its prefix length ("prefix"). Fails if it's not valid.

Parameter: the CIDR, or a dict with the CIDR as "cidr" and the setting it came from as "source"
*/ -}}
{{- define "__arkcase.network-policy.cidr" -}}
  {{- $cidr := ($ | toString) -}}
  {{- $source := "global.networkPolicy" -}}
  {{- if (kindIs "map" $) -}}
    {{- $cidr = ($.cidr | toString) -}}
    {{- $source = ($.source | default $source) -}}
  {{- end -}}
  {{- $octet := "(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])" -}}
  {{- if not (regexMatch (printf "^%s(\\.%s){3}/(3[0-2]|[12]?[0-9])$" $octet $octet) $cidr) -}}
    {{- fail (printf "Invalid IPv4 CIDR [%s] in %s (only IPv4 is supported)" $cidr $source) -}}
  {{- end -}}
  {{- $parts := (splitList "/" $cidr) -}}
  {{- $prefix := (atoi (last $parts)) -}}
  {{- $address := 0 -}}
  {{- range $o := (splitList "." (first $parts)) -}}
    {{- $address = (add (mul $address 256) (atoi $o)) -}}
  {{- end -}}
  {{- $size := (include "__arkcase.network-policy.pow2" (sub 32 $prefix) | atoi) -}}
  {{- $base := (mul (div $address $size) $size) -}}
  {{- $octets := list -}}
  {{- range $shift := (list 16777216 65536 256 1) -}}
    {{- $octets = append $octets (mod (div $base $shift) 256 | toString) -}}
  {{- end -}}
  {{- dict "cidr" (printf "%s/%d" (join "." $octets) $prefix) "base" $base "prefix" $prefix | toYaml -}}
{{- end -}}

{{- /* Output "true" if the CIDR "inner" is within (or equal to) the CIDR "outer" (both parsed) */ -}}
{{- define "__arkcase.network-policy.cidr.within" -}}
  {{- $size := (include "__arkcase.network-policy.pow2" (sub 32 (int $.outer.prefix)) | atoi) -}}
  {{- if and (ge (int $.inner.prefix) (int $.outer.prefix)) (eq (div (int64 $.inner.base) $size) (div (int64 $.outer.base) $size)) -}}
    {{- true -}}
  {{- end -}}
{{- end -}}

{{- /*
Compute the destinations for egress beyond the release: all addresses except the non-public ones and
the denied public ones, plus the non-public CIDRs expressly allowed. The result is a map with:

  except: the list of groups ({comment, cidrs}) excluded from 0.0.0.0/0
  allow: the list of non-public CIDRs allowed

Parameter: the "external" map computed by arkcase.network-policy.conf
*/ -}}
{{- define "__arkcase.network-policy.external.destinations" -}}
  {{- $groups := (include "__arkcase.network-policy.non-public" $ | fromYamlArray) -}}
  {{- $nonPublic := list -}}
  {{- range $g := $groups -}}
    {{- range $c := $g.cidrs -}}
      {{- $nonPublic = append $nonPublic (include "__arkcase.network-policy.cidr" $c | fromYaml) -}}
    {{- end -}}
  {{- end -}}

  {{- $denied := list -}}
  {{- range $c := $.denyPublic -}}
    {{- $public := (include "__arkcase.network-policy.cidr" (dict "cidr" $c "source" "global.networkPolicy.external.denyPublic") | fromYaml) -}}
    {{- if (eq 0 (int $public.prefix)) -}}
      {{- fail (printf "The CIDR %s in global.networkPolicy.external.denyPublic denies all addresses: don't grant external access instead" $c) -}}
    {{- end -}}
    {{- range $n := $nonPublic -}}
      {{- if (include "__arkcase.network-policy.cidr.within" (dict "inner" $public "outer" $n)) -}}
        {{- fail (printf "The CIDR %s in global.networkPolicy.external.denyPublic isn't public (it's within %s), so it's denied already" $c $n.cidr) -}}
      {{- end -}}
    {{- end -}}
    {{- $denied = append $denied $public.cidr -}}
  {{- end -}}
  {{- if $denied -}}
    {{- $groups = append $groups (dict "comment" "Denied via global.networkPolicy.external.denyPublic" "cidrs" ($denied | uniq)) -}}
  {{- end -}}

  {{- $allowed := list -}}
  {{- range $c := $.allowPrivate -}}
    {{- $private := (include "__arkcase.network-policy.cidr" (dict "cidr" $c "source" "global.networkPolicy.external.allowPrivate") | fromYaml) -}}
    {{- $valid := false -}}
    {{- range $n := $nonPublic -}}
      {{- if (include "__arkcase.network-policy.cidr.within" (dict "inner" $private "outer" $n)) -}}
        {{- $valid = true -}}
      {{- end -}}
    {{- end -}}
    {{- if not $valid -}}
      {{- fail (printf "The CIDR %s in global.networkPolicy.external.allowPrivate isn't within a non-public range, so it's allowed already (unless denied via denyPublic)" $c) -}}
    {{- end -}}
    {{- $allowed = append $allowed $private.cidr -}}
  {{- end -}}
  {{- dict "except" $groups "allow" ($allowed | uniq) | toYaml -}}
{{- end -}}

{{- define "arkcase.network-policy.enabled" -}}
  {{- if (include "arkcase.network-policy.conf" $ | fromYaml).enabled -}}
    {{- true -}}
  {{- end -}}
{{- end -}}

{{- /*
Render the label that grants a pod access to public addresses outside of the release, if the chart's
networkPolicy.externalAccess value is true. Included by arkcase.labels.workload, so all of the
chart's workload pods bear it (but not its test pods).

Parameter: the root context (either "." or "$")
*/ -}}
{{- define "arkcase.network-policy.labels.external" -}}
  {{- if and (include "arkcase.network-policy.enabled" $) (include "arkcase.toBoolean" ($.Values.networkPolicy | default dict).externalAccess) -}}
    {{- include "__arkcase.network-policy.label.external" $ -}}
  {{- end -}}
{{- end -}}

{{- define "__arkcase.network-policy.label.external" -}}
arkcase.com/external-access: "true"
{{- end -}}

{{- /*
Render the label that grants a pod access to the Kubernetes API, if the chart's
networkPolicy.kubeApiAccess value is true. Included by arkcase.labels.workload, so all of the
chart's workload pods bear it (but not its test pods).

Parameter: the root context (either "." or "$")
*/ -}}
{{- define "arkcase.network-policy.labels.kube-api" -}}
  {{- if and (include "arkcase.network-policy.enabled" $) (include "arkcase.kube-api.access" $) -}}
    {{- include "__arkcase.network-policy.label.kube-api" $ -}}
  {{- end -}}
{{- end -}}

{{- define "__arkcase.network-policy.label.kube-api" -}}
arkcase.com/kube-api-access: "true"
{{- end -}}

{{- /*
Convert a list of service port specifications into the list of NetworkPolicyPort
declarations for the pods behind the service (i.e. targetPort takes precedence)
*/ -}}
{{- define "__arkcase.network-policy.ports" -}}
  {{- $result := list -}}
  {{- range $p := $ -}}
    {{- $result = append $result (dict "protocol" (coalesce $p.protocol "TCP") "port" (int ($p.targetPort | default $p.port))) -}}
  {{- end -}}
  {{- $result | uniq | toYaml -}}
{{- end -}}

{{- /* The NetworkPolicyPeer for the release's pods (in the policy's namespace) */ -}}
{{- define "__arkcase.network-policy.peer.release" -}}
podSelector:
  matchLabels:
    app.kubernetes.io/instance: {{ $.Release.Name | quote }}
{{- end -}}

{{- define "__arkcase.network-policy.metadata" -}}
  {{- $ctx := $.ctx -}}
name: {{ $.name | quote }}
namespace: {{ $ctx.Release.Namespace | quote }}
labels: {{- include "arkcase.labels" $ctx | nindent 2 }}
  {{- with ($ctx.Values.labels).common }}
    {{- toYaml . | nindent 2 }}
  {{- end }}
  {{- with ($ctx.Values.annotations).common }}
annotations: {{- toYaml . | nindent 2 }}
  {{- end }}
{{- end -}}

{{- /*
Render the baseline network policies for the release, which lock down all its pods (see above)

Parameter: the root context (either "." or "$")
*/ -}}
{{- define "arkcase.network-policy.baseline" -}}
  {{- $ctx := $ -}}
  {{- $conf := (include "arkcase.network-policy.conf" $ctx | fromYaml) -}}
  {{- if $conf.enabled }}
    {{- $fullname := (include "arkcase.fullname" $ctx) }}
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {{- include "__arkcase.network-policy.metadata" (dict "ctx" $ctx "name" (printf "%s-baseline" $fullname)) | nindent 2 }}
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/instance: {{ $ctx.Release.Name | quote }}
  policyTypes: [ "Ingress", "Egress" ]
  # No incoming traffic is allowed, except what each service allows for its own pods
  egress:
    # The release's pods, which only accept traffic on the ports their services allow
    - to:
        - {{ include "__arkcase.network-policy.peer.release" $ctx | indent 10 | trim }}
    # Name resolution
    - to: {{- $conf.dns | toYaml | nindent 8 }}
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {{- include "__arkcase.network-policy.metadata" (dict "ctx" $ctx "name" (printf "%s-external" $fullname)) | nindent 2 }}
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/instance: {{ $ctx.Release.Name | quote }}
      {{- include "__arkcase.network-policy.label.external" $ctx | nindent 6 }}
  policyTypes: [ "Egress" ]
  egress:
    {{- $destinations := (include "__arkcase.network-policy.external.destinations" $conf.external | fromYaml) }}
    - to:
        # Public addresses: everything but the non-public ones (and the denied ones)
        - ipBlock:
            cidr: "0.0.0.0/0"
            except:
    {{- range $group := $destinations.except }}
              # {{ $group.comment }}
      {{- range $cidr := $group.cidrs }}
              - {{ $cidr | quote }}
      {{- end }}
    {{- end }}
    {{- with $destinations.allow }}
        # Allowed via global.networkPolicy.external.allowPrivate
      {{- range $cidr := . }}
        - ipBlock:
            cidr: {{ $cidr | quote }}
      {{- end }}
    {{- end }}
    {{- include "__arkcase.network-policy.kube-api.policy" (dict "ctx" $ctx "fullname" $fullname) }}
  {{- end }}
{{- end -}}

{{- /*
Render the ingress rules for the additional ports declared for a service's pods (see above)

Parameter: a dict with two keys:
             - ctx = the root context (either "." or "$")
             - model = the service model (see __arkcase.subsystem.service.model)
*/ -}}
{{- define "__arkcase.network-policy.ingress.extra" -}}
  {{- $ctx := $.ctx -}}
  {{- $model := $.model -}}
  {{- $rules := list -}}
  {{- range $i := $model.ingress -}}
    {{- if not (kindIs "map" $i) -}}
      {{- fail (printf "The ingress declarations for service %s must be maps (found a %s)" $model.name (kindOf $i)) -}}
    {{- end -}}
    {{- $label := ($i.name | default $i.port | toString) -}}
    {{- $port := ($i.port | default "" | toString) -}}
    {{- if not (regexMatch "^[1-9][0-9]*$" $port) -}}
      {{- fail (printf "The ingress declaration [%s] for service %s must have a numeric port (%s)" $label $model.name $port) -}}
    {{- end -}}

    {{- $from := ($i.from | default "release") -}}
    {{- $peers := list -}}
    {{- if (kindIs "slice" $from) -}}
      {{- $peers = $from -}}
    {{- else if (eq "release" ($from | toString)) -}}
      {{- $peers = list (include "__arkcase.network-policy.peer.release" $ctx | fromYaml) -}}
    {{- else if (eq "peers" ($from | toString)) -}}
      {{- $peers = list (dict "podSelector" (dict "matchLabels" $model.selector)) -}}
    {{- else -}}
      {{- fail (printf "The 'from' value for ingress declaration [%s] for service %s must be 'release', 'peers', or a list of NetworkPolicyPeer declarations (%s)" $label $model.name ($from | toString)) -}}
    {{- end -}}

    {{- $rules = append $rules (dict "from" $peers "ports" (list (dict "protocol" ($i.protocol | default "TCP") "port" (atoi $port)))) -}}
  {{- end -}}
  {{- $rules | toYaml -}}
{{- end -}}

{{- /*
Render the network policy that allows access to the pods behind a service, on its ports

Parameter: a dict with two keys:
             - ctx = the root context (either "." or "$")
             - model = the service model (see __arkcase.subsystem.service.model)
*/ -}}
{{- define "arkcase.network-policy.service" -}}
  {{- $ctx := $.ctx -}}
  {{- $model := $.model -}}
  {{- if and $model (not $model.external) $model.ports (include "arkcase.network-policy.enabled" $ctx) }}
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {{- include "__arkcase.network-policy.metadata" (dict "ctx" $ctx "name" (printf "%s-ingress" $model.name)) | nindent 2 }}
spec:
  podSelector:
    matchLabels: {{- $model.selector | toYaml | nindent 6 }}
  policyTypes: [ "Ingress" ]
  ingress:
    # The service's ports, from the release's pods
    - from:
        - {{ include "__arkcase.network-policy.peer.release" $ctx | indent 10 | trim }}
      ports: {{- include "__arkcase.network-policy.ports" $model.ports | nindent 8 }}
    {{- with (include "__arkcase.network-policy.ingress.extra" (dict "ctx" $ctx "model" $model) | fromYamlArray) }}
    # Ports the service doesn't publish
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- end }}
{{- end -}}

{{- /*
Compute the service models (see __arkcase.subsystem.service.model) for the services that
the given chart and all its subcharts render. Subcharts that don't declare services (i.e.
library charts, or charts that don't use the ArkCase service layout) are skipped.

Parameter: the root context (either "." or "$")
*/ -}}
{{- define "__arkcase.network-policy.serviceModels" -}}
  {{- $ctx := $ -}}
  {{- $models := list -}}
  {{- if and (ne "library" ($ctx.Chart.Type | default "")) (kindIs "map" $ctx.Values.service) -}}
    {{- /* The services' template names aren't visible here, so assume each part's service is named after it */ -}}
    {{- range $partname := (concat (list "") (keys (omit $ctx.Values.service "ports" "ingress" "type" "probes" "canDebug") | sortAlpha)) -}}
      {{- $models = concat $models (include "arkcase.subsystem.service.models" (dict "ctx" $ctx "subname" $partname "part" $partname) | fromYamlArray) -}}
    {{- end -}}
  {{- end -}}
  {{- range $name, $sub := ($ctx.Subcharts | default dict) -}}
    {{-
      $subctx := dict
        "Values" $sub.Values
        "Chart" $sub.Chart
        "Release" $sub.Release
        "Files" $sub.Files
        "Capabilities" $sub.Capabilities
        "Subcharts" $sub.Subcharts
        "Template" $ctx.Template
    -}}
    {{- $models = concat $models (include "__arkcase.network-policy.serviceModels" $subctx | fromYamlArray) -}}
  {{- end -}}
  {{- $models | toYaml -}}
{{- end -}}

{{- /*
Render the network policies that allow access to an Ingress' backend services. The backends
are resolved to the pods (and pod ports) behind them using the same service models that
render the services themselves, for the chart that renders the Ingress and all its subcharts.
Backends that can't be resolved (i.e. services rendered elsewhere, or provided externally)
are skipped.

Parameter: a dict with these keys:
             - ctx = the root context (either "." or "$")
             - name = the name of the Ingress
             - rules = the list of Ingress rules (as in the Ingress' spec.rules)
*/ -}}
{{- define "arkcase.network-policy.ingress" -}}
  {{- $ctx := $.ctx -}}
  {{- if (include "arkcase.network-policy.enabled" $ctx) -}}
    {{- $backends := dict -}}
    {{- range $rule := ($.rules | default list) -}}
      {{- range $path := (dig "http" "paths" list $rule) -}}
        {{- $service := (dig "backend" "service" dict $path) -}}
        {{- if $service.name -}}
          {{- $backends = set $backends $service.name (append (get $backends $service.name | default list) ($service.port | default dict)) -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}

    {{- $models := dict -}}
    {{- if $backends -}}
      {{- range $model := (include "__arkcase.network-policy.serviceModels" $ctx | fromYamlArray) -}}
        {{- if not $model.external -}}
          {{- $models = set $models $model.name $model -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}

    {{- range $serviceName := (keys $backends | sortAlpha) -}}
      {{- if not (hasKey $models $serviceName) -}}
        {{- continue -}}
      {{- end -}}
      {{- $model := get $models $serviceName -}}

      {{- $ports := list -}}
      {{- range $port := (get $backends $serviceName) -}}
        {{- range $p := $model.ports -}}
          {{- if or (and $port.number (eq (int $port.number) (int $p.port))) (and $port.name (eq ($port.name | toString) ($p.name | toString))) -}}
            {{- $ports = append $ports $p -}}
          {{- end -}}
        {{- end -}}
      {{- end -}}

      {{- if $ports }}
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {{- include "__arkcase.network-policy.metadata" (dict "ctx" $ctx "name" (printf "%s-ingress-%s" $.name $serviceName)) | nindent 2 }}
spec:
  podSelector:
    matchLabels: {{- $model.selector | toYaml | nindent 6 }}
  policyTypes: [ "Ingress" ]
  ingress:
    # The ingress controller may be anywhere (in-cluster, or a cloud load balancer)
    - ports: {{- include "__arkcase.network-policy.ports" $ports | nindent 8 }}
      {{- end }}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{- /*
Render the policy that allows the release's pods bearing the arkcase.com/kube-api-access label to reach
the Kubernetes API. If Kyverno's GeneratingPolicy (policies.kyverno.io/v1, Kyverno 1.19.1 or later) is
available, a GeneratingPolicy keeps a NetworkPolicy in sync with the API's actual endpoints (the
default/kubernetes EndpointSlice) and the "kubernetes" Service's address. Otherwise, the API's endpoints
can't be tracked, so the policy fails open towards the private network ranges.

Parameter: a dict with two keys:
             - ctx = the root context (either "." or "$")
             - fullname = the base name for the policies
*/ -}}
{{- define "__arkcase.network-policy.kube-api.policy" -}}
  {{- $ctx := $.ctx -}}
  {{- $selector := (merge (dict "app.kubernetes.io/instance" $ctx.Release.Name) (include "__arkcase.network-policy.label.kube-api" $ctx | fromYaml)) -}}
  {{- if ($ctx.Capabilities.APIVersions.Has "policies.kyverno.io/v1/GeneratingPolicy") }}
    {{- $name := (printf "%s-kube-api" $.fullname) }}
    {{- /* Kyverno manages the generated NetworkPolicy, not Helm */ -}}
    {{- $networkPolicyLabels := (omit (include "arkcase.labels" $ctx | fromYaml) "app.kubernetes.io/managed-by") }}
---
apiVersion: policies.kyverno.io/v1
kind: GeneratingPolicy
metadata:
  # It's cluster-scoped, so it must be unique across namespaces
  name: {{ printf "%s-%s" $ctx.Release.Namespace $name | quote }}
  labels: {{- include "arkcase.labels" $ctx | nindent 4 }}
    {{- with ($ctx.Values.labels).common }}
      {{- toYaml . | nindent 4 }}
    {{- end }}
    {{- with ($ctx.Values.annotations).common }}
  annotations: {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  evaluation:
    # Create the NetworkPolicy right away, keep it in sync with the endpoints, and delete it along with this policy
    generateExisting:
      enabled: true
    synchronize:
      enabled: true
    orphanDownstreamOnPolicyDelete:
      enabled: false
  matchConstraints:
    # Only the API's EndpointSlice, so no other EndpointSlice's changes ever reach Kyverno on our account
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: "default"
    objectSelector:
      matchLabels:
        kubernetes.io/service-name: "kubernetes"
    resourceRules:
      - apiGroups: [ "discovery.k8s.io" ]
        apiVersions: [ "v1" ]
        # UPDATE must always be included, lest a no-op update delete the generated NetworkPolicy
        operations: [ "CREATE", "UPDATE" ]
        resources: [ "endpointslices" ]
        resourceNames: [ "kubernetes" ]
  variables:
    # Each endpoint's first address (they're fungible), and the ports they serve the API on
    - name: addresses
      expression: >-
        (has(object.endpoints) ? object.endpoints : []).filter(e, has(e.addresses) && size(e.addresses) > 0).map(e, e.addresses[0])
    - name: endpointPorts
      expression: >-
        (has(object.ports) ? object.ports : []).filter(p, has(p.port)).map(p, dyn({"protocol": dyn(has(p.protocol) ? p.protocol : "TCP"), "port": dyn(p.port)}))
    # The "kubernetes" Service's address, for CNIs that apply policies before translating it to the endpoints'
    - name: service
      expression: >-
        resource.Get("v1", "services", "default", "kubernetes")
    - name: servicePorts
      expression: >-
        variables.service.spec.ports.map(p, dyn({"protocol": dyn(has(p.protocol) ? p.protocol : "TCP"), "port": dyn(p.port)}))
    - name: egress
      expression: >-
        (size(variables.addresses) > 0
          ? [ dyn({"to": dyn(variables.addresses.map(a, dyn({"ipBlock": dyn({"cidr": dyn(a + (a.contains(":") ? "/128" : "/32"))})}))), "ports": dyn(variables.endpointPorts)}) ]
          : [])
        + [ dyn({"to": dyn([ dyn({"ipBlock": dyn({"cidr": dyn(variables.service.spec.clusterIP + (variables.service.spec.clusterIP.contains(":") ? "/128" : "/32"))})}) ]), "ports": dyn(variables.servicePorts)}) ]
    - name: networkPolicy
      expression: >-
        {
          "apiVersion": dyn("networking.k8s.io/v1"),
          "kind": dyn("NetworkPolicy"),
          "metadata": dyn({
            "name": dyn({{ $name | toJson }}),
            "labels": dyn({{ $networkPolicyLabels | toJson }})
          }),
          "spec": dyn({
            "podSelector": dyn({ "matchLabels": dyn({{ $selector | toJson }}) }),
            "policyTypes": dyn([ "Egress" ]),
            "egress": dyn(variables.egress)
          })
        }
  generate:
    - expression: >-
        generator.Apply({{ $ctx.Release.Namespace | toJson }}, [ variables.networkPolicy ])
  {{- else }}
    {{- $kubeApi := (include "__arkcase.network-policy.kube-api" $ctx | fromYamlArray) }}
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {{- include "__arkcase.network-policy.metadata" (dict "ctx" $ctx "name" (printf "%s-kube-api-fail-open" $.fullname)) | nindent 2 }}
spec:
  podSelector:
    matchLabels: {{- $selector | toYaml | nindent 6 }}
  policyTypes: [ "Egress" ]
  egress:
    # Kyverno isn't available to track the Kubernetes API's endpoints, so allow the private networks they live in (fail open)
    - to:
    {{- range $group := $kubeApi }}
        # {{ $group.comment }}
      {{- range $cidr := $group.cidrs }}
        - ipBlock:
            cidr: {{ $cidr | quote }}
      {{- end }}
    {{- end }}
  {{- end }}
{{- end -}}
