# [ArkCase](https://www.arkcase.com/) Services Configuration

## Table of Contents

* [Introduction](#introduction)
* [General Use Pattern](#general-pattern)
    * [Passwords and rotation](#passwords-and-rotation)
* [Subsystem Configurations](#subsystem-configurations)
    * [ACME](#secret-acme)
    * [Application Artifacts](#secret-app)
    * [Content](#secret-content)
    * [LDAP](#secret-ldap)
    * [Messaging](#secret-messaging)
    * [Database](#secret-rdbms)
    * [Reports](#secret-reports)
    * [Search](#secret-search)
    * [Zookeeper](#secret-zookeeper)
* [E-mail Send & Receive](#email)
* [SSL/TLS Considerations](#ssl)

## <a name="introduction"></a>Introduction

This document describes how to configure the an ArkCase deployment built with these helm charts to interface with services provided externally. Essentially every service that can be deployed as part of this stack, can be provided externally, except for ArkCase itself.

In almost all cases, along with an external URL or hostname+port combination, you must also provide additional configurations like usernames, passwords, etc.  In particular, the connectivity details for every single subsystem are expected to be housed in Kubernetes Secrets - either rendered and provided by the Helm deployment itself as part of its duties, or provided by external means.

As with any community-release project, Issues and PRs are always welcome to help move this code further along.

## <a name="general-pattern"></a>General Pattern

In general, the Helm chart needs to be told which secret(s) describe the access and connectivity information for each **subsystem** (i.e. _service_)that is to be consumed from an external source. This preserves security while allowing the application access to those configurations at runtime.  The presence of such a secret specification will be interpreted by the chart as a desire by the deployer to avoid instantiating the associated, bundled-in **subsystem** in favor of an externally-provided one.

***NOTE**: if you opt for this approach, the responsiblity falls to you to properly provision, configure, and initialize said systems __before__ you boot up ArkCase to interface with them. ArkCase will only make a _best effort_ attempt to wait for those services to come online by way of TCP connectivity tests. If this type of check is insufficient, then you must provide the means to delay ArkCase bootup until those services are available for its consumption.*

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

### <a name="passwords-and-rotation"></a>Passwords and Rotation

For every subsystem deployed by the Helm chart, a new, random password will be generated every time a deployment is executed from scratch. The containers and Helm chart contain all the necessary code and configurations to allow for new passwords to be renderd on every ***new*** deployment (i.e. `helm install`), while re-using any existing passwords on every in-place ***upgrade*** (i.e. `helm upgrade`).

These credentials are available in the Secrets generated by the chart. If these Secrets are generated by another means because the subsystem is being provisioned externally (i.e. Amazon RDS, etc.), then no rotation will happen unless the entities managing those resources perform it.

As a result, to rotate the passwords for the integrated service accounts deployed as part of ArkCase, all a administrator needs to do is un-deploy the application, and re-deploy it (even with identical values as before!).  This will result in brand new passwords being generated for every single service account that the ArkCase deployment provisioned directly.  Therefore, the frequency of password rotations for security is entirely up to the deployer's discretion.


## <a name="subsystem-configurations"></a>Subsystem Configurations

As seen above, the subsystem configuration can supply details on how to consume them from external sources, as well as specific configurations that are independent of where those services are consumed from. This section describes these settings with examples.

Every ArkCase subsystem that consumes services from other subsystems must consume a specific, immutable set of configuration ***values*** that it needs in order to achieve interaction. _Where these values are stored and consumed from may vary_, but the _set of values proper_ may not. This listing describes the structure that those secrets are expected to follow, and thus how the other subsystems will consume them.  In the following descriptions, you may see placeholders such as `${release}`, `${subsys}`, and `${connection}` - these can be interpreted as follows:

- `${release}` == the name of the release, as used during `helm install RELEASE ...`
- `${subsys}` == the name of the subsystem being described
- `${connection}` == the name of the connection being described

Externally-provided secrets may provide the correct values, but not always under the expected names. This is what the `mappings:` sections, shown above, seek to address. Don't worry if your source secret doesn't match the expected secret perfectly in terms of keys - the important thing is that the ***VALUES*** must match what's expected.

Finally, the ***default*** names for the configuration secrets for ***any*** connection follow this pattern: `${release}-${subsys}-${connection}`. This means that for the subsystem "ldap" in the release "arkcase", the connection named "portal" would be described by the secret `arkcase-ldap-portal`. For example:

- `arkcase-ldap-main` (release name == `arkcase`)
- `new-foia-rdbms-content` (release name == `new-foia`)
- `confidential-messaging-arkcase` (release name == `confidential`)
- and so on...

### <a name="secret-acme"></a>ACME (SSL certificate generation)

The [ACME](https://en.wikipedia.org/wiki/Automatic_Certificate_Management_Environment) component is meant to provide a simple, self-contained PKI infrastructure for disposable, yet trustworthy certificates for the ArkCase application. The certificates aren't meant to be exported to other services, nor consumed by outside participants. These certificates exists solely for the purpose of deploying end-to-end SSL for ***all*** subsystems in such a manner that trust can be easily managed automatically with zero user intervention. The current implementation relies on Step-CA's proprietary protocols, so the use of "ACME" is a bit of a misnomer. That said, given the correct values, there's no reason an ArkCase deployment can't consume certificates from an externally-hosted Step-CA instance.

- Subsystem Name: `acme`

- Settings:
    - _n/a_

- Connections:
    - `main`:
        - `url`: The URL where the Step-CA service is running (e.g. `https://step-ca.server.com:9000`)
        - `password`: The password with which certificates may be obtained from the server (may not be the empty string)

- Default Secret Names:

### <a name="secret-app"></a>Application Artifacts

The Application Artifacts subsystem houses all the necessary application artifacts for the execution of a single, specific deployment of ArkCase. All the artifacts contained within can be thought of as tightly correlated: the version of ArkCase closely matches the version of the Portal (where applicable), and the version of the FOIA reports, etc. Technically speaking this *can* be hosted externally, but there is generally no need to do so.

- Subsystem Name: `app`

- Settings:
    - _n/a_

- Connections:
    - `main`:
        - `url`: The URL where the application artifacts may be downloaded from (e.g. `https://artifacts-server.domain.com:8443/artifacts`)

### <a name="secret-content"></a>Content Storage (Alfresco or S3/Minio)

ArkCase requires a place to store the documents that are uploaded to into it by end-users. Two types of content stores are supported: S3-compatible (i.e. [Minio](https://min.io/), [Amazon S3](https://aws.amazon.com/s3/), etc.) or [Alfresco](https://www.hyland.com/en/products/alfresco-platform).

***NOTE:** ArkCase requires administrative privileges in its target content store, in its target storage areas, so that it can freely create and configure them as necessary.*

- Subsystem Name: `content`

- Settings:
    - `dialect`: the content store engine's dialect - must be one of `alfresco`, `cmis` (an alias for `alfresco`), `s3`, `minio` (an alias for `s3`), or `box`. If this value is not provided, the default dialect is `s3`.

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

***NOTE:** if you wish to connect directly with Amazon S3, use the URL `https://s3.amazonaws.com` in your secrets*

### <a name="secret-ldap"></a>LDAP (Samba in Active Directory mode)

***NOTE:** ArkCase currently has an issue with regards to user and group authentication which causes [authentications to fail on case mismatch](https://arkcase.atlassian.net/jira/software/projects/ADS/issues/ADS-2353). Until that ticket is resolved, specific values listed below must be treated as case-sensitive where expressly specified.*

ArkCase utilizes LDAP as a user and group database, and leverages the underlying authentication mechanisms. ArkCase requires either one or two LDAP trees: one for base ArkCase (known as `arkcase`), and one for the Portal offering (known as `portal`). The default deployment sees both directories deployed within the same Samba instance. This need not be the case when consuming them from an external source.

- Subsystem Name: `ldap`

- Settings:

    - Common:
        - `create`: a boolean flag which controls whether user creation is enabled
        - `edit`: a boolean flag which controls whether user edition is enabled
        - `sync`: a boolean flag which controls whether LDAP sync is enabled
        - `domain`: the LDAP domain for all LDAP trees, ***in lowercase*** (e.g. `some.example.com`, only applicable when deploying the included LDAP directory)

    - ArkCase Tree:
        - `arkcase.create`: a boolean flag which controls whether user creation is enabled for the ArkCase LDAP tree
        - `arkcase.edit`: a boolean flag which controls whether user edition is enabled for the ArkCase LDAP tree
        - `arkcase.sync`: a boolean flag which controls whether LDAP sync is enabled for the ArkCase LDAP tree

    - Portal Tree:
        - `portal.create`: a boolean flag which controls whether user creation is enabled for the Portal LDAP tree
        - `portal.edit`: a boolean flag which controls whether user edition is enabled for the Portal LDAP tree
        - `portal.sync`: a boolean flag which controls whether LDAP sync is enabled for the Portal LDAP tree

- Connections:

    - `main`: (services the `arkcase` LDAP tree)
        - `url`: The LDAP URL to connect to (must be `ldaps://...`)
        - `username`: The username to use when connecting to the URL (will be appended to the realm, like so: `${REALM}\${USERNAME}`)
        - `password`: The password to authenticate with
        - `domain`: the LDAP domain for this LDAP directory, ***in lowercase*** (e.g. `some.example.com`)
        - `realm`: the LDAP realm for this LDAP directory, ***in UPPERCASE*** (e.g. `SOME`)
        - `rootDn`: the LDAP root DN for this LDAP directory, ***in UPPERCASE*** (e.g. `DC=SOME,DC=EXAMPLE,DC=COM`)
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
    - `dialect`: The database dialect to use. Must be either `mariadb` (aliased as `mysql`), or `postgresql` (aliased as `psql` or `postgres`). If this value is not provided, the default dialect is `postgresql`.

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

The secret structure for the RDBMS connections is almost identical to the secrets generated when provisioning an RDS instance (or a `Database` resource using the [CrossPlane SQL Provider](https://github.com/crossplane-contrib/provider-sql)), with the addition of two fields: `database` and `schema`.  Since the RDS provisioning supports adding the connectivity details into an existing secret, it's OK to render these secrets ahead of time with thhese known bits of information for those fields already set.

### <a name="secret-reports"></a>Reports (Pentaho 9.4.0.0)

ArkCase makes use of Pentaho to generate reports and in some deployments populate DataWarehousing tables and cubes that are used for some advanced reporting features.

***NOTE:** ArkCase requires administrative privileges in its target Pentaho tenant because it needs to support the ability to add, modify, and remove reports at runtime.*

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

      # SMTP Authentication is optional, in case you want to deploy
      # a locally-isolated SMTP relay for use by ArkCase. But if
      # you wish to use SMTP authentication, you must set BOTH of
      # these values to non-null, non-empty strings
      # username: "my-mail-relay-user"
      # password: "MyZ00p3rZe3kr1t"

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

    # A string of the form [serverName@]hostName:port[/tls-protocol], which will be queried
    # using openssl s_client to obtain the offered certificates, and any CA certificates
    # returned will be added to the trust.
    - psql.service.com@10.35.4.32:3434

    # You MUST specify the TLS protocol to use if the service in question requires TLS,
    # instead of hosting a direct SSL connection.
    - mysql.service.com@10.35.4.35:3434/mysql
```

You can add any number of certificates or pointers/URLs to certificates here. Only CA certificates (`basicConstraints.CA=TRUE`) will be added to the trust stores.
