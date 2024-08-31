# [ArkCase](https://www.arkcase.com/) Service Type Overrides for Helm

This document describes the model and configuration for overriding the default service configurations in order to employ alternative service types such as [NodePort](https://kubernetes.io/docs/concepts/services-networking/service/#type-nodeport) or [LoadBalancer](https://kubernetes.io/docs/concepts/services-networking/service/#loadbalancer), as well as adding labels or annotations to any rendered services. As with any community-release project, Issues and PRs are always welcome to help move this code further along.

  - [Base Model](#base-model)
  - [LoadBalancer Specifics](#loadbalancer)

## <a name="base-model"></a>Base Model

The helm charts support reconfiguring services in several ways in order to afford deployers flexibility when integrating the ArkCase deployment into their existing ecosystems. Services may be modified to be of type `NodePort`, `LoadBalancer`, or remain of type `ClusterIP` (the default). In particular, modifications here should not affect the ability to deploy [Ingress](Ingress.md) controllers alongside the customized services - this is'simply an alternative, or complimentary, means for exporting the required services (i.e. in the case of `NodePort` or `LoadBalancer` services.

This is achieved by way of overriding the service description via configurations, like so:

```yaml
global:
  service:

    # Direct modification using a string shortcut. These are the recognized, case-insensitive values
    # for "type-string" that may be used in configuration:
    #
    #   for LoadBalancer: LoadBalancer | LB
    #   for NodePort: NodePort | NP
    #   for ClusterIP: ClusterIP | default | def | "" (i.e. the empty string)
    #
    # Any other string value will result in a rendering error
    service-name-1: "type-string"

    # Full override by complete description
    service-name-2:
      # This string may be the same as the "type-string" described above...
      type: "type-string"

      # Optionally, when using type NodePort, you can declare the specific ports through which you wish
      # for individual service ports to be exported. Any ports you don't explicitly map here will be
      # automatically mapped by the cluster by whatever means it uses for that purpose, to whatever
      # port numbers it sees fit.
      #
      # The port description is a map (key-value pairs) where the key is the name of the service as
      # declared in the service's name (must be a string), and the value is the port number (in string
      # or numeric format) on which you wish the port to be exposed. The port number is validated to
      # be within the [1..65535] range.
      #
      # NodePort ranges are managed by the --nodeport-addresses parameter or the nodePortAddresses
      # configuration setting for kube-proxy. Thus, all port mappings must be within this range.
      # (see https://kubernetes.io/docs/concepts/services-networking/service/#type-nodeport)
      ports:
        http: 31345
        ssh: 31222
        imap: 31143
        imaps: 31993

      # Additionally, you may add labels that will be passed on to the service declaration,
      # in case you need to provide these for interaction with other objects in the cluster. All
      # keys and values will be converted to strings
      labels:
        "label-1": "value-1"
        "label-2": "value-2"
        "label-3": "value-3"
        # ...
        "label-N": "value-N"

      # Furthermore, you may add annotations that will be passed on to the service declaration,
      # in case you need to provide further configuration information. All keys and values will
      # be converted to strings
      annotations:
        "annotation-1": "value-1"
        "annotation-2": "value-2"
        "annotation-3": "value-3"
        # ...
        "annotation-N": "value-N"
```

[ClusterIP](https://kubernetes.io/docs/concepts/services-networking/service/#type-clusterip) access may be achieved by setting the `type-string` to `"CLusterIP"`, `"default"`, `"def"` (all case-insensitive), or leaving it out altogether. Port number mapping is not allowed in `ClusterIP` mode. You can, however, specify additional labels and annotations.

[NodePort](https://kubernetes.io/docs/concepts/services-networking/service/#type-nodeport) access may be achieved by setting the `type-string` to `"NodePort"` or `"NP"` (case-insensitive). Furthermore, you may provide the `ports:` mapping to specifi which individual ports should be mapped to which specific node ports. You can also specify additional labels and annotations.

[LoadBalancer](https://kubernetes.io/docs/concepts/services-networking/service/#loadbalancer) access may be achieved by setting the `type-string` to `"LoadBalancer"` or `"LB"` (case-insensitive). Port number mapping is not allowed in `LoadBalancer` mode. You can, however, specify additional labels and annotations.

## <a name="loadbalancer"></a>LoadBalancer Specifics

In `LoadBalancer` mode, there are additional settings that may be provided as part of a service override:

```yaml
global:
  service:
    service-name:
      type: "LoadBalancer"

      # These parameters are identical to the ones described in the Kubernetes documentation, and
      # are entirely optional.

      # The IP address from the Load Balancer to export the service on. Must be a valid IPv4 address
      loadBalancerIP: 1.2.3.4

      # The registered load balancer class to use
      loadBalancerClass: some-class-name

      # Enable or disable the allocateLoadBalancerNodePorts setting
      allocateNodePorts: true
```

These settings are entirely optional, and are exposed only to provide finer-grained control over the Load Balancer configuration to be deployed.
