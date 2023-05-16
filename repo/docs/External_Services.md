# [ArkCase](https://www.arkcase.com/) External Services Configuration for Helm

## Table of Contents

* [Introduction](#introduction)
* [General Use Pattern](#general-pattern)
* [External Databases](#external-database)
* [External LDAP Authentication](#external-ldap)
* [SSL/TLS Considerations](#ssl)

## <a name="introduction"></a>Introduction

This document describes how to configure the an ArkCase deployment built with these helm charts to interface with services provided externally. Essentially every service that can be deployed as part of this stack, can be provided externally, except for ArkCase itself.

In almost all cases, along with an external URL or hostname, you must also provide additional configurations like usernames, passwords, etc.

As with any community-release project, Issues and PRs are always welcome to help move this code further along.

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

To configure an external database, things are a little bit different. Instead of providing a URL, a hostname must be provided, like so:

```yaml
global:
  conf:
    rdbms:
      hostname: "my.database.com"
      port: 5432
      dialect: "postgresql"
      # More settings ...
```

In the case of the database (`rdbms`) service, it's the `hostname` configuration parameter that determines if the database is provided by an external server. Other parameters may need to be provided, such as the dialect (i.e. type of database), and port (if non-standard). However, these alternate values may be provided while still using a bundled database (i.e. to switch from PostgreSQL to MariaDB, for instance).

Recall that if you want to use an external database server, you must have pre-configured all the necessary database users, passwords, and schemata (tables, etc.) beforehand.

The database configuration has a very specific structure that must be followed when being overridden. *It is **strongly** recommended to **not** override any values other than the database dialect when deploying the embedded database pods*. Here's a general example of how the database configuration is structured:

```yaml
global:
  conf:
    rdbms:

      # The type of the database
      # Currently only postgres, mysql, mariadb, oracle, and mssql are supported.
      dialect: "postgres"

      # The host the DB is on. Only give this value if the DB is 
      hostname: "my-db-hostname"

      # The port at which it's accessible. If not given, a well-known default
      # will be used. Only provide this value if a non-standard port is used.
      port: 1234

      # This is generally optional, except for Oracle in which the instance (SID) is
      # required. It's also supported for SQL Server.
      # instance: "defaultInstance"

      # These may be necessary in some scenarios, but generally aren't.
      # admin:
      #   username: "...."
      #   password: "...."

      # Here we add the list of DB "schemas" that must exist on the target server,
      # and the necessary information to connect
      schema:

        # The schema name (only in abstract, for reference by the charts...has no
        # reflection on the database connectivity)
        numberone:

          # The name of the database. If not given (or empty), defaults to the schema's symbolic name
          database: "dbone"

          # The username to connect as. If not given (or empty), defaults to the database name
          username: "first"

          # The password to connect with. If not given (or empty), defaults to an SHA-1 checksum of the user name, all lowercase
          password: "io8aeHeeja+go3ju"

          # Optional ... only if required by the target DB (i.e. Oracle SID, SQL Server instance name)
          # instance: "myInstance"

          # Optional ... only if required by the target DB (i.e. PostgreSQL or SQL Server schema name)
          # schema: "public"

        deuce:
          database: "seconddb"
          username: "duo"
          password: "eGhu6ul)eePea&sh"
          # ...

        # ... more schema definitions here

```

Please refer to the next section for details on the database users and schemas that need to be configured for ArkCase, and how to specify the required configurations for deployment.

### <a name="external-database-init"></a>Initializing an External Database

As part of the process of interfacing with an externally-hosted database, the ArkCase application and its components will require "manual" configuration of a number of parameters which in turn reflect actual database configurations that must be in place prior to attempting a deployment.

Currently, the ArkCase ecosystem makes no attempt to execute these creation tasks on external servers, for safety reasons. It falls to the deployment team to prepare the groundwork on the external database in order to support ArkCase.

These are the database schemata that need to be created, organized by the component that requires them. The "name" column is the symbolic name for the schema, as referenced from within the helm charts.

|Name|Components that use it|
|--|--|
|arkcase|Core (ArkCase), Reports (Pentaho)|
|content|Content (Alfresco)|
|hibernate|Reports (Pentaho)|
|jackrabbit|Reports (Pentaho)|
|quartz|Reports (Pentaho)|

For each of these schemata, you must also create or select a username and password with which you'll want to allow access for the different components.

As a result, if you wish to interface ArkCase with an external database, you ***must*** provide connection information for each of the above schemata, except for those schemata related to components that won't be rendered (for example if you will be using an external Alfresco instance, then you can ignore creating and configuring the *content* schema since it's assumed that this has already been done as part of the Alfresco deployment).

Here's an example of what that database configuration may end up looking like (assuming a PostgreSQL instance):

```yaml
global:
  conf:
    rdbms:

      # Always required
      dialect: "postgresql"

      # Always required
      hostname: "psqldb.my-domain.com"

      # Only required if using a non-default port
      # port: 15432

      schema:
        # Always required
        arkcase:
          username: "arkcase-db-user"
          password: "<some-password-value>"

        # Only required if Alfresco is being deployed
        content:
          username: "alfresco-db-user"
          password: "<some-password-value>"
      
        # Only required if Pentaho is being deployed
        hibernate:
          username: "pentaho-db-user"
          password: "<some-password-value>"

        # Only required if Pentaho is being deployed
        jackrabbit:
          username: "pentaho-jcr-db-user"
          password: "<some-password-value>"

        # Only required if Pentaho is being deployed
        quartz:
          username: "pentaho-quartz-db-user"
          password: "<some-password-value>"
```
## <a name="external-ldap"></a>External LDAP Authentication

To configure external LDAP Authentication, things are also a little bit different. In addition to providing the LDAP(S) URL, you must also provide some information regarding how the directory is configured. The default organization assumes an [Active Directory](https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/get-started/virtual-dc/active-directory-domain-services-overview) organization.

This is the complete configuration available for LDAP services. Not all values are required - for example, it's generally sufficient to provide the URL (`global.conf.ldap.url`), the domain specification (`global.conf.ldap.domain`), and the bind details (`global.conf.ldap.bind.dn` and `global.conf.ldap.bind.password`):

```yaml
global:
  conf:
    ldap:
      url: "ldaps://ldap:636"
      domain: "my.external-ldap.domain.com"
      # Don't declare a baseDn unless absolutely necessary
      # baseDn: "ou=Case Management,dc=my,dc=external-ldap,dc=domain,dc=com"
      bind:
        dn: "cn=ArkCase Administrator,cn=Users,${baseDn}"
        password: "someUserBindPassword"
      admin:
        dn: "cn=ArkCase Administrator"
        role: "cn=ARKCASE_ADMINISTRATOR"
      search:
        users:
          base: "cn=Users"
          attribute: "sAMAccountName"
          filter: "(&(objectClass=user)(sAMAccountName={0}))"
          allFilter: "(objectClass=user)"
          prefix: ""
        groups:
          base: "cn=Users"
          attribute: "cn"
          filter: "(&(objectClass=group)(cn={0}))"
          allFilter: "(objectClass=group)"
          membership: "(&(objectClass=group)(member={0}))"
          ignoreCase: "false"
          subtree: "true"
          rolePrefix: ""
          prefix: ""
```

In more nuanced cases you may also have to provide the baseDn (`global.conf.ldap.baseDn`), as well as other values describing how to find users, groups, memberships, etc.  Please note that the configurations that appear to be missing a complete DN specification (i.e. like `global.conf.ldap.search.users.base` or `global.conf.ldap.search.groups.base`) are set in that manner by design, because when they're consumed while rendering configuration files, the baseDn value is appended unto them at that moment.

### User Management

ArkCase's user management features require the bind DN user to be able to create or modify users and groups. These permissions must be managed manually, or these features will not work as desired.

## <a name="ssl"></a>SSL/TLS Considerations

In order to consume external services using SSL/TLS, it's important to establish trust between the ArkCase stack and those services. The expectation is that those services will be utilizing certificates signed by a Certification Authority. Thus, the solution to establish trust is to enable the adding of those CA certificates into the stack's trust-at-large. The way to establish that trust is by the following configuration model:

```yaml
global:
  trusts:

    # A URL that leads directly to a certificate, or certificate chain.
    # Only CA certificates will be added to the trust.
    - http://www.my-certificates.com/trusted/root.pem

    # An actual PEM-encoded certificate, or chain. Only CA certificates
    # will be added to the trust.
    - |
      -----BEGIN CERTIFICATE-----
      MIIFeDCCBGCgAwIBAgIBLTANBgkqhkiG9w0BAQsFADCBtzELMAkGA1UEBhMCQ1Ix
      ETAPBgNVBAgTCFNhbiBKb3NlMRIwEAYDVQQHEwlTYW50YSBBbmExFzAVBgNVBAoT
      DkVydWRpY2l0eSBTLkEuMRwwGgYDVQQLExNTZWN1cml0eSBPcGVyYXRpb25zMSMw
      BgNVBAoTDkVydWRpY2l0eSBTLkEuMRwwGgYDVQQLExNTZWN1cml0eSBPcGVyYXRp
      b25zMRkwFwYDVQQDExBkaWVnby5yaXZlcmEucHJ2MSUwIwYJKoZIhvcNAQkBFhZz
      ......
      -----END CERTIFICATE-----

    # A string of the form [serverName@]hostName:port, which will be queried
    # using openssl s_client to obtain the offered certificates, and any CA
    # certificates returned will be added to the trust.
    - psql.service.com@10.35.4.32:3434

```

You can add any number of certificates or pointers/URLs to certificates here. Only CA certificates (`basicConstraints.CA=TRUE`) will be added to the trust stores.
