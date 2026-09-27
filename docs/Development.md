
# [ArkCase](https://www.arkcase.com/) Development Integration

- [Enabling Host Path Persistence](#hostpath)
- [Developer Workstations](#workstations)
- [Developer Ingress](#ingress)

This document describes the model and configuration for developers to integrate their local development environments with an ArkCase Helm chart deployment. As with any community-release project, Issues and PRs are always welcome to help move this code further along.

The ArkCase helm chart supports enabling development mode by way of a map whose fully-populated structure matches the following:

```yaml
global:
  dev:
    #
    # Enable or disable development mode, explicitly ... if the global.dev map is not empty,
    # and this flag is not explicitly set to false, development features will be enabled.
    #
    enabled: true

    #
    # These settings control the UID under which the ArkCase and Portal applications will
    # be executed in development mode. This is important to enable the developer to be able
    # to read and write live to the possibly shared WAR files/directories at runtime.
    #
    # The default values are 1000/1000, and should only be modified if your Linux numeric UID
    # is different from 1000, and/or your default GID is different from 1000
    #
    # uid: 1000
    # gid: 1000
    #

    #
    # This section controls the development mode for the ArkCase pod
    #
    arkcase:

      #
      # Debug-related settings
      #
      debug:
        #
        # Whether to enable or disable debugger features. Debugger features will be enabled if the debug map
        # is not empty, and the enabled flag is not explicitly set to "false"
        #
        enabled: true

        #
        # This setting governs the "suspend" setting in the debugger configuration for the JVM, and is useful
        # to stop execution of any code until and unless a debugger connects to the instance (i.e. for
        # debugging bootup issues). The default value is "false".
        #
        suspend: true

      #
      # This section allows you to modify existing loggers, or add new ones.  The format
      # is a map, where the key is the name of the logger, and the value is the Log4J level
      # (for safety, quote both strings ... we've had some strange behavior with unquoted
      # strings).
      #
      # Importantly, a master flag (enabled) is supported, and can be used to turn on or off
      # all the custom logs at once. Its value is assumed as "true" if it's not specified.
      #
      logs:
        # enabled: true
        "my.new.logger": "debug"
        "org.eclipse.persistence.logging.metadata": "off"
        # ... etc

      #
      # Use the given WAR files or exploded WAR directories listed for execution. The path must be
      # an absolute path. If the path specification has a "path:" prefix, it's assumed to be a
      # local directory containing an "exploded WAR" directory structure.
      #
      # To indicate a file (i.e. an actual WAR file), you must use the prefix "file:".
      #
      # This will result in the use of a hostPath volume by the ArkCase pod that will point to
      # either the given file or directory.
      #
      # Directories will be directly accessible by the Tomcat runtime, while files will instead
      # be treated like normal artifacts and be extracted and deployed during the deployment phase.
      #
      wars:
        arkcase: "path:/mnt/c/Users/developer/workspace/ArkCase/WAR"

    #
    # This section controls the development mode for the ArkCase pod
    #
    portal:
      #
      # This section is structured almost identically to the "arkcase:" section, above.
      #
      # The main difference is that the "logs:" section has no effect.
      #
      wars:
        "arkcase#external": "path:/......"
        foia: "path:/......"
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

## <a name="ingress"></a>Developer Ingress

For development mode, the Ingress that's normally created for production access is also created, with some key additions:

* The ingress supports access by both the `global.baseUrl` value, as well as the hostname `localhost.localdomain`. You can create an entry in your `/etc/hosts` file pointing that name to 127.0.0.1 (if one doesn't exist already), and access the application at [https://localhost.localdomain:8443/arkcase](https://localhost.localdomain:8443/arkcase)
* If a certificate is declared for the ingress, then that certificate must be valid, trusted, and match the hostname value from the `global.baseUrl` setting
* If a certificate is _*not*_ declared for the Ingress, a temporary one will be created each time, since HTTPS access is now required.
  * Chrome may have some HSTS complaints, which can be resolved following this procedure:
    1. Access this link: [chrome://flags/#allow-insecure-localhost](chrome://flags/#allow-insecure-localhost)
    1. Toggle the setting _*Allow invalid certificates for resources loaded from localhost*_ to _*Enabled*_
    1. Access this link: [chrome://net-internals/#hsts](chrome://net-internals/#hsts)
    1. Enter "localhost.localdomain" in the text box for _*Delete domain security policies*_
    1. Click "Delete"
    1. Enter "localhost" in the text box for _*Delete domain security policies*_
    1. Click "Delete"
    1. Enter "localhost.localdomain" in the text box for _*Query HSTS/PKP domain*_
    1. Click "Query" ... You should receive a result of _*Not found*_
    1. Enter "localhost" in the text box for _*Query HSTS/PKP domain*_
    1. Click "Query" ... You should receive a result of _*Not found*_
  * Firefox may be more flexible in terms of the SSL requirements
  * It's up to each developer to resolve this for other browsers
* In development mode, all supporting applications are made available in the same endpoint as the application (and thus the same SSL issues listed above apply):
  * /alfresco (for Alfresco Content Server)
  * /share (for Alfresco Share)
  * /pentaho (for Pentaho)
  * /solr (for Solr)
  * /console (for Artemis)
