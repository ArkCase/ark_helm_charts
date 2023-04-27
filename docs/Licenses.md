# [ArkCase](https://www.arkcase.com/) License Configuration for Helm

## Table of Contents

* [Introduction](#introduction)
* [Deployment Mode (Enterprise vs. Community)](#deployment-mode)
* [Providing Licenses](#providing-licenses)
* [Encoding Licenses](#encoding-licenses)
  * [Alfresco](#encoding-alfresco)
  * [Pentaho](#encoding-pentaho)
  * [PDFTron/PDFNet](#encoding-pdftron)

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

## <a name="providing-licenses"></a>Providing Licenses

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

## <a name="encoding-licenses"></a>Encoding Licenses

As mentioned above, licenses are meant to be encoded in Base-64 format. Linux has a tool to execute this encoding, somewhat cryptically named `base64`.  However, some licenses require only part of the license to be provided.  This section describes how to encode licenses for each software product within ArkCase that may require a license.

### <a name="#encoding-alfresco"></a>Alfresco

Alfresco is fairly straightforward: the license file is a binary file, whose contents will be encoded using `base64`, and listed within the `alfresco:` stanza in the license configuration file.

First, encode the file as base64:

    $ base64 alfresco.lic
    H4sIANUf7WMCA4WRT2vDMAzF7/0UIuzQrosDg+0Q2GGXjV166P700osXq4kgsYKttCttv/vkLmOD
    HQYGC/P0ftLz4VBcwpa6EiIKbKhF2fd41w1RbNVgCZfF6TQ5qGqyssGTr8G+8yAwxFQHbtt0i63N
    5DXaGksVA/mqHRxCVnHXsTe7r9ZoRv2LrTMwb7YdMJreSmOEjTRoqFOLJbOAUkd0Dg435P9xy1V7
    FtMGrHcwrdiLJR8heyfxtqNCkQF7jiQc9jOYesVMjY4ORxB+lpA2OULAGj8eSD2yPKzXbn5xjI29
    vrkts9kszbW6Xy6eFo8lLH+21xkFK0EF6/6/ONpQppekOZ1mV9C3aCOCwhGksQKkJ0KUwL5u94pP
    a6J36iUMdsvk/qYdNWOw0Ad2QyXEHtBvSS20U8xkTn7D0Ij0sSwKx1U0YwpG3YsxGwyxaHiXCxeD
    8oL+uXf5SMkTJf+lPKerc8F30qlOsX8CQkPmiUQCAAA=

Then, paste the contents into a YAML file, like so:

```yaml
global:
  licenses:

    #
    # The results of the base-64 encoding command, above. MIND THE INDENTATION!!!
    #
    alfresco: |-
      H4sIANUf7WMCA4WRT2vDMAzF7/0UIuzQrosDg+0Q2GGXjV166P700osXq4kgsYKttCttv/vkLmOD
      HQYGC/P0ftLz4VBcwpa6EiIKbKhF2fd41w1RbNVgCZfF6TQ5qGqyssGTr8G+8yAwxFQHbtt0i63N
      5DXaGksVA/mqHRxCVnHXsTe7r9ZoRv2LrTMwb7YdMJreSmOEjTRoqFOLJbOAUkd0Dg435P9xy1V7
      FtMGrHcwrdiLJR8heyfxtqNCkQF7jiQc9jOYesVMjY4ORxB+lpA2OULAGj8eSD2yPKzXbn5xjI29
      vrkts9kszbW6Xy6eFo8lLH+21xkFK0EF6/6/ONpQppekOZ1mV9C3aCOCwhGksQKkJ0KUwL5u94pP
      a6J36iUMdsvk/qYdNWOw0Ad2QyXEHtBvSS20U8xkTn7D0Ij0sSwKx1U0YwpG3YsxGwyxaHiXCxeD
      8oL+uXf5SMkTJf+lPKerc8F30qlOsX8CQkPmiUQCAAA=
```

You may now reference this file using `-f` during a Helm deployment. This may also be combined with other licenses into a larger YAML file containing all licenses. This may make your life easier (or not... YMMV).

### <a name="#encoding-pentaho"></a>Pentaho

Pentaho EE licenses are also fairly straightforward, like Alfresco's, but with one difference: there are multiple binary files. Since there is no need to treat those files in distinct ways during deployment, the license structure is just an array of the contents of the requisite files, encoded in `base64`:

First, encode each file as base64:

    $ base64 pentaho-1.lic
    H4sIANUf7WMCA4WRT2vDMAzF7/0UIuzQrosDg+0Q2GGXjV166P700osXq4kgsYKttCttv/vkLmOD
    HQYGC/P0ftLz4VBcwpa6EiIKbKhF2fd41w1RbNVgCZfF6TQ5qGqyssGTr8G+8yAwxFQHbtt0i63N
    5DXaGksVA/mqHRxCVnHXsTe7r9ZoRv2LrTMwb7YdMJreSmOEjTRoqFOLJbOAUkd0Dg435P9xy1V7
    FtMGrHcwrdiLJR8heyfxtqNCkQF7jiQc9jOYesVMjY4ORxB+lpA2OULAGj8eSD2yPKzXbn5xjI29
    vrkts9kszbW6Xy6eFo8lLH+21xkFK0EF6/6/ONpQppekOZ1mV9C3aCOCwhGksQKkJ0KUwL5u94pP
    a6J36iUMdsvk/qYdNWOw0Ad2QyXEHtBvSS20U8xkTn7D0Ij0sSwKx1U0YwpG3YsxGwyxaHiXCxeD
    8oL+uXf5SMkTJf+lPKerc8F30qlOsX8CQkPmiUQCAAA=

Then, paste the contents into a YAML file, like so:

```yaml
global:
  licenses:
    pentaho:
      #
      # The results of the base-64 encoding command, above. MIND THE INDENTATION!!!
      # One list item per file!
      #
      - |-
        H4sIANUf7WMCA4WRT2vDMAzF7/0UIuzQrosDg+0Q2GGXjV166P700osXq4kgsYKttCttv/vkLmOD
        HQYGC/P0ftLz4VBcwpa6EiIKbKhF2fd41w1RbNVgCZfF6TQ5qGqyssGTr8G+8yAwxFQHbtt0i63N
        5DXaGksVA/mqHRxCVnHXsTe7r9ZoRv2LrTMwb7YdMJreSmOEjTRoqFOLJbOAUkd0Dg435P9xy1V7
        FtMGrHcwrdiLJR8heyfxtqNCkQF7jiQc9jOYesVMjY4ORxB+lpA2OULAGj8eSD2yPKzXbn5xjI29
        vrkts9kszbW6Xy6eFo8lLH+21xkFK0EF6/6/ONpQppekOZ1mV9C3aCOCwhGksQKkJ0KUwL5u94pP
        a6J36iUMdsvk/qYdNWOw0Ad2QyXEHtBvSS20U8xkTn7D0Ij0sSwKx1U0YwpG3YsxGwyxaHiXCxeD
        8oL+uXf5SMkTJf+lPKerc8F30qlOsX8CQkPmiUQCAAA=

      #
      # Another file ...
      #
      - |-
        H4sIANUf7WMCA4WRT2vDMAzF7/0UIuzQrosDg+0Q2GGXjV166P700osXq4kgsYKttCttv/vkLmOD
        HQYGC/P0ftLz4VBcwpa6EiIKbKhF2fd41w1RbNVgCZfF6TQ5qGqyssGTr8G+8yAwxFQHbtt0i63N
        5DXaGksVA/mqHRxCVnHXsTe7r9ZoRv2LrTMwb7YdMJreSmOEjTRoqFOLJbOAUkd0Dg435P9xy1V7
        ...
```

You may now reference this file using `-f` during a Helm deployment. This may also be combined with other licenses into a larger YAML file containing all licenses. This may make your life easier (or not... YMMV).

### <a name="#encoding-pdftron"></a>PDFTron/PDFNet

This software package by far requires the most nuance in order to deploy the licenses.  When the licenses are provided, they're done so using a text file that looks somewhat like so:

```txt
------------------------------------
PDFNet Custom SDK Registration Information:
------------------------------------
Company: Your Company (yourdomain.com)
Contact: Johnny Purchasing Manager
License Model: Direct Purchase
License Type: PDFNet Custom SDK [PDF Page Manipulation, Redaction, and Save/Merge Annotations]
Application Name: ArkCase
Platform(s): Linux
AMS (Annual Maintenance Subscription): 09/25/2024 (Sep 25, 2024)
License Key:
Your Company (yourdomain.com):ABC:ArkCase Enterprise::X-:AMS(20240925):CBB484EA7BC149DBC702A36DCF4371E7E72F90648F9DCF8F2A792A14535FA0055950161EA9

 

------------------------------------
To register the Software simply copy the entire License Key (as specified above) and paste it as the parameter in the call to PDFNet.Initialize().
For example: PDFNet.Initialize("license key");
Note: Please make sure that the License Key is specified on a single line.
```

The important tidbits are immediately after the `License Key:` line. Specifically: this line ***and only this line*** must be base-64-encoded and provided in configuration.  This is an easy way to encode the value, given the above file:

    $ grep -A 1 "License Key:" pdfnet-license.txt | tail -1 | base64

Once you have the Base64 value, you can then paste it into the YAML configuration. The three licenses for PDFNet are named as follows: `pdfnet`, `viewer`, and `audioVideo`. This is an example of what that YAML looks like:

```yaml
global:
  licenses:
    pdftron:
      # This is an example value, not a valid PDFTron WebViewer license
      viewer: |-
        Yf39fES+xgnSd60b8dtr2ciOoAaJcVPbt4UbDdxrTWfKO4YJRTsQxqN6yIrkmrrSbWrhM0H1MWOS
        xQhsjME1rclEEYgYMpUejOuPN02pDsfofsmWyf4EML3epNIrbWvxSKr6sZe7yKvYNQIF1E4FNxyZ
        # ...
        ip7xmOa75sZJLQqFAwjXpsvP2yg27w7i4XLlSw==

      # This is an example value, not a valid PDFTron A/V Viewer license
      audioVideo: |-
        Yf39fES+xgnSd60b8dtr2ciOoAaJcVPbt4UbDdxrTWfKO4YJRTsQxqN6yIrkmrrSbWrhM0H1MWOS
        xQhsjME1rclEEYgYMpUejOuPN02pDsfofsmWyf4EML3epNIrbWvxSKr6sZe7yKvYNQIF1E4FNxyZ
        # ...
        ip7xmOa75sZJLQqFAwjXpsvP2yg27w7i4XLlSw==

      # This is an example value, not a valid PDFNet library license
      pdfnet: |-
        Yf39fES+xgnSd60b8dtr2ciOoAaJcVPbt4UbDdxrTWfKO4YJRTsQxqN6yIrkmrrSbWrhM0H1MWOS
        xQhsjME1rclEEYgYMpUejOuPN02pDsfofsmWyf4EML3epNIrbWvxSKr6sZe7yKvYNQIF1E4FNxyZ
        # ...
        ip7xmOa75sZJLQqFAwjXpsvP2yg27w7i4XLlSw==
```

You may now reference this file using `-f` during a Helm deployment. This may also be combined with other licenses into a larger YAML file containing all licenses. This may make your life easier (or not... YMMV).
