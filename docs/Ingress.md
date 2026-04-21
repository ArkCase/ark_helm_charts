
# [ArkCase](https://www.arkcase.com/) Ingress and SSL/TLS Access for Helm

## Table of Contents

* [Introduction](#introduction)
* [Configuration Example](#configuration-example)
    * [Annotations](#annotations)
* [Supported Clouds](#supported-clouds)
    * [Default (development)](#cloud-default)
    * [Amazon Web Services](#cloud-aws)
    * [Microsoft Azure](#cloud-azure)


## <a name="introduction"></a>Introduction

This document describes the model and configuration for enabling Ingress and SSL/TLS access to ArkCase as part of the original deployment. As with any community-release project, Issues and PRs are always welcome to help move this code further along.

The ArkCase helm chart supports rendering an `Ingress` resource as part of the deployment procedure. This ingress resource is configured via the `global.ingress` configuration map, and the `global.conf.baseUrl` configuration string. The ingress will, in turn, reference the ArkCase application itself (through the service named `core`), under the path specified in the given `global.conf.baseUrl` value.

The Ingress configuration will be activated if the `global.conf.baseUrl` configuration string is present and is a valid URL. This string represents the actual URL through which ArkCase will be accessed. If the parameter is not given, the Ingress resource will not be rendered. If the URL is not valid, this will result in a template rendering error.

SSL/TLS will always be enabled for the ingress, as this is a necessity for the application's proper functioning. If the name of a valid secret (of type `kubernetes.io/tls`) is provided, the certificate information within will be used. If, instead, you wish to provide certificates dirctly, they can be embedded into the configuration as shown below. Finally, if you provide neither, and the cloud infrastructure selected does not by default provide a certificate, then the Helm chart will render a self-signed certificate (and secret to hold it), and use it.

This is all governed via the the `global.ingress.secret` value.  The secret configuration can have two formats:

- a string, which denotes the name of the secret (within the same namespace, and of type `kubernetes.io/tls`) which will be referenced by the Ingress resource in order to obtain the requisite SSL/TLS certificates
- a map, consisting of the following keys:
  - crt: the PEM-encoded SSL certificate to use
  - key:  the PEM-encoded SSL private key to use
  - ca: (*optional*) the PEM-encoded SSL CA certificate chain to serve up

## <a name="configuration-example"></a>Configuration Example

This is a brief example of what a completely valid ingress configuration (except for the certificates, of course), with SSL/TLS support, would look like:

```yaml
global:
  conf:
    #
    # This is the URL through which ArkCase will be accessed. Only HTTPS
    # URLs are supported because only crazy people don't use SSL these days :)
    #
    baseUrl: "https://my.arkcase-deployment.com/arkcase"

  ingress:
    #
    # This flag allows the deployer to explicitly disable the ingress generation
    # without modifying configurations. By default, it is assumed to be true if
    # the global.conf.baseUrl value is provided.
    #
    enabled: true

    #
    # This is the class name for the ingress class to use. If not given, the default
    # ingress class name for the cluster will be used.
    #
    className: "ingress-class-name"
    
    #
    # You can provide extra labels for the ingress here. These values will override
    # any conflicting labels added by default from the cloud compatibility layer.
    #
    labels:
      "label1": "value1"
      "label2": "value2"
      # ....
      "labelN": "valueN"
    
    #
    # You can provide extra annotations for the ingress here. These are usually
    # closely tied to the ingress class being used. These values will override
    # any conflicting annotations added by default from the cloud compatibility
    # layer.
    #
    annotations:
      "annotation1": "value1"
      "annotation2": "value2"
      # ....
      "annotationN": "valueN"

    #
    # The "cloud" section describes how to integrate with the load balancer and
    # ingress controller infrastructure as provided by an overarching cloud
    # environment like AWS, GKE, Azure, or even OpenShift.
    #
    # If the "cloud" stanza isn't given or is empty, the type is presumed to be "default"
    # (i.e. the behavior seen by developers with haproxy annotations, etc), which is tuned
    # for standalone cluster deployments (i.e. appropriate for development).
    #
    # There's an abbreviated syntax using the default values for the cloud's configuration,
    # for when you don't mean to set any other configurations and just want to get off the
    # ground quickly:
    #
    # cloud: "cloud-name"
    #
    # Here's the full syntax:
    #
    cloud:
      #
      # This will indicate which cloud compatibility settings to use. If no type
      # is given, or the value is the string "default", then the default cloud
      # infrastructure defaults for developer mode will be applied.
      #
      # For further configuration, a key with the given cloud name can be provided
      # below, to further tune configurations.
      #
      type: "cloud-name" # should be "azure", "aws", "default", or other supported names

      #
      # This is the key that would be used for AWS (type must also be set to "aws")
      #
      aws:
        # Default is "ELBSecurityPolicy-TLS13-1-2-2021-06"
        sslPolicy: "ssl-policy-to-use"

        # Default is "internet-facing"
        scheme: "scheme-to-use"

        # Default is "ip"
        targetType: "target-type-to-use"

        labels:
          # ... additional labels to set ...
        annotations:
          # ... additional annotations to set ...

      #
      # This is the key that would be used for Azure (type must also be set to "azure")
      #
      azure:
        # No config values yet, support is forthcoming...
        labels:
          # ... additional labels to set ...
        annotations:
          # ... additional annotations to set ...

    #
    # Extra modules (subsystems) to expose via the ingress.
    #
    # COMING SOON: public vs. private ingresses so administrators may
    # have access to other ecosystem applications without exposing them
    # to the general population.
    #
    modules:
      # A boolean-equivalent value of "true" is transformed to "private", for now.
      # Since we don't have private-vs-public yet, both private and public are treated the same.
      # Only values of "public", "private", or "true" will result in access paths being rendered
      artifacts: "public|private|off"
      content: "public|private|off"
      messaging: "public|private|off"
      reports: "public|private|off"
      search: "public|private|off"

    #
    # If the "secret" value is a string, then it represents the name of
    # the secret containing the SSL certificates (must be of type
    # kubernetes.io/tls, and contain valid tls.crt and tls.key values).
    #
    # secret: "tls-secret-name"

    #
    # If the "secret" value is a map, then it must contain the "crt" and
    # "key" values to be used when rendering the TLS secret resouce. The
    # "ca" value is optional, but may also be present.
    #
    secret:
      #
      # This an SSL certificate, in PEM format
      #
      crt: |-
        -----BEGIN CERTIFICATE-----
        DY82KKWTR1nF18IhGKcafNojIZwEyvFkIrJelFWGZRMXi2l01LmJhF739iI9Tl56tUYOeAqTIMuc
        4K9Ywu9ViYEhg5Js+AGVD73Xw5yffuxhzBxtVZiG3BGOoHuNDnSISO0ROYDTcJDp+K4Nvgpd81Eb
        /833KcfDPDwxKAA+sNo4iKEq5wEe2Lhr9w7LHXdI/BDPH11Ce6N+DD9zeo+VXPzkEbDKfegKnKR8
        wNV/UAJ2iK3Hr/hMv985Yzk8xUb+RaI5KhW9bgcpBZV/3xrTyuYsNUEL+nCdS1sudFbGUBCiclAh
        H9vGjBeCDYB2D5rBNFBr8veWCi+8Gw2GXlNVjAEqcRPMtBwSggpytpZDKx7T8awpv2MS7QaM8rlW
        Aci3l3HEDpBLaLaufgN/+tLYT6z6FoPP0piusGA1RZ3EcOx4KjNESVG79qsPqVFWyyxJsarb8003
        Ss0cF/6vydpNeB2CNB2bLtnoKu25NYZVwwdy1O4Sgwl+iujmaSJoKE+AFX8hEDDTAKxR7043imHQ
        XjYnWrXnTe4MqrXXP4NjMZ6uPklC/kmihEdSr5Vrd3WiOhkXbJLu1FHMz3sBmMuGUjXMZVplu55x
        ML/kkeQD1qdkrRWpFiklCUgnDdVQvwDP6cdPFAFYe6a+n7u0FpXEquD1w7QWwWJtX9ldbmvUaEe/
        T3TF2k3Fg+uEheuf9fjWJpxmAwafpi2Y6g31ku8yptOLSvD+QZP4u6kzXfffTSEQWnUFq0c3aMTj
        7FWwHoH20jjU7AxsF8cbcpLBc05t3iXKcdFZ2lPWlGZhNO73SN2qTa5MO+tXjQlZ0Qe2nKo7tKkf
        S6nzfknSLJp6YEGTRFHlrQvo1QVqFvu18+YOcZdPovkFNPAXkwKD3s3Cg2bPINVtKUX/xklhLu2V
        2ArwAgYg1liAcAdbL8aovRn66irhDMUYm2cLXdeiSpf6Q8vzi43tdaiEJ84uOKXEJSTnjo/Dwo4E
        DlRMp6utf2yYN4zPiXS/fqS8XDNVrRjH6HdVnkb9c6QVeYySDak9pn8rudlErB9KyFKNkgaBCcv9
        /EXHhqWB9zDswiFL6B/YkkuY5kYG0en56VMguhP5M3c4lp9zWoyX086G6vPm/VIkBpFhFEpLa1W+
        rSc7q/4Yebjb2FPcFLB33t6vZBAEUE+SH1HY33NWpbpCqtME+84uj9ITi2+LU7yhXATPhU6dfG4e
        /2w9mqHNSe8XMqZYiMctFsG2vXPfk0J4hrurU7CAXW8vpMM6uphWNFlgsYP3SNIQqatpM+hq1OkV
        pu+3/iE+7g1idyIOaMP5yf39W8EsYY+U5zIBWgJEMA+7I1Al6EGthXxkAFmoLpdUkN1IzZtQaA==
        -----END CERTIFICATE-----

      #
      # This an SSL certificate private key, in PEM format
      #
      key: |-
        -----BEGIN PRIVATE KEY-----
        oc5xSNe6V6iF/CVeKODKfLhYKopOdFdBx6o2mIrc++4kNUAaeu0YQ+kCdMLx+u0Gh9SEtP8ok0jX
        tvNLuFUGlkx6DU1znDOlO+8yfg3oCChTWlci42zrmDilOQarpN1YfdpznHu521oT6IGtqLLRKrGm
        PdzgcXQ7nbdEeVEzZMAIQ066E5/e8m418YTWtkwtFEpQnWrVqpuz5YMqxy3N1ZRKEMK0cqm/R72s
        zybKfp+qNRAqzJ4Q+9GFWcWmHYd0CznkEfo2Rk6ZUchDSAUXtUGGjSxrS5pZ2xiYegzikLyDucVT
        XaeqwHFjCbMn+EbM8EA4ZvytHsUgFfs3G6fnFwWsfT5rvLf/OE2E0EwN9lqk7mUWbjW+V/FYqvSs
        w6lBMqBqR/wQ8AK2bjGOLhwXIOVy3IQGxre5jSKTV6tnvDfXz/c+L4xqIKDj46/vRks2ONeAoxxJ
        DgpkX6Fw87pToyOMfV2grzFwxumJqXytVlEaK7DaOSuCPWNIBj8pXale9HzEx8Sq8yxv4H/ymKhz
        JnNsPl0FnmFfZrueFJqcoeHKJlKDDq+dLk9jv3F2zB+0nTg6L1iQlpfwPgPEN/C74sWN/inTmUF/
        JGsev1faSZsago1eWTe18qdipggfRP9N8Xxef/sN2OH7FWBOgduAjt9ambL8lBqpY26zJXGuCKKH
        jDJxWbcZLoqA6AYNzbJrXYYavahLSLcLPKWnmXgePUzZTEqVGMKU7FiYW9cQkfQdF4pJmzejJTs9
        gL02YQ7vP3zdbZoJ60wmylxGm0RQ4mzqqdw8m980uE64E/9LLY/ye44ueWhgE7fB5X860BZcUGbG
        TNzh7IVIBE42ZXd2+Yb9w0D9QnaM1O/xIUwchN+tB0BBVoTRYQRxz+pUle8FtPcj/GvmBmiZ74+m
        TxQ2ACmOQXDNLk7xAaFCjzfo9RzJqt7WqiqzDMS/1sjsxE2LSpOL6G5gq/ObE0DOxnqQS3Im0Uqp
        J3SGfWIB0LDJ+xDNk+HIhmCjz0Ct5XvhqWq5wzSHAez965wl0NZwAMKd3fqKmh/2sb80p5I0zPbv
        uW/0wrcHIG1DceO4m8TqWNe7IdEerMDsO7p0GZTOM9zyZKfSFDjUvkxMnYXAO2r65mnaXvn2TsiB
        XWsNbND2GXpfsUphs9zrgAwkL+SHwtDFngaIRn5q+mkxhbG9MgVlHRPDYQ66wGggHeX41zWCctxg
        cNkRZnPCU6fSZ19jBS1WNYf5I8JBnWkTpb71mcHra2Ch9DQcj9O0iHJQpRBMM0EVTNecJf8yFaP8
        ng+61ktSIo82EK7z/ZF0uKOJpT6J+yyq7LE+VNGil8HkrWBmVR9+ynKQOvlInZ+g1iKuZWJ/Xg==
        -----END PRIVATE KEY-----

      #
      # This an SSL CA certificate chain, in PEM format
      # (this entry is optional)
      #
      ca: |-
        -----BEGIN CERTIFICATE-----
        mJxtan5OxQ7oBxmQttC6bjsX3UUyYKMq17sIOMs/wV80xeU3EyduRGg59QQA3jKxmTcPF0vr1sPc
        uS3ii+yWu3E2RldJrc3XgykUoxnumlcmVnkHvzIoBxQkXzCYk7wOHr1mTX21nBhiK5QaYRG6+15N
        wmXp3Lxy73rrcoNDrqtUYB44qqzEGuBtxpe/9wmkuuwHoNwzgqTyOP+42h0eVQKdOFI7D3KR6KTH
        Wahmv3p6JTC2vI6PEEjBQ99MP+LH2FAG7Pzcb4Vn0zhRU++MOwO4iTbEBikdwlLFNKMReGWs5dFO
        ZXaOJTYW6/7jREbNvalMF3mbfS6OrCEMgL2S8dOU8AXDjRDXHx/+l39UCmd6oFqMnsWu8eDAPa5+
        Ga4IGz1UXlS96GGOxBroieCGx7Pwtt8ooCQQjK8MH/F+I9qWqoGNXvDEY+qNsg3fFfNQxye4uKlj
        Q3E3XLcbbDnP+j3iTCQVOYnuJZySDHJd+khlLpbR9xy/BMzsqW5TLvF9Hpyq7ZalTcYla54fnkM+
        k8IwqbDRb9WXar22XI2cVh0BUPo7XH8yTfOr7kfmIEDgLrJqPeZakhHBQHqRz/6pkoqbyQjhUYMp
        jFzAw+SKwkYxZpq+grMwGGekoA7tJTkXHqWerhWkqbKOz6XlG0lGjBcLlU+KdfKbg7/X/X2VY4G6
        LA8OQ9lcFAvl3jfdYFTHpyKkGkHD5+6PI3ASwq0XiIcSC9CB4Efgmwo5/xd0Yb05EcXP8NzGv0e2
        UCp3NooKPxyAOP9wxK3dwYFZ6SS2eHn0di+MGnt7i9Hju0LrhxHO92dJYOZVTf3shS0Tj/BLwVGU
        HiWinsYns97ofijxNxLULqL7RplY+OCAlwaP44vsiyfehmnT/0K7UE7eU70ZgNaiUlSiynJnLwBG
        sCoIbpONsNjVv7tueczhyPclFPZ7M1a574A5KRP0aNO1AR/f0suB8iaNi5yF4SfDLTWImut68gr/
        7Wl7zthHhsT3fFn/0gAZGeQnT/wl31Pz4Mxf99z3HI7OVCZaleR+Q6tvMEkPZ/2V/TTLfsCuUePj
        /8Nxx6rhr1+HJUK6Z4up3JIEAuXSu2BBJVXrTl9kwekuY0780am88H/8honZrXVYn4VLNcKnLe7V
        8Yq/kxJ+RHHluMn1q6BtewejMKapUA+jK2R3EJ6UXVDu1EL6F1+M/pM/RjNNTILS5d2g7ZjgjHxC
        iWL5mdInTY9sepjgrGFzvrynSmBvgMWKESMPmMZQM4973fVqOSQO0i0VBNrcdwp4SG+GHTYl6Xxh
        ZDr/XXXj8xfXVXuDhp6exUZ4T+NBQirXmP5nIPic/kZ4KlzBtAxYqAqyPr/3fJFyvFMu6uZinQ==
        -----END CERTIFICATE-----
        -----BEGIN CERTIFICATE-----
        # ...
        -----END CERTIFICATE-----
        -----BEGIN CERTIFICATE-----
        # ...
        -----END CERTIFICATE-----
        # ...
```

As mentioned above, `global.conf.baseUrl` MUST be an `https://` URL.

### <a name="annotations"></a>Annotations

The `global.ingress.annotations` section is useful for providing additional instruction to the K8s ingress controller. The ingress class is selected by way of the `global.ingress.className` parameter. Some controllers support more nuanced configuration via proprietary annotations, which can be provided in this section.

Documenting the possible values for those configuration annotations is beyond the scope of this document, and is left as an exercise for the reader.

## <a name="supported-clouds"></a>Supported Clouds

Currently, the application has out-of-the-box support for the following cloud infrastructure providers.  Feel free to submit MRs/PRs to add support for others of your choosing.  The "tag" described below is the string to be used either in the `global.ingress.cloud.type` value, or the `global.ingress.cloud` value when using the abbreviated syntax (see the configuration example, above).

### <a name="cloud-default"></a>Default (i.e. development) Cloud

- Tag: `default`
- Default Annotations:
    - `haproxy-ingress.github.io/backend-protocol: "h1-ssl"`
    - `haproxy-ingress.github.io/ssl-redirect: "true"`
    - `haproxy-ingress.github.io/secure-backends: "true"`
    - `haproxy-ingress.github.io/secure-sni: "host"`
    - `haproxy-ingress.github.io/timeout-connect: "30s"`
    - `haproxy-ingress.github.io/timeout-http-request: "2m"`
    - `haproxy-ingress.github.io/timeout-keep-alive: "5m"`
- Default Labels:
    - _None_

### <a name="cloud-aws"></a>Amazon Web Services

- Tag: `aws`
- Default Annotations:
    - `alb.ingress.kubernetes.io/backend-protocol: ${baseUrl.scheme}`
    - `alb.ingress.kubernetes.io/listen-ports: [{"HTTPS": ${baseUrl.port}}]`
    - `alb.ingress.kubernetes.io/scheme: "internet-facing"`
    - `alb.ingress.kubernetes.io/target-type: "ip"`
    - `alb.ingress.kubernetes.io/ssl-policy: "ELBSecurityPolicy-TLS13-1-2-2021-06"`
    - `alb.ingress.kubernetes.io/ssl-redirect: "${baseUrl.port}"`
    - `aws.k8s.acm.manager/domain_name: "${baseUrl.domainName}"`
    - `external-dns.alpha.kubernetes.io/hostname: "${baseUrl.hostname}"`
- Default Labels:
    - _None_

### <a name="cloud-azure"></a>Microsoft Azure

- Tag: `azure`
- Default Annotations:
    - _TBD_
- Default Labels:
    - _TBD_

