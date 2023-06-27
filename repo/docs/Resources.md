
# [ArkCase](https://www.arkcase.com/) Resource Requests and Limits

- [Basic Premise](#basic-premise)
- [Operating Modes](#operating-modes)
- [Abbreviated Syntax](#abbreviated-syntax)

This document describes the model and configuration for specifying the resource allocations - requests and/or limits - for Pods as part of the ArkCase deployment. As with any community-release project, Issues and PRs are always welcome to help move this code further along.

The ArkCase helm chart supports configuring pod resource requests and limits by way of a map whose fully-populated structure matches the following:

```yaml
global:
  resources:
    # The name of the chart or subsystem (i.e. content, search, rdbms, core, reports, etc.)
    # that the pod or container is housed in (the Alfresco example is used for illustration)
    content:

      # Within each chart's section you can either describe the "default" resources for the
      # pod that the chart will produce (i.e. for single-pod charts), or describe the allocations
      # for all sub-pods as part of the chart (like this example)

      # This is the abbreviated string syntax, which is fully described below.
      main: "200Mi-1536Mi,100m-500m"

      # This is another approach to describe the same thing with abbreviated strings (read the specs
      # below for details on the syntax)
      share:
        requests: "400Mi,200m"
        limits: "1Gi,500m"

      # Another alternative approach to achieve the same thing (again, read the specs below)
      activemq:
        cpu: "100m-500m"
        memory: "200Mi-1Gi"

      # The more "usual" syntax where we describe the entire thing as a map
      search:
        requests:
          memory: "200Mi"
          cpu: "200m"
        limits:
          memory: "2Gi"
          cpu: "500m"

    # Since the reports subchart has a singular pod (i.e. Pentaho), there's
    # no need to use subdivisions as was done for the "content" subchart.
    #
    # This abbreviated string syntax is identical to the map syntaxes below.
    #
    # reports: "*-2Gi,*-1"
    #
    # # Alt map #1
    # reports:
    #   limits: "2Gi,1"
    #
    # # Alt map #2
    reports:
      limits:
        memory: "2Gi"
        cpu: "1"

    # Other subcharts' resources may be described here
```

## <a name="basic-premise"></a>Basic Premise

The whole idea behind allowing this level of flexibility in declaring the resource allocations for pods is to permit a simplified syntax in the YAML, as well as more briefly declaring resource allocations using **--set** in the command line. By allowing the simplified string syntax, a single parameter can represent an entire map of values, like so:

`helm install arkcase arkcase/app --set global.resources.reports="1Gi-2Gi,0.5-1"`

The above command would render the entire application, setting the Pentaho chart's resource allocations as follows:

```yaml
resources:
  requests:
    memory: "1Gi"
    cpu: "0.5"
  limits:
    memory: "2Gi"
    cpu: "1"
```

Resource allocations described as part of the `global` map will ***ALWAYS*** override any allocations described internally in the chart, regardless of operating mode.

Furthermore, there are specific resource allocations described in the pods for use in ***development*** mode (see [this document](Development.md) for more details), to facilitate the deployment of the entire stack by developers while significantly lowering the resource requirements on their hardware.

The system will be fully functional, if somewhat performance constrained due to the imposed restrictions.  Developers may opt to increase these constraints by way of `global` values, or disabling the development values altogether by setting the value `global.dev.resources` to `"false"` (or, rather, any value other than `"true"` or `true`)

## <a name="operating-modes"></a>Operating Modes

There are three operating modes for the resource allocations:

* Default mode

  Default mode simply means to use the default resource allocations described for each (set of) pod(s) as described within each chart. This is generally viable for a small, fully-functional system with limited performance and load-bearing capacity. Specifically, this is good for demo systems, evaluation systems, and the such.

  It could also be used for production if you don't anticipate having to service more than a few (4 or fewer) users at once.

* Development mode

  Development mode means to use the minimal "possible" (as identified by our own testing) resource allocations for a fully-functional system, with performance not being a priority. This is generally useful for developers to deploy on their local K3d/K3s/K8s/Minikube clusters, without (hopefully) overwhelming their development systems. Development mode can be activated by setting the `global.dev.enabled` flag to a *true-value* (i.e. `"true"` or `true`), and either ***not*** setting the `global.dev.resources` flag, or explicitly setting it to a *true-value*.

  If development mode is enabled (i.e. `global.dev.enabled` is a *true-value*) and development resources are disabled (i.e. `global.dev.resources` is explicitly set to a *non-true-value*), then Default resources will be used instead (except if Overrides are provided).

* Override mode

  Override mode is simply setting the values for a given pod or chart via the `global.resources.*` map entries. These values will always be used and override any set values regardless of the other two modes. Override is designed to allow deployers the ability to describe the resource allocations in a `yaml` file, and use that during deployment.

### Addressing for Charts/Containers

Each (sub)chart within the ArkCase suite has a symbolic name:

* ***reports*** == Pentaho
* ***content*** == Alfresco
* ***search*** == Solr
* and so on

Within each chart there may be one or more pods that are instantiated, and whose resources are to be managed separately from each other. An example of this is the ***content*** chart (Alfresco), as it contains the following ***parts***:

* ***activemq***
* ***main*** (Content Server)
* ***search*** (Alfresco's Solr implementation)
* ***sfs*** (Shared File System - only used in Enterprise mode)
* ***share***
* ***transform-core-aio*** (Transformer AIO engine)
* ***transform-router*** (Transformation Router - only used in Enterprise mode)

The general structure for overriding a pod's resource allocation using the `global.resources` structure is as follows:

```yaml
global:
  resources:
    # First level: the name of the chart the pod resides in. If the chart onl
    # produces a single pod, this tends to be enough. Multi-pod charts will
    # likely require a 2nd level here, to distinguish between pods

    # This is an example of a single-pod chart's resource declarations
    reports:
      requests: ...
      limits: ...

    # This is an example of a multi-pod chart's resource declarations
    content:
      main:
        requests: ...
        limits: ...
      share:
        requests: ...
        limits: ...
      sfs:
        requests: ...
        limits: ...
      search:
        requests: ...
        limits: ...
      # ... etc ...
```

By using this strategy we allow granular control over the resource allocation while keeping the pods' configuration and template code fairly simple and easy to read.

## <a name="abbreviated-syntax"></a>Abbreviated Syntax

The resource allocations may be described either using a classical "requests-limits" map (i.e. [ResourceRequirements](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.27/#resourcerequirements-v1-core)), or using a few variations including an abbreviated string notation that facilitates declaring both requests and limits in a single string.

The high-level syntax is as follows: `MEMSPEC,CPUSPEC`. The elements are positional, so if you only want to produce a CPUSPEC, you must add the leading `,` character (i.e. `,0.5-1.5`). If you only wish to provide a MEMSPEC, then you can omit the CPUSPEC outright. This is by design as it's anticipated that the resource which tere will be the most interest in capping will be the memory.

Here's a breakdown of what MEMSPEC and CPUSPEC mean, and how to formulate them:

* MEMSPEC : ( MEM | REQMEM-LIMMEM )

  * MEM : When given in this form, and the context of use allows it, it means *use this value for both requests and limits*. This is an actual memory specification as described [here](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
  * REQMEM : The requests value for memory (use "\*" if you wish to not use any value). This is an actual RAM specification as described [here](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
  * LIMMEM : The limits value for memory (use "\*" if you wish to not use any value). This is an actual RAM specification as described [here](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)

* CPUSPEC : ( CPU | REQCPU-LIMCPU )

  * CPU : When given in this form, and the context of use allows it, it means *use this value for both requests and limits*. This is an actual CPU specification as described [here](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
  * REQCPU : The requests value for CPU (use "\*" if you wish to clear the value). This is an actual CPU specification as described [here](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
  * LIMCPU : The limits value for CPU (use "\*" if you wish to clear the value). This is an actual CPU specification as described [here](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)

Notably, empty strings will be ignored.

Here are some examples of strings, and what they mean:

|String|Explanation|
|800Mi,1|Set both requests and limits to 800Mi RAM and 1000m CPU|
|800Mi|Set both requests and limits to 800Mi RAM, no requests/limits on CPU|
|,1|Set both requests and limits to 1000m CPU, no requests/limits on RAM|
|200Mi-1536Mi,100m-500m|Request 200Mi of RAM and 100m CPU, and limit to 1536Mi RAM and 500m CPU|
|\*-2Gi,1.5-\*|Request 2Gi of RAM but no request for CPU, and limit to 1500m CPU, no limit for RAM|
|4Gi,\*-3|Request *and* limit to 4Gi of RAM, no CPU request, but limit to 3000m CPU|

In addition, maps may be described in an abbreviated form, like so:

```yaml
# See above for descriptions of CPUSPEC and MEMSPEC
resourcesExample:
  cpu: "CPUSPEC"
  memory: "MEMSPEC"
```

As a concrete example:

```yaml
concreteExample:
  cpu: "0.5-2000m"
  memory: "512Mi-4Gi"
```
Similarly, you can use a similar syntax to abbreviate the map in another manner, like so:

```yaml
# See above for descriptions of CPU and MEM
alternateExample:
  requests: "MEM,CPU"
  limits: "MEM,CPU"
```

Just remember to use single-values for MEM and CPU.

Finally, the complete syntax is supported, as described in the Kubernetes documentation:

```yaml
# See above for descriptions of CPU and MEM
finalExample:
  requests:
    memory: "MEM"
    cpu: "CPU"
  limits:
    memory: "MEM"
    cpu: "CPU"
```
