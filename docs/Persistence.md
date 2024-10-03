# [ArkCase](https://www.arkcase.com/) Persistence Configuration for Helm

## Table of Contents

* [Introduction](#introduction)
* [Enable or Disable Persistence](#enable-disable)
* [Setting Default Values](#defaults)
* [Overriding Volumes](#overriding-volumes)
* [Volume String Syntax](#volume-string-syntax)

## <a name="introduction"></a>Introduction

This document describes how to configure the persistence layer for the ArkCase helm charts to suit your needs. Generally speaking, you likely will not need to configure too many parameters on a normal deployment. As with any community-release project, Issues and PRs are always welcome to help move this code further along.

ArkCase relies on **PersistentVolumeClaim** (PVC) templates to access **PersistentVolume** (PV) resources which it (generally) expects the cluster infrastructure (or some other actor) to provision. It may also leverage specifically declared PVC resources, as well as specifically tailored PV resources. However, great effort has gone towards not requiring such manipulations of the persistence layer.

The current default for the helm charts is to deploy ArkCase using the default cluster storage class. This means that all volumes will be described using ***volumeClaimTemplate*** declarations within each pod (explicit or template), and will thus be delegated to the cluster for provisioning.

Here's an example of a simple configuration that should work on a production environment, to enable the use of `glusterfs` volumes:

```yaml
# Example contents of conf.yaml
global:
  persistence:
    storageClassName: "glusterfs"
```

Then deploy, like so:

    $ helm install arkcase arkcase/app -f conf.yaml

And that's it. This should yield a fully-working ArkCase stack, with all required components, and with all storage volumes using storage class `glusterfs`. During deployment, the infrastructure will be expected to fulfill all rendered volume claim templates by automatically provisioning volumes (or attaching to existing ones), or bind the incoming claims to already-existing volumes accordingly.

Alternatively, if no `storageClassName` is provided, [the cluster's default storage class](https://kubernetes.io/docs/tasks/administer-cluster/change-default-storage-class/) will be used.

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
  persistence:
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

The alternative to using a string is to use a map to describe the override in more detail. The map may contain exactly one of 2 supported keys: `claim` or `volume`. Defining more than one results in a Helm error that fails the deployment.  Please note that even at this stage, the `claim:` or `volume:` may also be described using a string, for convenience.

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
global:
  persistence:
    volumes:

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

        ################################################################################
        # NEXT, USING THE FANCY STRING SYNTAX                                          #
        ################################################################################

        # Create a PVC template using glusterfs as the storageClassName, and with 8Gi
        # resource requests, in ReadWriteMany or ReadWriteOnce modes, whichever one matches first
        charlie: "pvc://glusterfs/8Gi#RWM,ReadWriteOnce"

        # Create a PVC template using the cluster's default-configured storageClassName (or our
        # specifically configured storageClassName), and with 1Gi resource requests, in
        # ReadWriteOnce mode
        dog: "pvc:///1Gi#RW"

        # Bind to the specific PVC resource named "myFoxyPvc", which would be managed external to the helm
        # chart
        easy: "pvc:myFoxyPvc"

        # Create an nvme volume that's 32Gi in size, and will be mounted in ReadWriteMany mode
        fox: "pv://nvme/32Gi#RWM"

        # Bind this volume to the existing PV resource named "howYouLikeDisVolume"
        george: "vol://howYouLikeDisVolume"

        ################################################################################
        # FINALLY, USING THE COMBINATION MAP AND FANCY STRING SYNTAX                   #
        ################################################################################

        # Similar to the above examples, except the string is tied to the "claim:" stanza
        how:
          # claim: "pvc://.../..."
          # claim: "pvc:queenOfVolumes"
      
          # This is identical to "pvc:kingOfAllVolumes"
          claim: "kingOfAllVolumes"

        # Similar to the above examples, except the string is tied to the "volume:" stanza
        item:
          # volume: "pv://.../..."
          # volume: "vol://volumeIDoNotLove"
      
          # This is identical to "vol://loveThisVolume"
          volume: "loveThisVolume"
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

#### pvc://[\${storageClassName}]/\${requests}[-\${limits}][#\${accessModes}]

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
