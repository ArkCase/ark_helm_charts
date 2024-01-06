# Deploying Custom [ArkCase](https://www.arkcase.com/) Versions with Helm

## Table of Contents

* [Introduction](#introduction)
* [Deployment Mechanics](#deployment-mechanics)
    * [Deployer Container](#deployer-container)
    * [Artifacts Containers](#artifacts-containers)
* [Creating a Custom Artifacts Image](#create-custom-image)
    * [Adding Artifacts](#adding-artifacts)
    * [Encrypting Values](#encrypting-values)
* [Referencing a Custom Artifacts Image](#reference-custom-image)

## <a name="introduction"></a>Introduction

This document describes how to prepare your own, customized ArkCase builds for deployment using these Helm charts. As with any community-release project, Issues and PRs are always welcome to help move this code further along.

ArkCase generally requires the following artifacts for execution, all of which may (or may not) be customized to meet specific application needs (in order of likelihood of customization):

1. the ArkCase WAR file
1. the ArkCase configuration set (.arkcase)
1. the Pentaho Reports set - both 
1. the Solr configurations (schemas, etc) and names of search indexes (a.k.a. cores or collections)
1. the content store's (Alfresco or Minio) initial configuration and content structure
1. any additional customization configurations (to be deployed into .arkcase) and code modules (JARs to be deployed into .arkcase/custom/WEB-INF/lib)

All components should be considered to be interrelated. In particular, ArkCase does not self install its dependencies onto its supporting cast (except for the Database schema management and updates). As a result, other containers must do this preparatory work on its behalf. This made it necessary to design and implement as simple a mechanism as possible to deliver a **set** of ***strongly-correlated*** artifacts, as a **unit**, for deployment, in order to guarantee the internal consistency of the deployment, while also enabling enough flexibility to allow containers to implement their supporting deployment processes in as individually-independent a fashion as possible.

For instance:

* if you deploy ArkCase WAR version X, but the ArkCase configuration set (.arkcase) version Y, the application may fail to start up, or even start up but operate incorrectly
* if you deploy the Pentaho reports version Z with the ArkCase version Y, then the reports won't work properly b/c the DB schema may not match expectations
* if you deploy the wrong the Solr configuration for ArkCase A, but deploy ArkCase B, then the application may boot correctly, but fail to correctly display information in the queues, for instance
* etc...

Of the above items, #5 is the most frequently customized. However, it's still tightly coupled to the other artifacts - especially #1 and #2.

Therefore, it's ***critically*** important that **all** artifacts be served from the same place (the ***artifacts*** container). At the same time, by doing so we enable a homogenized artifact retrieval process that works "more or less the same" for all containers in the ecosystem.

For these Helm charts the deployment mechanics are somewhat different than would normally be expected in a containerized application, precisely to allow for easy customization for the overall application, but without necessarily requiring changing many runtime container images un order to support it. This is why the WAR files are delivered separate from their execution environment.

## <a name="deployment-mechanics"></a>Deployment Mechanics

The ArkCase helm charts use a single container image to provide all the runtime artifacts required to assemble the final application. This image is generally referred to as the ***artifacts container***. Each ***type*** of ArkCase deployment requires a different set of artifacts, and as a result a different *artifact image*.

For instance:
* A "default" (i.e. *core* or *legal*) ArkCase deployment utilizes the ***arkcase/artifacts-core*** image
* A FOIA ArkCase deployment utilizes the ***arkcase/artifacts-foia*** image
* The customer XYZ may utilize the ***arkcase/artifacts-xyz*** image
* and so on

The artifacts container is meant to run passively, simply hosting an HTTP(S) server which can be queried by other containers' ***deployer*** *initContainer* in order to download artifacts of interest for different runtime scenarios, and extract/place them in the correct locations.

For example: the **core** container's ***deployer*** would download the main ArkCase WAR (along with any other supporting WARs), the ArkCase configuration archive, along with any additional customizations. It would then extract files as required into the correct volumes for the runtime Pod, such that the ArkCase application can be booted up and execute successfully.

By contrast, Pentaho's ***deployer*** would only download the reports and make them available to Pentaho for consumption and installation during boot.

Similar things would happen with Solr's and Alfresco's deployer.

Thus, the intention is that through providing a central place where all interrelated artifacts can be obtained, each component can download and deploy the correct configuration it requires to work correctly and in concert with the other components.

### <a name="deployer-container"></a>Deployer Container

The ***deployer*** container is based off of the ***arkcase/deployer*** image. It houses all the scripts that facilitate pulling, validating, and deploying artifacts from the ***artifacts*** container. It also supports ***version-controlling*** the deployed artifacts such that the system does not attempt repeat installation or deployment of artifacts if they've not changed since the last time they were deployed.

This is done primarily through file hash validation (SHA256).  When deploying an artifact, the scripts will verify that the SHA256 sum for the new file is different to the SHA256 sum of the previous file deployed. If no file has been previously deployed, then clearly the sum will be treated as different. The ***artifacts*** container **generally** contains cached SHA256 sum values for the each of artifacts it contains, to accelerate this process.

There are some instances in which some artifacts are NOT version-controlled because the volumes into which they're deployed are not meant to be persistent. Because they're not persistent, they can't remember which prior versions were installed into it, and always behave as if every install is a first-time install. Notably, the ArkCase WARs are treated in this manner to ensure that the correct application (per the ***artifacts*** container) is ***always*** deployed. The ArkCase configuration, however, **is** stored persistently, since this is required.

Deployment is generally performed by an init container within the pods. This is intentionally so, in order to facilitate bootup and loosely couple the deployment mechanics from the actual components' runtime mechanics. This way we can change the means/mechanism for deployment without having to adjust the components to the new model.

### <a name="artifacts-containers"></a>Artifacts Containers

The base image for all the artifacts container images is, cryptically enough, the ***arkcase/artifacts*** container image. This container image houses all the required scripts and runtime logic that will be required by ***all*** artifacts images. As mentioned above, the ***artifacts*** container is simply a read-only web server, housing a very simplistic HTTPS-based REST API. This API allows the scripts in the ***deployer*** to query:

* what **categories** (folders) of artifacts are available (i.e. *arkcase*, *pentaho*, *solr*, *arkcase/wars*, etc.)
* what **artifacts** are available within each category (i.e. which WARs need deploying, which Pentaho reports need installing, etc.)

This allows each chart to code its own deployment process according to its component's requirements.

The ***artifacts*** container must house a directory structure similar to the following:

```
/app
└── file
    ├── alfresco
    │   ├── sites
    │   │   └── acm.zip
    │   ├── rm
    │   │   └── rm.zip
    ├── arkcase
    │   ├── conf
    │   │   ├── 00-conf.zip
    │   │   ├── 00-pdftron.zip
    │   │   └── 01-ksbn.zip
    │   └── wars
    │       ├── arkcase#external-portal.war
    │       ├── arkcase.war
    │       └── foia.war
    ├── minio
    ├── pentaho
    │   ├── analytical
    │   │   ├── foia.zip
    │   │   └── neo4j-demo.zip
    │   └── reports
    │       └── foia.zip
    └── solr
        └── solrconfig.zip
```

Each of the above ***files*** *may* be accompanied by a **.ver** file which contains the version number for the file being deployed, for traceability, and a **.sum** file containing the SHA256 sum for the file. The base container image provides mechanisms with which one can easily generate these files if missing, or during the creation of a customized container (see below for details).

The base ***arkcase/artifacts*** image should generally not require modification, unless it's a bugfix, a feature enhancement, or a review of the deployment mechanics (which will generally be accompanied by a documentation update as well as modifications to the overall deployment mechanics).

## <a name="create-custom-image"></a>Creating a Custom Artifacts Image

As mentioned above, you don't need to create a custom ***deployer*** image, as that container image. However, should you wish to deploy your own customized version of ArkCase, you ***will*** need to create a custom artifacts image. The deployment mechanism generally doesn't care ***how*** your artifacts container image is built, as long as it follows the following rules:

1. it's built using ***public.ecr.aws/arkcase/artifacts*** as the base image (to ensure proper run-time execution)
1. all artifact files are housed within /app/file, and any and all modifications to the container are limited to adding files within /app/file, ***no exceptions!!!***
1. the directory structure within /app/file matches what the target containers expect:
    * ArkCase
        * expects the folders *arkcase/conf* and *arkcase/wars* to exist, both are required
        * WAR files to be deployed are to be stored in native, WAR format, with their base name being their Tomcat deployment context (i.e. *ROOT.war* is permissible, to populate the **/** context, *abcde.war* is permissible to populate the **/abcde** context, etc.)
        * Configuration files to be deployed are stored in ZIP format
            * They will be extracted directly into the ***.arkcase*** directory (this meansy they must contain a mirror directory structure that exactly matches .arkcase)
            * Files will be extracted in (US-ASCII) alphabetical order
            * Filenames are irrelevant except for the purposes of version tracking
            * It is allowable to overwrite files from earlier archives with files from latter archives, hence the strict extraction order
            * ***No files will be deleted from an existing configuration directory prior to deployment***  *(this **may** change soon, though)*
  * Pentaho
      * supports the folders *pentaho/analytical* and *pentaho/reports*, neither is required
      * files within *pentaho/reports* are reports bundles which will be copied into Pentaho's **init** volume, and consumed during startup for installation
      * files within *pentaho/analytics* are PDI data warehousing scripts which will be executed once on initial installation, but will generally only be consumed by the Pentaho cron container
  * Solr
      * ***TBD...***
  * Alfresco
      * ***TBD...***
  * Others
      * ***TBD...***

[This container image](https://github.com/ArkCase/artifacts-dev) can be used as an easy starting point. Here's the Dockerfile for that image:

```Dockerfile
#
# Basic Definitions
#
ARG EXT="core"
ARG VER="2023.01.06"

#
# Basic Parameters
#
ARG REG="public.ecr.aws"
ARG REP="arkcase/artifacts-${EXT}"
ARG BASE_IMAGE="${REG}/${REP}:${VER}"

FROM "${BASE_IMAGE}"

#
# Basic Parameters
#

LABEL ORG="ArkCase LLC" \
      MAINTAINER="Armedia Development Team <devops@armedia.com>" \
      APP="ArkCase Development Deployer" \
      VER="${VER}" \
      EXT="${EXT}"

#
# Add the local files we want in this deployment (must match the requisite folder structure within)
# (note that ${FILE_DIR} is defined on the parent image as "/app/file")
#
ADD file "${FILE_DIR}"

#
# The last command, to build any missing .sum or .ver files, if necessary
#
RUN rebuild-helpers
```

This image takes the ***artifacts/arkcase-core*** image as the base, since it assumes you'll want to base your image of the current ArkCase. You can then begin to add or overwrite artifacts by adding them within the ***files*** directory.

If you wish to be more daring and start with a blank slate, you can perhaps use the **Dockerfile.blank** image as your basis:

```Dockerfile
#
# Basic Parameters
#
ARG REG="public.ecr.aws"
ARG REP="arkcase/artifacts"
ARG ARTIFACTS_VER="1.4.0"
ARG BASE_IMAGE="${REG}/${REP}:${ARTIFACTS_VER}"

FROM "${BASE_IMAGE}"

#
# Basic Parameters
#

LABEL ORG="Custom Builder LLC" \
      MAINTAINER="Custom Builder Development Team <devops@armedia.com>" \
      APP="Custom Builder Development Artifacts"

#
# Add the local files we want in this deployment
#
ADD file "${FILE_DIR}"

#
# The last command, to make sure everything is kosher
#
RUN rebuild-helpers
```

Feel free to customize your Dockerfile's metadata to your liking.

You can then build that container image, like so:

    $ docker build [-f Dockerfile.blank] -t my-image-repository/my-test-arkcase:1.2.3 .

### <a name="adding-artifacts"></a>Adding Artifacts

There are multiple ways to add artifacts into your custom container images. Here are some simple ones:

* Copy your custom artifacts into their correct locations within the container
    * i.e. copy the local file ***my-test-arkcase.war*** as ***${FILE_DIR}/arkcase/wars/arkcase.war***
    * i.e. copy the local file ***my-test-arkcase-config.zip*** as ***${FILE_DIR}/arkcase/conf/01-conf.zip***
    * ... etc ...
    * Run the ***render-helpers*** as your last step, to generate the ***.sum*** and ***.ver*** files automatically for each added file
        * Please note that if there is no companion ***.ver*** file with each artifact you upload, the default version string ***(unknown)*** will be used
        * Thus, it's not advisable to omit this particular file, since this isn't a value that can be reliably deduced
    * Recall that by using Docker's `ADD` Dockerfile command instead of `COPY` you may have the build process reach out and download resources from URLs of your choosing. However, if this is your preferred method for obtaining the desired artifacts, then may we suggest you instead ...
* Download your custom artifacts using a (HTTP) URL, using the ***prep-artifact*** script, which will not only download your artifact, but also simultaneously create the SHA256 sum file **and** the version file (based on the version information provided).  The script uses `curl`, and supports SSL security albeit it bypasses certificate validation
    * usage: `prep-artifact source targetFile [version]`
    * example: `prep-artifact https://my-web-server.com/custom-arkcase/test-war-1.2.3.war files/arkcase/wars/arkcase.war 1.2.3`
    * Authentication is supported using the `CURL_ENCRYPTION_KEY`, `CURL_USERNAME`, and `CURL_PASSWORD` environment variables
        * `CURL_ENCRYPTION_KEY` is the encryption key used to encrypt/decrypt values, and is ***required*** if you wish to utilize authentication (try to use a STRONG value, and manage its security wisely)
        * `CURL_USERNAME` is the username with which CURL will authenticate, and **may** be encrypted using `CURL_ENCRYPTION_KEY` (see the algorithm below)
        * `CURL_PASSWORD` is the password with which CURL will authenticate, and **MUST** be encrypted using `CURL_ENCRYPTION_KEY`
        * There's an advanced option of using an authentication file for large, and complex artifact download processes which require many different authentications fo rmany different servers. This will not be covered here as documentation for this mechanism already exists elsewhere (you'll know it when you see it ;) )

* Download your custom artifacts from a Maven repository, using the ***mvn-get*** script, and using Maven coordinates. This will also download your artifact, and create the support files (sum + ver), but since Maven data is available, the version will be filled accurately with the artifact's **actual**, **real** version (as Maven understands it to be)
    * usage:

            mvn-get artifactSpec repoUrl target`

                artifactSpec: groupId:artifactId[:version[:packaging[:classifier]]]
                repoUrl:      URL to the Maven repository housing the artifact (http:// or https://)
                target:       The final path where the file will be copied into. If it's
                              a directory, the downloaded filename will be preserved.

    * Authentication is also supported with the `MVN_GET_ENCRYPTION_KEY`, `MVN_GET_USERNAME`, and `MVN_GET_PASSWORD` environment variables
        * `MVN_GET_ENCRYPTION_KEY` is the encryption key used to encrypt/decrypt values, and is ***required*** if you wish to utilize authentication (try to use a STRONG value, and manage its security wisely)
        * `MVN_GET_USERNAME` is the username with which the `mvn-get` script will authenticate, and **may** be encrypted using `MVN_GET_ENCRYPTION_KEY` (see the algorithm below)
        * `MVN_GET_PASSWORD` is the password with which the `mvn-get` script will authenticate, and **MUST** be encrypted using `MVN_GET_ENCRYPTION_KEY`

As mentioned <a href="#artifacts-containers">above</a>, **the important thing is for the artifacts to have the correct names, and be organized using the correct folder structure**. Otherwise, the deployers for the containers will not find your customizations, and thus not deploy them for use.

### <a name="encrypting-values"></a>Encrypting Values

As mentioned above, there are some values that can be encrypted using an encryption key. In order to encrypt a value, you must use some variation of the following script:

```bash
echo -n "your-password-to-encrypt" | openssl aes-256-cbc -a -A -salt -iter 5 -kfile <(echo -n "${YOUR_ENCRYPTION_KEY}") 2>/dev/null
```

The above command will yield a *base-64* encoded string, which you can then use as your encrypted password moving forward (i.e. as a `CURL_PASSWORD` or `MVN_GET_PASSWORD` value).  For decryption, you can use *almost* the same script (note the **-d** flag in the openssl command):

```bash
echo -n "the-base64-version-of-your-encrypted-password" | openssl aes-256-cbc -a -A -salt -iter 5 -d -kfile <(echo -n "${YOUR_ENCRYPTION_KEY}") 2>/dev/null
```

Note that `YOUR_ENCRYPTION_KEY` can be *any* value, but we generally recommend a strong value (online password generators may help with this).  Note that if you lose this value, your encrypted passwords will be unrecoverable, and will not be able to be decoded during container construction. This value is safe to be stored in secret stores, such as the one used in GitHub (for WorkFlows), or GitLab (for GitLab CI).

In the base [arkcase/artifacts](https://github.com/ArkCase/ark_artifacts) container, there are several useful scripts that can help simplify this task:

* `encrypt` and `decrypt` : use `CURL_ENCRYPTION_KEY` to encrypt/decrypt values

        $ export CURL_ENCRYPTION_KEY=12345
        $ echo -n "abcde" | ./encrypt | ./decrypt
        # Prints out "abcde"

* For the `MVN_GET_*` values, you can use the same mechanism described above, just use the value for `MVN_GET_ENCRYPTION_KEY` in `CURL_ENCRYPTION_KEY` when invoking `encrypt` or `decrypt`

## <a name="reference-custom-image"></a>Referencing a Custom Artifacts Image

Once you have your [custom image built](#create-custom-image), you will want to make it available to the helm deployment. In order to do this, you must set these configurations:

```yaml
global:
  image:
    app:
      # This name is required ... if FOIA is enabled, then the name *must* be "artifacts-foia",
      # or you must employ a "YAML map copy" trick as shown below
      artifacts: &artifacts
        #
        # The name of the secret which contains the required credentials to access the image
        # (may be provided as a CSV list of names, or a YAML array of names). All 3 forms
        # below are acceptable.
        #
        # pullSecrets: "pull-secret-1,pull-secret-2"
        # pullSecrets: [ "pull-secret-1", "pull-secret-2" ]
        # pullSecrets:
        #   - "pull-secret-1"
        #   - "pull-secret-2"

        # These settings would be provided as required. They don't all have to be there,
        # but at least some will need to be customized in order to support your custom
        # deployment ... most likely the registry and repository since you would be able
        # to mimic the default tag on your own images. However, if you wish to follow your
        # own tag organization, you're also able to do that comfortably.
        registry: "my-image-repository"
        repository: "my-test-arkcase"
        tag: "1.2.3"

        # This setting is optional, and the default value if not provided is "Always".
        #
        # The possible values are described here: https://kubernetes.io/docs/concepts/containers/images/#image-pull-policy
        #
        # If you're using a machine-local image that isn't yet published to any repository,
        # then you *MUST* use "Never" here, to avoid bootup failures due to image search
        # failures.
        #
        # pullPolicy: "Always"

      # This little "YAML map copy" trick can be useful to simplify the overall configuration
      # when FOIA may be in play, to ensure that the correct container information is used while
      # using a simplified configuration syntax
      artifacts-foia:
        # This "<<:" tells the YAML parser to copy the contents of the &artifacts map inline here
        <<: *artifacts
```

### Example #1: deploy a different version of ArkCase:

```yaml
global:
  image:
    app:
      artifacts:
        tag: "2025.07.64"
```

This will cause the container image `public.ecr.aws/artifacts/arkcase-core:2025.07.64` to be used in the deployment.

### Example #2: deploy from a different registry:

```yaml
global:
  image:
    app:
      artifacts:
        # You must create this secret manually, ahead of time
        pullSecrets: "my-docker-registry-auth"
        registry: "my-private-registry.my-domain.com"

```

This will cause the container image `my-private-registry.my-domain.com/artifacts/arkcase-core:${VERSION}` to be used in the deployment. Note that `${VERSION}` represents the current ArkCase version referenced by default from the Helm charts.

### Example #3: deploy a local image:

```yaml
# 
global:
  image:
    app:
      artifacts:
        registry: "local"
        repository: "my-test-arkcase"
        tag: "latest"
        pullPolicy: "Never"
```

This will cause the locally-stored container image `local/my-test-arkcase:latest` to be used in the deployment, with no attempt being made to fetch the image from any other source. This obviously assumes that the image was built using: `docker build -t local/my-test-arkcase:latest .`, or at the very least tagged from another using Docker's `tag` command.