
# [ArkCase](https://www.arkcase.com/) Development Integration

This document describes the model and configuration for developers to integrate their local development environments with an ArkCase Helm chart deployment. As with any community-release project, Issues and PRs are always welcome to help move this code further along.

The ArkCase helm chart supports enabling development mode by way of a map whose fully-populated structure matches the following:

```yaml
global.dev:
  # Enable or disable development mode, explicitly ... if the global.dev map is not empty,
  # and this flag is not explicitly set to false, development features will be enabled. Development
  # mode will also be enabled in general (i.e. for persistence), except if the global.mode flag
  # is explicitly set to "production".
  enabled: true

  # Use the ArkCase WAR file or exploded WAR directory at this location for execution. It must be
  # an absolute path. If it's an absolute path, it's assumed to be an "exploded WAR" directory.
  # To indicate a file, you must use the syntax file://${absolutePathToFile}. If you want to be specific,
  # you can also use path://${absolutePathToDirectory} to also indicate an exploded WAR directory.
  war: "path:///mnt/c/Users/developer/workspace/ArkCase/WAR"
  # war: "file:///mnt/c/Users/developer/workspace/ArkCase/target/arkcase-webapp.war"

  # Use the ArkCase configuration zip file or exploded zip directory at this location for execution.
  # the syntax and logic is identical for the war component, except this is for the .arkcase configuration
  # file set.
  conf: "path:///mnt/c/Users/developer/.arkcase"

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

## Development vs. Production Mode

There are two major deployment modes for the application: [Development mode](#development-mode) and [production mode](#production-mode). There are important differences between the two, so you should endeavor to understand these before pressing further.

### <a name="development-mode"></a>Development

The mode of operation mainly affects the persistence layer. In *development* mode, all persistence is handled via ***hostPath*** volumes. In development mode it's still possible to configure the persistence layer to use a combination of rendered ***hostPath*** volumes, with actual cluster-provided volumes (i.e. [GlusterFS](https://www.gluster.org/), [Ceph](https://docs.ceph.com/en/quincy/), [NFS](https://en.wikipedia.org/wiki/Network_File_System), etc). You can find more details on how to do this [in this document](docs/Persistence.md).

The intent of supporting *development* mode is to facilitate the charts' use by developers in single-cluster environments, where persistence can be provided safely by a single host. This lowers the environment bar required for a developer to get an instance up and running, for testing and development purposes.

Enabling development mode may also enable many other features related to the deployment location for the actual ArkCase WAR file, as well as the configuration directory (a.k.a.: *.arkcase*). Through these features, Developers will be able to deploy the whole stack using custom ArkCase WAR files, configurations, and even run it in (remote) debugger mode.

Development mode can be explicitly enabled via the instructions in that document, or by enabling the configuration value:

```yaml
global.mode: "development"
```

Other (case-insensitive) abbreviations such as "dev", "devel", or "develop" are also accepted. If an invalid value is used, ***production*** mode is defaulted.

### <a name="production-mode"></a>Production

In *production* mode, the resources rendered are more apt for deployment on a normal, multi-node cluster environment. No hostPath volumes are rendered, and instead all generated persistence is managed via volume claim templates declared with each Pod or StatefulSet. The particulars of the persistence layer are described [here](Persistence.md).

Production mode is enabled implicitly by default, but may be enabled explicitly if you need to combine some of the features from production mode with other features from development mode. To enable production mode ***explicitly***, you'll need to set this configuration value (in YAML syntax):

```yaml
# Enable production mode
global.mode: "production"
```

If production mode is enabled, but a default *storageClassName* is not configured, all volume claim templates rendered will lack that setting and thus will be expected to be provisioned by the cluster with [the default storage class](https://kubernetes.io/docs/tasks/administer-cluster/change-default-storage-class/).

Finally, you may refer to the [documentation on the persistence layer](#persistence) for more details on how to configure persistence.

## Developer Workstations

***This documentation will be added soon***
