# [ArkCase](https://www.arkcase.com/) External Services Configuration

## Table of Contents

* [Introduction](#introduction)
* [General Use Pattern](#general-pattern)
* [External Databases](#external-database)
* [SSL/TLS Considerations](#ssl)

## <a name="introduction"></a>Introduction

This document describes how to configure the an ArkCase deployment built with these helm charts to interface with services provided externally. Essentially every service that can be deployed as part of this stack, can be provided externally, except for ArkCase itself.

In almost all cases, along with an external URL or hostname, you must also provide additional configurations like usernames, passwords, etc.

## <a name="general-pattern"></a>General Pattern

In general, when providing a `url` configuration for a given **service** (i.e. component), the deployment process will interpret this as a desire by the deployer to avoid instantiating the associated, bundled-in services in favor of externally-provided services.

***NOTE**: if you opt for this approach, the responsiblity falls to you to properly configure and initialize said service **before** you boot up ArkCase to interface with them.*

The general gist of external service configuration is as follows (except for the database, which is covered separately):

```yaml
global:
  conf:
    # This would be the name of the service that is provided externally. I.e. "ldap", "search",
    # "content", "messaging", etc.
    ${service}:
      url: "the-url-where-the-service-is-accessible"
      # other configurations go here
```

The above configuration can be replicated for every service provided externally. Currently, the following charts will interpret the presence of the `global.conf.${service}.url` configuration value as a desire to inhibit the deployment of the bundled component:

- ldap (Samba)
- messaging (ActiveMQ)
- search (Solr)
- content (Alfresco)
- reports (Pentaho)

As an example, the following configuration would cause ArkCase to connect to an external (imaginary) Active Directory instance for an example domain:

```yaml
global:
  conf:
    ldap:
      url: "ldaps://dc-01.myexample.domain.com"
      domain: "example.domain.com"
      bind:
        dn: "cn=svc-bind-dn-account,cn=Users,${baseDn}"
        password: "phieDuquiy_o@o4ierae5Eex"
```

The above configuration will cause the ***ark-samba*** chart, which provides the `ldap` services, to not render the requisite pods during deployment. Simultaneously, other charts that consume LDAP services will automatically utilize the given parameters to configure their LDAP access and interaction.

Here's another example, for external Alfresco:

```yaml
global:
  conf:
    content:
      url: "https://content.mydomain.com/alfresco"
      username: "arkcase-proxy-user"
      password: "eish4oi;ph8eik4eo6tiBi0e"
```

Enabling the above configurations will have a similar effect: all charts/pods that consume Alfresco services will be configured to use the given values, and the Alfresco pods will not be rendered.

## <a name="external-database"></a>External Database

To be written

## <a name="ssl"></a>SSL/TLS Considerations

To be written
