# [ArkCase](https://www.arkcase.com/) Persistence Configuration

## Table of Contents

* [Introduction](#introduction)
* [Enable or Disable Persistence](#enable-disable)
* [Setting Default Values](#defaults)
* [Default Persistence Mode](#default-mode)
* [Overriding Volumes](#overriding-volumes)
* [Volume String Syntax](#volume-string-syntax)

## <a name="introduction"></a>Introduction

This document describes how to configure the persistence layer for the ArkCase helm charts to suit your needs. Generally speaking, you likely will not need to configure too many parameters on a normal deployment. As with any community-release project, Issues and PRs are always welcome to help move this code further along.

ArkCase relies on **PersistentVolumeClaim** (PVC) templates to access **PersistentVolume** (PV) resources which it (generally) expects the cluster infrastructure (or some other actor) to provision. It may also leverage specifically declared PVC resources, as well as specifically tailored PV resources. However, great effort has gone towards not requiring such manipulations of the persistence layer.

Here's an example of a simple configuration that should work on a production environment:

```yaml
# Example contents of conf.yaml
global:
  persistence:
    default:
      storageClassName: "glusterfs"
```

Then deploy, like so:

    $ helm install arkcase arkcase/arkcase -f conf.yaml

And that's it. This should yield a fully-working ArkCase stack, with all required components, and with all storage volumes using storage class `glusterfs`. During deployment, the infrastructure will be expected to fulfill all rendered volume claim templates by automatically provisioning volumes (or attaching to existing ones), or bind the incoming claims to already-existing volumes accordingly.

Alternatively, production deployment can be selected by setting the appropriate mode, but without setting a default value for *storageClassName*, which will result in the volume claims using [the cluster's default storage class](https://kubernetes.io/docs/tasks/administer-cluster/change-default-storage-class/):

```yaml
# Example contents of conf.yaml
global:
  mode: "production"
```
Then deploy, like so:

    $ helm install arkcase arkcase/arkcase -f conf.yaml

This will result in a similar cluster with production persistence, but relying on the cluster's configured default storage class.

## <a name="enable-disable"></a>Enable or Disable Persistence

Persistence is enabled by default. The persistence layer can be disabled completely by setting this value:

```yaml
global:
  persistence:
    # Set to false if you wish to disable persistence
    enabled: true
```

If the value `global.persistence.enabled` is not set, its value will be defaulted to "true". If it's set, and its string value is equal to `"true"` (case-insensitively), then the persistence layer will be enabled as well.

If the value is explicitly set to any other value, then a value of `"false"` will be assumed and persistence will be ***disabled***. This means that ***all volumes will be rendered as ephemeral (emptyDir) volumes***, and thus their data will be lost as soon as the pods go down.

## <a name="defaults"></a>Setting Default Values

The persistence layer supports setting default values that will be used by the volume claim template generator whenever it needs that value, but has no other source for it.

These are the default values that can be configured, in YAML syntax:

```yaml
global:
  # The default value for mode is "development"
  # Can be set case-insesitively, and must be one of
  # "production" (prod is equivalent), or
  # "development" (develop, devel, dev are equivalent)
  #
  # hostPath volumes are only allowed in development mode
  mode: "development"

  persistence:
    default:
      # The default value for accessModes is [ "ReadWriteOnce" ]
      # Can be set case-insensitively, and supports abbreviations
      # such as RWM, RWO (RW is equivalent), and ROM (RO is equivalent)
      #
      # Can be specified as a list (JSON or YAML format), or a string of
      # CSV values (i.e. "RWM,RWO,RO").
      accessModes: [ "ReadWriteOnce" ]

      # The default value for capacity is 1Gi
      # Can be set case-insensitively
      capacity: "4Gi"

      # The default value for hostPathRoot is "/opt/app"
      hostPathRoot: "/directory/where/relative/hostPath/volumes/will/reside"

      # No default value for persistentVolumeReclaimPolicy
      # Can be set case-insensitively, and must be one of
      # Retain, Recycle, or Delete
      persistentVolumeReclaimPolicy: "retain"

      # No default value for storageClassName
      storageClassName: "..."

      # The default value for volumeMode is "Filesystem"
      # Can be set case-insensitively, and must be one of
      # "Filesystem" or "Block"
      volumeMode: "Block"
```

## <a name="default-mode"></a>Default Persistence Mode

The current default for the helm charts is to deploy ArkCase in ***development*** mode. This means that all volumes will be described as ***hostPath*** volumes, and will be allocated based on the `global.persistence.default.hostPathRoot` configuration (by default this has a value of `/opt/app`).

The path that a volume is stored in will be computed as follows:

- If no path is given explicitly (or an empty path is given), then use this formula: `${hostPathRoot}/${namespace}/${releaseName}/${component}/${volumeName}`.
  - The value ***hostPathRoot*** will be the value set for `global.persistence.default.hostPathRoot`, or the default value as specified above.
  - The value ***namespace*** refers to the K8s namespace into which the deployment is being executed
  - The value ***releaseName*** is the release name given to the Helm release
  - The value ***component*** is the component that will consume the volume (i.e. *core*, *search*, *reports*, *rdbms*, etc.)
  - The value ***volumeName*** is the name of the volume, as referenced within the consuming component
- If a non-empty, relative path is given explicitly, use this formula: `${hostPathRoot}/${relativePath}`
- If a non-empty, absolute path is given explicitly, use that path directly regardless of any other configurations

Volumes in hostPath mode are specified in mode ***DirectoryOrCreate***, which means that if the target path does not exist, it will be created by the cluster to satisfy the requirements. If this creation fails, the volume bind operation will eventually fail, and the affected pods will fail to boot up.

*Please note that **hostPath** volumes are only supported in **development** mode*

Production mode is enabled when:

- `global.mode` is explicitly set to the value ***production***
- `global.mode` is not set to any value, and `global.persistence.default.storageClassName` is set to a non-empty value

In all other instances, *development* mode will be active.

***NOTE**: this default behavior **may** change soon, making **production** the default mode, and requiring explicit configuration of **development** mode.*

## <a name="overriding-volumes"></a>Overriding Volumes

For specific deployments, it may be desirable to override specific volumes. For example: you may want to leverage NVMe storage for ArkCase's NodeJS files, or use gusterfs storage for Alfresco's content store. The point is: for specific deployments, you may want a more nuanced persistence configuration.

This configruation framework gives you enough rope to hang yourself with, and then some. :)

Specifically, you can override ***any*** component's persistence volume configuration using global properties. The general pattern for overriding a component's volume description is as follows:

```yaml
global:
  persistence:
    volumes:
      # ${component} means the name of the component whose volume this is
      # i.e. "core", "content", "search", etc.
      ${component}:
        # ${volume} means the name of the volume you're seeking to customize
        ${volume}:
          # ... actual configuration ...
```

The `actual configuration` for a volume can either be a string (see [this section for more information on the supported syntax](#volume-string-syntax)), or a map which describes how you wish to override the volume. The string syntax facilitates override specifications because it allows the condensation of information into a single line, using (relatively) easy-to-read statements.

The alternative to using a string is to use a map to describe the override in more detail. The map may contain exactly one of 3 supported keys: `claim`, `volume`, and `path`. Defining more than one results in a Helm error that fails the deployment.  Please note that even at this stage, the `claim:`, `volume:` or `path:` may also be described using a string, for convenience.

As an example, if you wanted to override the ***core*** component's ***home*** volume to be supplied by the ***nvme*** storage class, with a minimum capacity of ***4Gi***, you could achieve that with a configuration similar to this one:

```yaml
# This is an example of overriding the core component's home volume for NVMe, with at least 4Gi
# space available
global:
  persistence:
    volumes:
      core:
        home:
          claim:
            spec:
              storageClassName: "nvme"
              resources:
                requests:
                  storage: "4Gi"
```

For brevity and ease of reading in the following examples, we're going to shorten the "global-persistence-volumes" map path to a simpler "global.persistence.volumes", which is still valid in YAML, but most importantly it makes things a bit easier to read.

This configuration snippet attempts to describe all the forms in which a volume override may be described.  Each volume entry will have a brief comment describing what the configuration seeks to accomplish:

```yaml
global.persistence.volumes:

  # We use the name "widget" for our example component, for brevity
  widget:

    ################################################################################
    # FIRST, THE MORE VERBOSE METHODS                                              #
    ################################################################################
  
    # Apply the full PVC description as a template. The PVC will seek to
    # bind to an nvme volume of at least 16Gi in ReadWriteMany mode
    able:
      claim:
         # ... PersistentVolumeClaim (see doc links, below)
         metadata:
           labels:
             # ... add some labels
           annotations:
             # ... add some annotations
         spec:
           storageClassName: "nvme"
           accessModes:
             - ReadWriteMany
           resources:
             requests:
               storage: "16Gi"

    # Create a new PV, using nfs and of exactly 64Gi size, in ReadWriteOnce mode,
    # and connecting to the server at 172.17.0.2, on path /data/beta, while also providing
    # some mount flags
    bravo:
      volume:
         # ... PersistentVolumeSpec (see links, below)
         storageClassName: "nfs"
         capacity:
           storage: "64Gi"
         accessModes: [ "ReadWriteOnce" ]
        mountOptions:
          - hard
          - nfsvers=4.1
        nfs:
          path: /data/beta
          server: 172.17.0.2

    # Create a hostPath volume (if applicable) for charlie, which mounts the contents
    # of the path /var/log/chuck as the volume
    charlie:
      path: "/var/log/chuck"

    ################################################################################
    # NEXT, USING THE FANCY STRING SYNTAX                                          #
    ################################################################################

    # Create a PVC template using glusterfs as the storageClassName, and with 8Gi
    # resource requests, in ReadWriteMany or ReadWriteOnce modes, whichever one matches first
    dog: "pvc://glusterfs/8Gi#RWM,ReadWriteOnce"

    # Create a PVC template using the cluster's default-configured storageClassName (or our
    # specifically configured storageClassName), and with 1Gi resource requests, in
    # ReadWriteOnce mode
    easy: "pvc:///1Gi#RW"

    # Bind to the specific PVC resource named "myFoxyPvc", which would be managed external to the helm
    # chart
    fox: "pvc:myFoxyPvc"

    # Create an nvme volume that's 32Gi in size, and will be mounted in ReadWriteMany mode
    george: "pv://nvme/32Gi#RWM"

    # Bind this volume to the existing PV resource named "howYouLikeDisVolume"
    how: "vol://howYouLikeDisVolume"

    # This will render a hostPath volume, housed in ${hostPathRoot}/my-item-volume
    item: "my-item-volume"

    # This will render a hostPath volume, housed in "/opt/app/j"
    jig: "/opt/app/j"

    ################################################################################
    # FINALLY, USING THE COMBINATION MAP AND FANCY STRING SYNTAX                   #
    ################################################################################

    # Similar to the above examples, except the string is tied to the "claim:" stanza
    king:
      # claim: "pvc://.../..."
      # claim: "pvc:queenOfVolumes"
      
      # This is identical to "pvc:kingOfAllVolumes"
      claim: "kingOfAllVolumes"

    # Similar to the above examples, except the string is tied to the "volume:" stanza
    love:
      # volume: "pv://.../..."
      # volume: "vol://volumeIDoNotLove"
      
      # This is identical to "vol://loveThisVolume"
      volume: "loveThisVolume"

    # Similar to the above examples, except the string is tied to the "path:" stanza
    mike:
      # volume: "relative/path/for/mike"
      
      volume: "/opt/app/michael"

```

Some helpful reference docs:

* [PersistentVolumeSpec](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.27/#persistentvolumespec-v1-core)
* [PersistentVolumeClaim](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.27/#persistentvolumeclaim-v1-core)

## <a name="volume-string-syntax"></a>Volume String Syntax

To facilitate rapid configuration, we've developed a library that allows deployers to describe volume overrides using a fairly simple and direct string syntax, while retaining much of the power of directly customizing volumes via full claim declarations.

This is not designed as a full replacement for custom volume provisioning, if that is what your needs require. However, it is meant to cover a broad range of needs that require *some* customization, but don't require very sophisticated customization in order to succeed.

There are several supported string syntaxes. This section describes each one, along with their nuances:

- [pvc: and pvc://](#pvcString)
- [vol:// and pv://](#pvString)
- [Other string patterns](#otherString)

In the following documentation, you'll find reference to placeholders for variable values that you may wish to employ with each syntax. Placeholders are specified with the syntax `${p1}`, where ***p1*** is the name of the value in that position, and optional values are enclosed in square brackets. Thus, the placeholder `[${p2}]` can be read as "the placeholder ***p2*** is optional".

This table describes each value in some detail, along with examples:

| Value | Description | Example |
|--|--|--|
|accessModes|The access modes, as a comma-separated list, that will be requested for the volume or claim. Abbreviations are supported (RWO/RW = ReadWriteOnce, RWM = ReadWriteMany, RO/ROM = ReadOnlyMany)|ReadOnlyMany,RWO,ROM|
|capacity|The resource capacity that the volume is meant to house|32Gi|
|limits|The resource capacity limits to be applied to the claim|8Gi|
|requests|The resource capacity requests to be applied to the claim|4Gi|
|resourceName|The name of the resource (claim or volume) being referenced||
|storageClassName|The name of the storage class you wish for the volume or claim. If not provided (where allowed)|glusterFs|

### <a name="pvcString"></a> pvc:, pvc://

This syntax allows you to describe which PersistentVolumeClaim resource you wish to be associated to a specific volume, or the characteristics that the corresponding volume claim template should specify.

#### pvc://[\${storageClassName}]/\${requests}[/\${limits}][#\${accessModes}]

This pattern describes the desire for the PVC template to be rendered with the given **storageClassName** (optional), **requests**, **limits** (optional), and **accessModes** (optional). The underlying assumption is that the persistence layer in the cluster will automatically deploy the necessary volumes to back the claim templates. If this is not the case, then you'll need to deploy those PersistentVolume resources manually.

If the ***storageClassName*** value is not given, default storage class for the cluster will be used by the claim template (i.e. no ***storageClassName*** stanza will be rendered)

If the ***limits*** value is not given, no resource limits will be rendered for the claim template.

If the ***accessModes*** value is not given, it will default to **ReadWriteOnce**, or any default access mode that the deployment has been configured for (see [defaults](#defaults) for more details).

#### pvc:\${resourceName}

This pattern describes the desire to bind the volume to a specific **PersistentVolumeClaim** resource that will be expected to already exist on the target cluster.

If the ArkCase deployment is executed with volume overrides described using this string pattern, then the deployment will only succeed if the named PVC resources already exist in the cluster by the time the deployment process tries to bind to them. If they haven't, then some pods will hang indefinitely pending deployment until such a time as they're torn down, or the required PVC is created.

In this scenario, the deployer assumes reponsibility for deploying the necessary PVC resource(s) ***before*** attempting to deploy ArkCase.

### <a name="pvString"></a> pv://, vol://

This syntax allows you to describe which PersistentVolume resource you wish to be associated to a specific volume, or the characteristics that the corresponding PV that will be rendered.

#### pv://[\${storageClassName}]/\${capacity}[#\${accessModes}]

This pattern describes the desire to render a PV with the given **storageClassName** (optional), **capacity**, and **accessModes** (optional).

If the ***storageClassName*** value is not given, default storage class for the cluster will be used by the claim template (i.e. no ***storageClassName*** stanza will be rendered)

If the ***accessModes*** value is not given, it will default to **ReadWriteOnce**, or any default access mode that the deployment has been configured for (see [defaults](#defaults) for more details).

#### vol://\${resourceName}

This pattern describes the desire to bind the volume to a specific **PersistentVolume** resource that will be expected to already exist on the target cluster.

If the ArkCase deployment is executed with volume overrides described using this string pattern, then the deployment will only succeed if the named PV resources already exist in the cluster by the time the deployment process tries to bind to them. If they haven't, then some pods will hang indefinitely pending deployment until such a time as they're torn down, or the required PV is created.

In this scenario, the deployer assumes reponsibility for deploying the necessary PV resource(s) ***before*** attempting to deploy ArkCase.

### <a name="otherString"></a>Other String Patterns

Other string patterns are allowed, and their interpretation varies depending on the context in which they're used. They can be used to describe paths, PVC names, or PV names. Here are some examples:

```yaml
global:
  persistence:
    defaults:
      # Define the location within which relative paths will be housed
      hostPathRoot: "/data/volumes"

    volumes:
      # Render the volume 'logs' for pod 'search' as a hostPath,
      # if applicable, pointing to this specific absolute path
      search:
        logs: "/var/log/arkcase-search"

      # Render the volume 'init' for pod 'core' as a hostPath,
      # if applicable, pointing to the path "/data/volumes/core-initializer"
      core:
        init: "core-initializer"
        # This is equivalent to using vol://volumeWithConfigurations
        home:
          volume: "volumeWithConfigurations"

      rdbms:
        data:
          # This is equivalent to using pvc:pvcForDatabase
          claim: "pvcForDatabase"
```
