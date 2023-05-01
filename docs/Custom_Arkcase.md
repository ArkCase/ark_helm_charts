# Deploying Custom [ArkCase](https://www.arkcase.com/) Versions with Helm

## Table of Contents

* [Introduction](#introduction)
* [Deployment Mechanics](#deployment-mechanics)
* [Creating a Custom Deployer Image](#create-custom-image)
* [Referencing a Custom Deployer Image](#reference-custom-image)

## <a name="introduction"></a>Introduction

This document describes how to prepare your own, customized ArkCase builds for deployment using these Helm charts. As with any community-release project, Issues and PRs are always welcome to help move this code further along.

ArkCase generally requires the following artifacts for execution, all of which may (or may not) be customized to meet specific application needs (in order of likelihood of customization):

1. the ArkCase WAR file
1. the ArkCase configruation set (.arkcase)
1. the Solr indexing schema and list of search indexes (core/collections)
1. the content store's (generally, Alfresco) prepared folder structure
1. the Pentaho Reports set

Of the above items, 1 and 2 are the most frequently customized, and are the ones most closely tied together.

For the Helm charts, the deployment mechanics are somewhat different than would normally be expected, precisely to allow for easy customization for the overall application, but without necessarily requiring changing many runtime container images un order to support it.

## <a name="deployment-mechanics"></a>Deployment Mechanics

The ArkCase helm charts use a single container image to provide all the runtime artifacts required to assemble the final application. This image is generally referred to as ***arkcase/deploy***. This image, however is based on another image where the base deployment code is housed, called ***arkcase/deploy-base***. Generally speaking, the ***arkcase/deploy-base*** image should not require modification in order to deploy updated artifacts.

Instead, these should be done by creating a new image of your choosing, ***based on*** the ***arkcase/deploy-base*** image. This is, in fact, how the default ***arkcase/deploy*** image is built:

```Dockerfile
ARG PUBLIC_REGISTRY="public.ecr.aws"
ARG BASE_REPO="arkcase/deploy-base"
ARG BASE_TAG="latest"

# Some parameters for easy build configuration
ARG VER="2021.03.26"
ARG CONFIG_SRC="https://project.armedia.com/nexus/repository/arkcase/com/armedia/arkcase/arkcase-config-core/${VER}/arkcase-config-core-${VER}.zip"
ARG ARKCASE_SRC="https://project.armedia.com/nexus/repository/arkcase/com/armedia/acm/acm-standard-applications/arkcase/${VER}/arkcase-${VER}.war"

FROM "${PUBLIC_REGISTRY}/${BASE_REPO}:${BASE_TAG}"

ARG CONFIG_SRC
ARG ARKCASE_SRC

LABEL ORG="ArkCase LLC" \
      MAINTAINER="Armedia Devops Team <devops@armedia.com>" \
      APP="ArkCase Deployer" \
      VERSION="${VER}"

# Download the configuration file we want (CONF_FILE is defined on the parent image)
ADD "${CONFIG_SRC}" "${CONF_FILE}"

# Cache its SHA-256 checksum, for faster deployment
RUN sha256sum "${CONF_FILE}" | \
        sed -e 's;\s.*$;;g' | \
        tr -d '\n' \
        > "${CONF_FILE}.sum"

# Download the WAR file we want (WAR_FILE is defined on the parent image)
ADD "${ARKCASE_SRC}" "${WAR_FILE}"

# Cache its SHA-256 checksum, for faster deployment
RUN sha256sum "${WAR_FILE}" | \
        sed -e 's;\s.*$;;g' | \
        tr -d '\n' \
        > "${WAR_FILE}.sum"
```

Note that the above Dockerfile doesn't include any sections describing functionality, or adding scripts.  This is because everything is already configured on the parent image (***arkcase/deploy-base***) in order to facilitate the construction of customized deployment images.

During bootup, the ArkCase application (specifically, the ***core*** `StatefulSet`) will use the deployer image as an initialization container, and use it to seed the appropriate volumes with the required data (i.e. the ***home*** volume with the contents of .arkcase, and the ***war*** volume with the contents of the WAR file, etc.).

Zip archives to be deployed are selected from the deployer image's `/app/file` directory. Every ZIP file contained therein is a deployment candidate. The search is performed on the directory ***only***, so no subdirectories are allowed!

Each archive may be accompanied by a matching `.sum` companion file containing the SHA-256 checksum, to accelerate computation during deployment. The checksum file will be named exactly as the archive, but ***adding*** the .sum extension at the end. As an example, the checksum file for "foo.zip" would be called "foo.zip.sum". The checksum contained within the file will be used later on to determine if the incoming archive should be deployed or not. If no checksum file is provided, then the SHA-256 checksum for the archive will be computed live at deployment time.

During deployment, each file's basename will be taken as the directory into which it's meant to be deployed, within the `/app/depl` directory, minus the "zip" extension. Thus, the file `/app/file/foo-bar.zip` will be extracted into `/app/depl/foo-bar`. If the target directory does not exist, the archive will not be extracted, and will simply be skipped.

As an example: you wish to deploy a file named `foo-bar.zip`. You'll need to add it to your own version of the deployer image as `/app/file/foo-bar.zip`. Then you'll need to run the image with a volume mounted at `/app/depl/foo-bar`. The bootup script for the deployer image will iterate through every zip file contained in `/app/file` (remember: no subdirectories!), get its basename (i.e. just the filename, minus the zip extension), and look for a folder with that same basename within `/app/depl`. If such a folder exists, then the deployment will be executed against that folder.

The deployment consists of checking the version tracking file to see if the incoming archive's SHA-256 sum matches the last deployed one. If this cannot be verified (i.e. no prior version tracking due to a missing index, the prior checksum from the index is different, etc.), then the contents of `/app/file/foo-bar.zip` will be extracted **directly** into `/app/depl/foo-bar`, overwriting any existing files. Finally, the version deployed will be tracked in the version tracking file. For each volume, the version tracking file is called `.versions`, in the root of the volume.

## <a name="create-custom-image"></a>Creating a Custom Deployer Image

To create a custom deployer image, you can use the following Dockerfile as a template:

```Dockerfile
FROM "public.ecr.aws/arkcase/deploy-base:latest"

COPY "my-custom-configuration.zip" "${CONF_FILE}"
RUN sha256sum "${CONF_FILE}" | \
        sed -e 's;\s.*$;;g' | \
        tr -d '\n' \
        > "${CONF_FILE}.sum"

COPY "my-custom-arkcase.war" "${WAR_FILE}"
RUN sha256sum "${WAR_FILE}" | \
        sed -e 's;\s.*$;;g' | \
        tr -d '\n' \
        > "${WAR_FILE}.sum"
```

You can then build that container image, like so:

    $ docker build -t my-image-repository/my-test-arkcase:1.2.3 .

Recall that Docker's `ADD` Dockerfile command you may have the build process reach out and download resources from URLs (as is done in our base image's Dockerfile). This way you can use a singular image for all builds, and parameterize the URL using `--build-arg` (see the Docker documentation for more details on how `ARG` works). Finally, you can push the image to your repository (if desired):

    $ docker push my-image-repository/my-test-arkcase:1.2.3

Please note that for real-world usage there may be authentication steps and other security measures in place that you may need to comply with. Due to the incredible variety in these measures, it's impossible for this document to cover them. Thus, this is left out of scope, and as an exercise for the reader.


## <a name="reference-custom-image"></a>Referencing a Custom Deployer Image

Once you have your [custom image built](#create-custom-image), you will want to make it available to the helm deployment. In order to do this, you must set these configurations:

```yaml
global.image.core:
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

  # This name is required
  deploy:
    # These settings would be provided as required. They don't all have to be there,
    # but at least some will need to be customized in order to support your custom
    # deployment ... most likely the registry and repository since you would be able
    # to mimic the default tag on your own images. However, if you wish to follow your
    # own tag organization, you're also able to do that comfortably.
    registry: "my-image-repository"
    repository: "my-test-arkcase"
    tag: "1.2.3"

    # This setting is optional, and the default behavior is described
    # here: https://kubernetes.io/docs/concepts/containers/images/#image-pull-policy
    # pullPolicy: "IfNotPresent"
```
