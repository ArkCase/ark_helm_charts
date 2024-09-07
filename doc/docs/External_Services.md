# [ArkCase](https://www.arkcase.com/) External Services Configuration for Helm

## Table of Contents

* [Introduction](#introduction)
* [General Use Pattern](#general-pattern)
* [Required Secrets and Structures](#required-structure)
* [External LDAP Authentication](#external-ldap)
* [External Content Store](#external-content-store)
* [E-mail Send & Receive](#email)
* [SSL/TLS Considerations](#ssl)

## <a name="introduction"></a>Introduction

This document describes how to configure the an ArkCase deployment built with these helm charts to interface with services provided externally. Essentially every service that can be deployed as part of this stack, can be provided externally, except for ArkCase itself.

In almost all cases, along with an external URL or hostname, you must also provide additional configurations like usernames, passwords, etc.

As with any community-release project, Issues and PRs are always welcome to help move this code further along.

## <a name="general-pattern"></a>General Pattern

In general, the Helm chart needs to be told which secret(s) describe the access and connectivity information for each **subsystem** (i.e. _service_)that is to be consumed from an external source. This preserves security while allowing the application access to those configurations at runtime.  The presence of such a secret specification will be interpreted by the chart as a desire by the deployer to avoid instantiating the associated, bundled-in **subsystem** in favor of an externally-provided one.

***NOTE**: if you opt for this approach, the responsiblity falls to you to properly provision, configure, and initialize said systems **before** you boot up ArkCase to interface with them. ArkCase will only make a _best effort_ attempt to wait for those services to come online by way of TCP connectivity tests. If this type of check is insufficient, then you must provide the means to delay ArkCase bootup until those services are available for its consumption.*

The general gist of subsystem configuration is as follows:

```yaml
global:
  subsys:
    # This would be the name of the subsystem that is provided externally,
    # such as "rdbms", ldap", "search", "content", "messaging", etc.
    ${subsystemName}:
      settings:
        # Here you would place the settings that describe the service's
        # configuration, INDEPENDENT of its connectivity settings. For
        # instance: the database dialect, the LDAP domain, etc.
        #
        # setting-1: value-1
        # setting-2: value-2
        # ...
        # setting-N: value-N

      # The "external" section describes where to how to
      # access an externally-provided subsystem

      # This is the abridged version. The subsystem won't
      # be rendered, but pods that consume its services will
      # still expect the default-named secrets to be provided
      # with the default key names holding the correct values.
      # 
      # external: true|false

      #
      # This is the full version, with all the trimmins
      #
      external:

        # For quick turn on/off (defaults to true if non-empty connection
        # entries are provided), will consume all secrets using the default
        # expected names.
        enabled: true

        # Indicate the actual name to be used when reading
        # an expected setting. For example: a subsystem may
        # need the hostname setting name to be "host", but
        # the secret may provide that value under the name
        # "endpoint", so this mapping would have to indicate
        # that this is the case.
        #
        # This instance of the mappings is meant to be shared
        # by all defined connections, in the event that this
        # helps keep the configuration brief and DRY.
        #
        mappings:
          host: "endpoint"
          # expected-key-2: actual-key-2
          # expected-key-3: actual-key-3
          # ...
          # expected-key-N: actual-key-N

        #
        # The connections and where/how they're configured. The connection
        # names required to consume each subsystem are described below.
        #
        connection:
          #
          # Abbreviated version (i.e. only the secret name,
          # no key mappings, and inherit any global ones)
          #
          # connection-name: "name-of-the-secret-that-configures-it"

          # Here, "admin" is the connection's symbolic name
          admin:

            # The name of the secret where the configuration
            # values are to be consumed from
            source: "some-secret-name"

            # Turn mapping inheritance on or off
            inherit-mappings: true

            # Any necessary key mappings to translate from the expected
            # key name to the actual key name, as above. This configuration
            # example would expect that the details for the connection named
            # "admin" would be held in the secret named "some-secret-name"
            # and that within that secret, the value for "password" would be
            # in the key "secret-identification-key", while the value for
            # "host" would be in the key "endpoint" (b/c this mapping is
            # inherited from the global mappings)
            mappings:
              password: "secret-identification-key"


```

The above configuration can be replicated for every service provided externally. The presence of the `global.subsys.${subsys}.external` map with either the value `enabled` set to `true`, or non-empty connection descriptions, will be interpreted as a desire to consume a subsystem externally. All connections will be expected to be provided by that external subsystem, and any connections not expressly configured will assume the default secret name (described below for each subsystem).

As an example, the following configuration would cause ArkCase to connect to an external (imaginary) Active Directory instance for an example domain:

```yaml
global:
  subsys:
    ldap:
      settings:
        domain: "example.domain.com"
      external:
        connection:
          admin: "example-admin-secret"
          arkcase: "arkcase-ldap-secret"
          portal: "secret-for-portal-ldap"
```

The above configuration will cause the ***ark-samba*** chart, which provides the `ldap` services, to not render the requisite pods during deployment. Simultaneously, other charts that consume LDAP services will automatically utilize the given parameters to configure their LDAP access and interaction by consuming configuration values directly from those secrets (via environment variables).

Here's another example, for external S3, using the abridged configuration syntax:

```yaml
global:
  subsys:
    content:
      settings:
        dialect: s3
      external: true
```

Enabling the above configurations will have a similar effect: all charts/pods that consume S3 services will be configured to consume the connectivity details from the default secret locations, and the Minio (S3 service) pods will not be rendered. It will be up to the deployer to provide those secrets and ensure they have the correct information.

## <a name="subsystem-configurations"></a>Subsystem Configurations

As seen above, the subsystem configuration can supply details on how to consume them from external sources, as well as specific configurations that are independent of where those services are consumed from. This section describes these settings with examples.

Every ArkCase subsystem that consumes services from other subsystems must consume a specific, immutable set of configuration _*values*_ that it needs in order to achieve interaction. _Where these values are stored and consumed from may vary_, but the _set of values proper_ may not. This listing describes the structure that those secrets are expected to follow, and thus how the other subsystems will consume them.  In the following descriptions, you may see placeholders such as `${release}`, `${subsys}`, and `${connection}` - these can be interpreted as follows:

- `${release}` == the name of the release, as used during `helm install RELEASE ...`
- `${subsys}` == the name of the subsystem being described
- `${connection}` == the name of the connection being described

Finally, externally-provided secrets may provide the correct values, but not always under the expected names. This is what the `mappings:` sections, shown above, seek to address. So don't worry if your source secret doesn't match the expected secret perfectly in terms of names - the important thing is that the ***VALUES*** must match what's expected.

Finally, the _*default*_ names for the configuration secrets for _*any*_ connection follow this pattern: `${release}-${subsys}-${connection}`. This means that for the subsystem "ldap" in the release "arkcase", the connection named "portal" would be described by the secret `arkcase-ldap-portal`.

### <a name="secret-acme"></a>ACME (SSL certificate generation)

The [ACME](https://en.wikipedia.org/wiki/Automatic_Certificate_Management_Environment) component is meant to provide a simple, self-contained PKI infrastructure for disposable, yet trustworthy certificates for the ArkCase application. The certificates aren't meant to be exported to other services, nor consumed by outside participants. These certificates exists solely for the purpose of deploying end-to-end SSL for _*all*_ subsystems in such a manner that trust can be easily managed automatically with zero user intervention. The current implementation relies on Step-CA's proprietary protocols, so the use of "ACME" is a bit of a misnomer. That said, given the correct values, there's no reason an ArkCase deployment can't consume certificates from an externally-hosted Step-CA instance.

- Subsystem Name: `acme`

- Settings:
    - _n/a_

- Connections:
    - `main`:
        - `url`: The URL where the Step-CA service is running (e.g. `https://step-ca.server.com:9000`)
        - `password`: The password with which certificates may be obtained from the server (may not be the empty string)

### <a name="secret-app-artifacts"></a>Application Artifacts

The Application Artifacts subsystem houses all the necessary application artifacts for the execution of a single, specific deployment of ArkCase. All the artifacts contained within can be thought of as tightly correlated: the version of ArkCase closely matches the version of the Portal (where applicable), and the version of the FOIA reports, etc. Technically speaking this *can* be hosted externally, but there is generally no need to do so.

- Subsystem Name: `app`

- Settings:
    - _n/a_

- Connections:
    - `main`:
        - `url`: The URL where the application artifacts may be downloaded from (e.g. `https://artifacts-server.domain.com:8443/artifacts`)

### <a name="secret-content"></a>Content Storage (Alfresco or S3/Minio)

ArkCase requires a place to store the documents that are uploaded to into it by end-users. Two types of content stores are supported: S3-compatible (i.e. [Minio](https://min.io/), [Amazon S3](https://aws.amazon.com/s3/), etc.) or [Alfresco](https://www.hyland.com/en/products/alfresco-platform).

- Subsystem Name: `content`

- Settings:
    - `dialect`: the content store engine's dialect - must be one of `alfresco`, `cmis` (an alias for `alfresco`), `s3`, or `minio` (an alias for `s3`)

- Connections:
    - `main`, `admin`:
        - `ui`: the URL to the content engine's UI (only used when the dialect is `alfresco`)
        - `url`: the URL to the content engine's backend API
        - `username`: the username to connect as
        - `password`: the password to authenticate with
        - `rm`: (optional, only for `alfresco`) the name of the Records Management Site to link with (the default value is `rm`)
        - `site`: (optional, only for `alfresco`) the name of the Site to store the content in (the default value is `acm`)
        - `bucket`: (optional, only for `s3`) the name of the bucket to store the content in (the default value is `arkcase`)
        - `region`: (optional, only for `s3`) the name of the region the bucket is stored in (the default value is `us-east-1`)

The `main` connection will be used during general operation and need only have sufficient privileges to store and retrieve content freely.  The `admin` connection may be needed by ArkCase for certain functions during initialization, and as such the provided credentials must have sufficient permissions to execute those initialization tasks.

***NOTE:* if you wish to connect directly with Amazon S3, use the URL `https://s3.amazonaws.com` in your secrets **

### <a name="secret-ldap"></a>LDAP (Samba in Active Directory mode)

***NOTE:* ArkCase currently has an issue with regards to user and group authentication which causes [authentications to fail on case mismatch](https://arkcase.atlassian.net/jira/software/projects/ADS/issues/ADS-2353). Until that ticket is resolved, specific values listed below must be treated as case-sensitive where expressly specified.**

ArkCase utilizes LDAP as a user and group database, and leverages the underlying authentication mechanisms. ArkCase requires either one or two LDAP trees: one for base ArkCase (known as `arkcase`), and one for the Portal offering (known as `portal`). The default deployment sees both directories deployed within the same Samba instance. This need not be the case when consuming them from an external source.

- Subsystem Name: `ldap`

- Settings:

    - Common:
        - `create`: a boolean flag which controls whether user creation is enabled
        - `edit`: a boolean flag which controls whether user edition is enabled
        - `sync`: a boolean flag which controls whether LDAP sync is enabled
        - `domain`: the LDAP domain for all LDAP trees, _*in lowercase*_ (e.g. `some.example.com`, only applicable when deploying the included LDAP directory)

    - `arkcase`:
        - `create`: a boolean flag which controls whether user creation is enabled
        - `edit`: a boolean flag which controls whether user edition is enabled
        - `sync`: a boolean flag which controls whether LDAP sync is enabled

    - `portal`:
        - `create`: a boolean flag which controls whether user creation is enabled
        - `edit`: a boolean flag which controls whether user edition is enabled
        - `sync`: a boolean flag which controls whether LDAP sync is enabled

- Connections:

    - `main`: (services the `arkcase` LDAP tree)
        - `url`: The LDAP URL to connect to (must be `ldaps://...`)
        - `username`: The username to use when connecting to the URL (will be appended to the realm, like so: `${REALM}\${USERNAME}`)
        - `password`: The password to authenticate with
        - `domain`: the LDAP domain for this LDAP directory, _*in lowercase*_ (e.g. `some.example.com`)
        - `realm`: the LDAP realm for this LDAP directory, _*in UPPERCASE*_ (e.g. `SOME`)
        - `rootDn`: the LDAP root DN for this LDAP directory, _*in UPPERCASE*_ (e.g. `DC=SOME,DC=EXAMPLE,DC=COM`)
        - `baseDn`: the RDN (relative to the `rootDn` value) that will serve as the root for all ArkCase-related LDAP objects (e.g. `ou=ArkCase`)
        - `userBaseDn`: the RDN (relative to the `baseDn` value) where users will be stored/searched for (e.g.`ou=Users`)
        - `userClass`: the object class for user objects (e.g. `user`)
        - `userListFilter`: the search filter applied when listing users (e.g. `(objectClass=user)`)
        - `userMembershipFilter`: the search filter applied when examining user membership (e.g. `(&(objectClass=user)(memberOf={0}))`)
        - `userNameAttribute`: the attribute that houses the username (e.g. `sAMAccountName`)
        - `userPrefix`: the prefix to apply to each username when performing lookups, etc. (e.g. `451.`)
        - `userSearchFilter`: the filter to use when searching for specific users (e.g. `(&(objectClass=user)(sAMAccountName={0}))`)
        - `groupBaseDn`: the RDN (relative to the `baseDn` value) where groups will be stored/searched for (e.g.`ou=Groups`)
        - `groupClass`: the object class for group objects (e.g. `group`)
        - `groupListFilter`: the search filter applied when listing groups (e.g. `(objectClass=group)`)
        - `groupMembershipFilter`: the search filter applied when examining a group's direct membership (e.g. `(&(objectClass=group)(member={0}))`)
        - `groupNameAttribute`: the attribute that houses the groupName (e.g. `cn`)
        - `groupPrefix`: the prefix to apply to each group name when performing lookups, etc. (e.g. `451.`)
        - `groupRecursiveMembershipFilter`: the search filter applied when examining a group's recursive membership (e.g. `(member``:1.2.840.113556.1.4.1941``:={0})`)
        - `groupSearchFilter`: the filter to use when searching for specific groups (e.g. `(&(objectClass=group)(cn={0}))`)
    - `portal`:
        - (requires the same set of settings as for `main`, but may have different values; most commonly, the credentials and the `baseDn` values will be different, but the rest will be the same)

The `main` and `portal` connections will be used during general operations and will only need elevated privileges within their `baseDn` if and only if the `create` and `edit` settings are enabled for their respective trees (they are by default). Otherwise, if there will be no LDAP modification required from within ArkCase, they can be read-only credentials.

### <a name="secret-messaging"></a>Messaging (Apache ActiveMQ Artemis)

ArkCase makes use of [Apache ActiveMQ Artemis](https://activemq.apache.org/components/artemis/) for its message broker (AMQP) and WebSocket (STOMP) services.

- Subsystem Name: `messaging`

- Settings:
    - _n/a_

- Connections:
    - `arkcase`:
        - `username`: The username to use when authenticating to either service
        - `password`: The password to use when authenticating
        - `amqpUrl`: The AMQP URL where the service is being hosted (e.g. `ssl://activemq.server.com:61616`)
        - `stompUrl`: The STOMP URL where the service is being hosted (e.g. `ssl://activemq.server.com:61613`)
    - `cloudconfig`:
        - `username`: The username to use when authenticating to either service
        - `password`: The password to use when authenticating
        - `amqpUrl`: The AMQP URL where the service is being hosted (e.g. `ssl://activemq.server.com:61616`)
        - `stompUrl`: The STOMP URL where the service is being hosted (e.g. `ssl://activemq.server.com:61613`)

### <a name="secret-rdbms"></a>Database (MariaDB 10.6 / PostgreSQL 13)

ArkCase, Pentaho (a.k.a. _reports_), and Alfresco (when used) require a relational database to store state information. This service can be provided by an instance of either MariaDB 10.6, MySQL 8, or PostgreSQL 13.  The ArkCase Helm charts support embedded deployment of an instance of MariaDB 10.6, or PostgreSQL 13.

- Subsystem Name: `rdbms`

- Settings:
    - `dialect`: The database dialect to use. Must be either `mariadb` (aliased as `mysql`), or `postgresql` (aliased as `psql` or `postgres`). If this value is not provided, the default dialect is PostgreSQL.

- Connections:
    - `arkcase`:
        - `endpoint`: The host or IP providing the service
        - `port`: The port number
        - `username`: The username to use when authenticating
        - `password`: The password to use when authenticating
        - `database`: The name of the database
        - `schema`: The within the database (if applicable, may be empty)
    - `content`:
        - `endpoint`: The host or IP providing the service
        - `port`: The port number
        - `username`: The username to use when authenticating
        - `password`: The password to use when authenticating
        - `database`: The name of the database
        - `schema`: The within the database (if applicable, may be empty)
    - `jcr`:
        - `endpoint`: The host or IP providing the service
        - `port`: The port number
        - `username`: The username to use when authenticating
        - `password`: The password to use when authenticating
        - `database`: The name of the database
        - `schema`: The within the database (if applicable, may be empty)
    - `pentaho`:
        - `endpoint`: The host or IP providing the service
        - `port`: The port number
        - `username`: The username to use when authenticating
        - `password`: The password to use when authenticating
        - `database`: The name of the database
        - `schema`: The within the database (if applicable, may be empty)
    - `quartz`:
        - `endpoint`: The host or IP providing the service
        - `port`: The port number
        - `username`: The username to use when authenticating
        - `password`: The password to use when authenticating
        - `database`: The name of the database
        - `schema`: The within the database (if applicable, may be empty)

The secret structure for the RDBMS connections is almost identical to the secrets generated when provisioning an RDS instance, with the addition of two fields: `database` and `schema`.  Since the RDS provisioning supports adding the connectivity details into an existing secret, it's OK to render these secrets ahead of time with the intended-known information for those fields.

### <a name="secret-reports"></a>Reports (Pentaho 9.4.0.0)

ArkCase makes use of Pentaho to generate reports and in some deployments populate DataWarehousing tables and cubes that are used for some advanced reporting features.

***NOTE:* ArkCase requires administrative privileges in its target Pentaho tenant because it needs to support the ability to add, modify, and remove reports at runtime.**

- Subsystem Name: `reports`

- Settings:
    - _n/a_

- Connections:
    - `main`:
        - `url`: The URL where the Pentaho instance is available (e.g. `https://pentaho.myserver.com:8443/pentaho`)
        - `username`: The username to use when authenticating
        - `password`: The password to use when authenticating

### <a name="secret-search"></a>Search (Apache Solr 8.11.3)

ArkCase makes use of Solr for its FTS services, as well as many other security-related services.

- Subsystem Name: `search`

- Settings:
    - _n/a_

- Connections:
    - `main`:
        - `url`: The URL where the Solr instance is available (e.g. `https://cloud.solr-cluster.com/`)


### <a name="secret-zookeeper"></a>Zookeeper (Apache Zookeeper 3.8.6)

ArkCase, Pentaho, and Solr make use of Zookeeper when deployed in a clustered configuration.

- Subsystem Name: `zookeeper`

- Settings:
    - _n/a_

- Connections:
    - `main`:
        - `zkHost`: The list of Zookeeper nodes, as would be set in the `ZK_HOST` environment variable (e.g. `zk-0.mydomain.com:2181,zk-1.mydomain.com:2181,external-zk.another-site.net:2181`)


---









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

Note that within the `ldap` stanza, the next level down is the name of the LDAP _directory_ (i.e. configuration set). Multiple directory configuration sets are supported, though currently only _arkcase_ and _foia_ are used actively in the charts. Other directories defined may be visible within the application, but are not directly used within the charts.

In the below configuration example, the `${directory}` value is _arkcase_, for demonstration purposes. The `default:` value describes the name of the directory configuration to use as the deployment's default. This affects chart rendering for cases where a chart doesn't consume a specific configuration name and instead just seeks to consume the default configuration's values. If the `default:` value is left unspecified, a hardcoded default value of _"arkcase"_ will be used. The value in the `default:` field must be a valid directory configuration name (i.e. _arkcase_, in the below example).

This is the complete configuration available for LDAP services. Not all values are required - for example, it's generally sufficient to provide the URL (`global.conf.ldap.${directory}.url`), the domain specification (`global.conf.ldap.${directory}.domain`), and the bind details (`global.conf.ldap.${directory}.bind.dn` and `global.conf.ldap.${directory}.bind.password`):

```yaml
global:
  conf:
    ldap:
      default: "arkcase"
      arkcase:
        url: "ldaps://ldap:636"
        domain: "my.external-ldap.domain.com"
        # enableCreatingLdapUsers, enableEditingLdapUsers and syncEnabled default to true
        # If disabled there will be no connection between LDAP users and Arkcase users,
        # which is preferential when SSO is used and there are a lot of Arkcase users
        enableCreatingLdapUsers: "true" 
        enableEditingLdapUsers: "true"
        syncEnabled: "true"
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

In more nuanced cases you may also have to provide the baseDn (`global.conf.ldap.${directory}.baseDn`), as well as other values describing how to find users, groups, memberships, etc.  Please note that the configurations that appear to be missing a complete DN specification (i.e. like `global.conf.ldap.search.users.base` or `global.conf.ldap.search.groups.base`) are set in that manner by design, because when they're consumed while rendering configuration files, the baseDn value is appended unto them at that moment.

### User Management

ArkCase's user management features require the bind DN user to be able to create or modify users and groups. These permissions must be managed manually, or these features will not work as desired.

## <a name="external-content-store"></a>External Content Store

To configure an external content store instance, things are also a little bit different since you must provide two URLs: one for the content server API, and one for the content server UI, like so:

```yaml
global:
  conf:
    content:
      # The content store dialect to use. Minio is an alias for S3, and Alfresco is an alias for CMIS.
      # dialect: s3|minio|cmis|alfresco
      api: https://some-server.domain.com/alfresco
      ui: https://another-server.domain.com/share
      # username: "admin"
      # password: "admin's password"
      # settings:
      #   indexing: true
      #   # More settings ...
```

Specifically, and consistent with Alfresco's capabilities, the API server (i.e Alfresco Content Server) and UI server (i.e. Share) need **not** be co-located on the same server. As long as the UI instance (indicated by `ui`) is connected to the same content server URL instance (indicated by `api`), everything will work just fine.

If you want to use an external content server instance, you ***must*** set the value `global.conf.content.api` to point to the content server's API base URL. Only changing the `global.conf.content.ui` value will not be enough. You must also take care to change the `ui` setting to match the correct value to the UI instance which connects to the given content server API URL.

### <a name="external-alfresco-init"></a>Initializing an External Alfresco

Depending on the ArkCase deployment, the Alfresco content structures may vary, and thus not all permutations can be covered here. However, we can cover the default configuration supported by the charts.

ArkCase will require two sites (depending on configuration):

* ***ACM*** - (regular site) will store the primary ArkCase live content, and must contain the following folders:

  * Business Processes
  * Case Files
  * Complaints
  * Consultations
  * Document Repositories
  * Expenses
  * People
  * Recycle Bin
  * Requests
  * SAR
  * Tasks
  * Timesheets
  * User Profile

* ***RM*** - (Records Management site) will store any records flagged to be preserved, and must contain the following categories:

  * ACM
    * Case Files
    * Complaints
    * Consultations
    * Document Repositories
    * Requests
    * SAR
    * Tasks

The ArkCase application will attempt to initialize the Alfresco contents on bootup - whether internal or external -, and as such there should not be any need for manual intervention on the deployer's part. This effort will only be done once, and its success will be tracked within ArkCase's persistence areas.

As long as the configurations (URLs, usernames, passwords, etc.) are correct, everything should work out just fine. Specifically, the content seeder script will require administrative access to Alfresco, so whatever username (`global.conf.content.username`) or password (`global.conf.content.password`) are used, they must provide administrator access for the seeding process to succeed (this is particularly important for the Records Management portions).

In particular, the ArkCase initialization data may include information regarding users and groups to be added to the ***ALFRESCO\_ADMINISTRATORS*** group during initialization. As such it's important that the `username` and `password` settings permit access to an account that's already a member of that group, or any other group/role with access to add members (either users or groups) to that group.

## <a name="email"></a>E-Mail Send & Receive

ArkCase will require access to a mail relay to send e-mail, and a (set of) IMAP account(s) to receive it. To configure these, use the following configruation model:

```yaml
global:
  email:

    # E-mail sending configurations
    send:
      # Connection mode (plaintext, ssl, starttls is default)
      # connect: starttls

      # The mail relay's hostname or IP
      host: "my.mail-relay.com"

      # Only needed if using non-standard ports.
      # Both plaintext and starttls will use 25, ssl will use 465
      # port: 25

      # ArkCase currently requires e-mail authentication, so you MUST set these two
      # values to non-null, non-empty strings
      username: "my-mail-relay-user"
      password: "MyZ00p3rZe3kr1t"

      # The e-mail address to use in the From: header
      from: "noreply-arkcase@my.domain.com"

    # E-mail receiving configurations
    receive:
      # The host to pull e-mail from (will use IMAP+SSL)
      host: "my.imap.server.com"

      # The port is only needed if it's not 993
      # port: 993
```

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
