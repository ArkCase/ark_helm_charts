# [ArkCase](https://www.arkcase.com/) License Configuration

***NOTE**: In a rare first, this documentation is slightly ahead of the code it covers. If something described here doesn't work with the current version of the charts, check in within a few days, and it more than likely will. These charts will remain in a constant state of flux until they reach 1.0 status, as we're using them to guide the development roadmap. Adjustments to the docs will be made if/when we find better/cleaner ways to do things on the backend.*

## Table of Contents

* [Introduction](#introduction)
* [Deployment Mode (Enterprise vs. Community)](#deployment-mode)
* [Providing Licenses](#providing-licenses)

## <a name="introduction"></a>Introduction

This document describes how to configure the licenses for specific products used as part of the the ArkCase helm charts.

ArkCase consumes the following products which require paid licenses to be provided in order to leverage the Enterprise functionalities:

- ArkCase EE : must purchase a [license here](https://www.arkcase.com/)
- Pentaho EE : licenses are included as part of the ArkCase EE package.
  - If you've purchased ArkCase EE, but haven't received your Pentaho EE licenses, please contact support.
- PDFTron/PDFNet : licenses [must be acquired separately](https://apryse.com/).
  - Operating this component without a license is possible, but will yield significantly limited functionality
  - This component can only be de-activated through modifying the ArkCase platform's code

Once you've acquired the licenses you need to deploy, follow the instructions below to do so.

## <a name="deployment-mode"></a>Deployment Mode (Enterprise vs. Community)

When deploying ArkCase, the helm charts within will examine the given deployment configuration to identify which license(s) are present. Based on the **presence** of these values, deployment decisions are made to select the correct components (and their configurations) to be deployed.

This means that:

- If the Alfresco chart locates the required license configuration(s) to run Alfresco EE, it will do so. Otherwise, it will deploy Alfresco CE.
- If the Pentaho chart locates the required license configuration(s) to run Pentaho EE, it will do so. Otherwise, it will deploy Pentaho CE.
- PDFTron will deploy the same edition regardless, but the runtime behavior will vary based on whether the required licenses were made available via configuration, or not.

In general, ***Comunity Edition*** components do not require licenses to be deployed. This is why the presence of licenses automatically selects ***Enterprise Edition*** components.

***WARNING: once you've deployed a component in either edition - Enterprise or Community - you may ONLY deploy that component in that edition. The containers have code within them to check for edition incompatibilities, and will refuse to boot if any are found, for data safety.***

More generally: Enterprise Edition data sets (databases, filesystem files, etc.) tend to not be backwards compatible with Community Edition data sets. And often enough, the reverse is also true: Community Edition data sets can't be "upgraded" into Enterprise Edition. This is especially true for Alfresco.

Thus, if you wish to migrate a component that has a persistent data set you want to preserve (most likely Alfresco or Pentaho) from one edition to the other, you must ***manually*** perform said migration before you can safely boot up ArkCase after that up/downgrade.

## <a name="providing-licenses"></a> [Providing Licenses](#providing-licenses)

Licenses are provided in (Base-64)[https://en.wikipedia.org/wiki/Base64] format, to preserve any internal text formatting or binary data. Each component that consumes license data knows the structure of the data it's looking for.

This file serves as a high-level example of how to configure licenses:

```yaml
global:
  licenses:
    # This is the name of the software the license is for (i.e. alfresco, pdftron, pentaho, etc).
    software-1:
      # license data contained within, structured as required by the consuming chart(s)

    software-2:
      # license data contained within, structured as required by the consuming chart(s)

    software-3:
      # license data contained within, structured as required by the consuming chart(s)

    # ...
    software-N:
      # license data contained within, structured as required by the consuming chart(s)
```

In a real world scenario, you would construct the license file, name it something meaningful (like `licenses.yaml`), and deploy ArkCase referencing it, like so:

    $ helm install arkcase arkcase/arkcase -f licenses.yaml -f values.yaml

This is a real-world example (with fake licenses, of course) of the licenses required for a full Enterprise Edition ArkCase stack (ArkCase EE, Pentaho EE, Alfresco EE, PDFTron EE):

```yaml
global:
  licenses:

    pdftron:

      viewer: |-
        Yf39fES+xgnSd60b8dtr2ciOoAaJcVPbt4UbDdxrTWfKO4YJRTsQxqN6yIrkmrrSbWrhM0H1MWOS
        xQhsjME1rclEEYgYMpUejOuPN02pDsfofsmWyf4EML3epNIrbWvxSKr6sZe7yKvYNQIF1E4FNxyZ
        # ...
        ip7xmOa75sZJLQqFAwjXpsvP2yg27w7i4XLlSw==

      audioVideo: |-
        Yf39fES+xgnSd60b8dtr2ciOoAaJcVPbt4UbDdxrTWfKO4YJRTsQxqN6yIrkmrrSbWrhM0H1MWOS
        xQhsjME1rclEEYgYMpUejOuPN02pDsfofsmWyf4EML3epNIrbWvxSKr6sZe7yKvYNQIF1E4FNxyZ
        # ...
        ip7xmOa75sZJLQqFAwjXpsvP2yg27w7i4XLlSw==

      pdfnet: |-
        Yf39fES+xgnSd60b8dtr2ciOoAaJcVPbt4UbDdxrTWfKO4YJRTsQxqN6yIrkmrrSbWrhM0H1MWOS
        xQhsjME1rclEEYgYMpUejOuPN02pDsfofsmWyf4EML3epNIrbWvxSKr6sZe7yKvYNQIF1E4FNxyZ
        # ...
        ip7xmOa75sZJLQqFAwjXpsvP2yg27w7i4XLlSw==

    alfresco: |-
      Yf39fES+xgnSd60b8dtr2ciOoAaJcVPbt4UbDdxrTWfKO4YJRTsQxqN6yIrkmrrSbWrhM0H1MWOS
      xQhsjME1rclEEYgYMpUejOuPN02pDsfofsmWyf4EML3epNIrbWvxSKr6sZe7yKvYNQIF1E4FNxyZ
      # ...
      ip7xmOa75sZJLQqFAwjXpsvP2yg27w7i4XLlSw==

    pentaho:
      - |-
        Yf39fES+xgnSd60b8dtr2ciOoAaJcVPbt4UbDdxrTWfKO4YJRTsQxqN6yIrkmrrSbWrhM0H1MWOS
        xQhsjME1rclEEYgYMpUejOuPN02pDsfofsmWyf4EML3epNIrbWvxSKr6sZe7yKvYNQIF1E4FNxyZ
        # ...
        ip7xmOa75sZJLQqFAwjXpsvP2yg27w7i4XLlSw==

      - |-
        Yf39fES+xgnSd60b8dtr2ciOoAaJcVPbt4UbDdxrTWfKO4YJRTsQxqN6yIrkmrrSbWrhM0H1MWOS
        xQhsjME1rclEEYgYMpUejOuPN02pDsfofsmWyf4EML3epNIrbWvxSKr6sZe7yKvYNQIF1E4FNxyZ
        # ...
        ip7xmOa75sZJLQqFAwjXpsvP2yg27w7i4XLlSw==

      - |-
        Yf39fES+xgnSd60b8dtr2ciOoAaJcVPbt4UbDdxrTWfKO4YJRTsQxqN6yIrkmrrSbWrhM0H1MWOS
        xQhsjME1rclEEYgYMpUejOuPN02pDsfofsmWyf4EML3epNIrbWvxSKr6sZe7yKvYNQIF1E4FNxyZ
        # ...
        ip7xmOa75sZJLQqFAwjXpsvP2yg27w7i4XLlSw==

      - |-
        Yf39fES+xgnSd60b8dtr2ciOoAaJcVPbt4UbDdxrTWfKO4YJRTsQxqN6yIrkmrrSbWrhM0H1MWOS
        xQhsjME1rclEEYgYMpUejOuPN02pDsfofsmWyf4EML3epNIrbWvxSKr6sZe7yKvYNQIF1E4FNxyZ
        # ...
        ip7xmOa75sZJLQqFAwjXpsvP2yg27w7i4XLlSw==

      - |-
        Yf39fES+xgnSd60b8dtr2ciOoAaJcVPbt4UbDdxrTWfKO4YJRTsQxqN6yIrkmrrSbWrhM0H1MWOS
        xQhsjME1rclEEYgYMpUejOuPN02pDsfofsmWyf4EML3epNIrbWvxSKr6sZe7yKvYNQIF1E4FNxyZ
        # ...
        ip7xmOa75sZJLQqFAwjXpsvP2yg27w7i4XLlSw==
```
