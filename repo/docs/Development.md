
# [ArkCase](https://www.arkcase.com/) Development Integration

- [Enabling Host Path Persistence](#hostpath)
- [Developer Workstations](#workstations)

This document describes the model and configuration for developers to integrate their local development environments with an ArkCase Helm chart deployment. As with any community-release project, Issues and PRs are always welcome to help move this code further along.

The ArkCase helm chart supports enabling development mode by way of a map whose fully-populated structure matches the following:

```yaml
global:
  dev:
    # Enable or disable development mode, explicitly ... if the global.dev map is not empty,
    # and this flag is not explicitly set to false, development features will be enabled.
    enabled: true

    # Use the ArkCase WAR file or exploded WAR directory at this location for execution. It must be
    # an absolute path. If it's an absolute path, it's assumed to be an "exploded WAR" directory.
    # To indicate a file, you must use the syntax file://${absolutePathToFile}. If you want to be specific,
    # you can also use path://${absolutePathToDirectory} to also indicate an exploded WAR directory.
    #
    # This will result in the use of a hostPath volume by the core pod(s)
    war: "path:///mnt/c/Users/developer/workspace/ArkCase/WAR"
    # war: "file:///mnt/c/Users/developer/workspace/ArkCase/target/arkcase-webapp.war"

    # Use the ArkCase configuration zip file or exploded zip directory at this location for execution.
    # the syntax and logic is identical for the war component, except this is for the .arkcase configuration
    # file set.
    #
    # This will result in the use of a hostPath volume by the core pod(s)
    conf: "path:///mnt/c/Users/developer/.arkcase"
    # conf: "file:///mnt/c/Users/developer/workspace/ArkCase/target/.arkcase.zip"

    # The settings in this map govern the debugging features
    debug:
      # Whether to enable or disable debugger features. Debugger features will be enabled if the debug map
      # is not empty, and the enabled flag is not explicitly set to "false"
      enabled: true

      # The port to listen on for JDB connections. If not specified, the default of 8888 is used.
      port: 8888

      # This setting governs the "suspend" setting in the debugger configuration for the JVM, and is useful
      # to stop execution of any code until and unless a debugger connects to the instance (i.e. for
      # debugging bootup issues). The default value is "false".
      suspend: true
```

## <a name="hostpath"></a>Enabling Host Path Persistence

Among the helm charts available for deployment is the `arkcase/hostpath-provisioner` chart. This chart will deploy a CSI provisioner service that will allow the use of `HostPath` volumes backed by a cluster node's local filesystem. This provisioner should only be used in single-node cluster environments (i.e. development environments) since the provisioner doesn't fully support multi-node clusters. In particular: when a volume is provisioned by this component, even though it's visible to the entire cluster, only one of the nodes will contain the data (the node on which the provisioner is running), and this data will only be accessible to pods running on that node.

Hence, why it's only appropriate in single-node clusters: no such discrepancy will arise.

In order to deploy the provisioner, you may use the following command:

`$ helm install --create-namespace --namespace hostpath-provisioner hostpath-provisioner arkcase/hostpath-provisioner`

The provisioner has many available configurations. The most important one is the value `hostPath`, which indicates the place within the node's filesystem the volumes will be provisioned (the default is `/opt/app`):

```yaml
# Set the host path to /k8s/hostPath
hostPath: "/k8s/hostPath"
```

The path must normalize (i.e. after removing `.` and `..` components) to an absolute path, or an error will result. The component creates a `storageClass` with the name `hostpath` (this name is configurable via the `storageClass.name` value), which can also be earmarked as the default storage class for the cluster (this behavior can be overridden with the value `storageClass.defaultClass`).

## <a name="workstations"></a>Developer Workstations

***This documentation will be added soon***
