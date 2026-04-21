# Clustering and High Availability for [ArkCase](https://www.arkcase.com/)

## Table of Contents

* [Introduction](#introduction)
* [Component Overview](#component-overview)
* [Configuration](#configuration)
* [Component Details](#component-details)
    * [ArkCase](#arkcase)
    * [Artemis](#artemis)
    * [Artifacts](#artifacts)
    * [Pentaho](#pentaho)
    * [Proxy](#proxy)
    * [Solr](#solr)
    * [ZooKeeper](#zookeeper)
* [Non-Clustered Component Details](#non-clustered-details)

## <a name="introduction"></a>Introduction

This document describes how to enable and configure clustering when deploying ArkCase using these Helm charts. As with any community-release project, Issues and PRs are always welcome to help move this code further along.

Clustering in ArkCase is handled pragmatically: there are some components for which it makes little sense to implement sophisticated rendering logic in order to support a clustering scenario, when the same service can be [consumed from an external provider](External_Services.md) which offers a much more robust and proven platform from which to consume that service. For other components where that is either not possible, sensible, of for which achieving a highly-available configuration is relatively simple, these Helm charts do support it.  This document describes both scenarios: which components may be clustered (and how), as well as which components are not (and why).

Importantly, for the time being, ***ArkCase itself does not support being deployed as a multi-replica cluster***. Unfortunately, at this time there are many changes required in order to make this possible due to the application's architecture, implementation, and deployment design.

Finally, **almost none of the clustering implementations described herein supports dynamic replica scaling**. Any change in the number of replicas deployed for a given component ***necessarily requires a new deployment*** (or an in-place deployment update). In addition, you must also take care to ensure that no data loss/data gaps occurr as a result of the re-scaling. Notably, <a href="#solr">Solr</a> can be problematic when you rescale it.  The one exception for dynamic deployment is the Artifacts container, because it's a read-only service.

In particular: ***you may not manually (or otherwise) modify the number of replicas at runtime WITHOUT executing a deployment (update or redeployment), and then act surprised when weird things start happening and data start getting lost.***

## <a name="component-overview"></a>Component Overview

A typical, *"OOTB"* ArkCase Helm deployment with clustering enabled will include the following components:

* Alfresco or Minio : file content store
* ArkCase : the main application
* Artemis (ActiveMQ) : OpenWire Messaging and STOMP support
* HAProxy : for stateful session tracking (i.e. `JSESSIONID`)
* Pentaho : reporting and datawarehousing
* Samba : LDAP (AD) authentication
* Solr : search and indexing
* SQL Database : data storage
* Step-CA : SSL certificate management
* ZooKeeper : clustered component synchronization and shared state management

## <a name="configuration"></a>Configuration

The difficulty level of supporting a simple, configurable, and robust clustering deployment for the above components varies wildly. For some it's a very simple issue due to their internal architecture. For others, it can be very challenging, and a significant effort all its own. As a result, these Helm charts only support clustering for the following components:

* [ArkCase](#arkcase)
* [Artemis](#artemis)
* [Artifacts](#artifacts)
* [Pentaho](#pentaho)
* [Proxy](#proxy)
* [Solr](#solr)
* [ZooKeeper](#zookeeper)

***No other components support clustering at this time.***

The general model for clustering configuration follows a similar trend as with other configurations:

```yaml
global:
  cluster:

    # Enable single-replica clusters (useful for development and debugging)
    # single: true

    # ArkCase
    core:
      onePerHost: false
      replicas: 3

    # Artemis
    messaging:
      onePerHost: false
      replicas: 2

    # Artifacts
    app-artifacts:
      onePerHost: false
      replicas: 4

    # Pentaho
    reports:
      onePerHost: false
      replicas: 3

    # Proxy
    app-proxy:
      onePerHost: false
      replicas: 2

    # Solr
    search:
      onePerHost: false
      replicas: 8

    # ZooKeeper
    zookeeper:
      onePerHost: false
      replicas: 5
```

The general model follows this approach:

```yaml
global:
  cluster:
    ${component-name}:
      # single: true
      replicas: 2
      resources:
      #  ...
```

Here's a breakdown of what each configuration value means:

* **single** : enable (`true`) or disable (`false`) single-replica clustering for that component (i.e. the replica count on deployment will always be 1). If the value is not provided, it will default to `false`. This is very useful for conserving resources on local developer deployments, and for debugging tricky issues such that the multi-replica factor can be removed from the equation.
* **onePerHost** : set a `podAntiAffinity` policy that prefers (`false`) not scheduling two replicas of the same pod on the same cluster worker replica (by hostname), but will allow it to happen if unavoidable in order to satisfy the requisite number of replicas, vs. one that flat out forbids it (`true`) and will not schedule any pods that would violate that affinity rule.
* **replicas** : the number of replicas that this component should use for its deployment. Some components ignore this value due to the chosen clustering strategy, while others may use it as the basis for computing the *actual* number of replicas required.
* **resources** : the resource allocations to grant to each Pod replica when clustering is enabled, following the same syntax as described [in this document](Resources.md).

## <a name="component-details"></a>Component Details

Each component implements clustering differently, due to different factors. This section describes those nuances to provide more context regarding the current implementation, as well as helping inform your decisions when planning out a clustered ArkCase deployment.

### <a name="arkcase"></a>ArkCase

ArkCase supports multi-replica clustering. The ArkCase clustering solution is limited to 4 replicas, since replica counts above that require additional considerations for session sharing, and other synchronization overhead issues.

#### Rescaling

You may rescale ArkCase after deployment by altering the replica count. ***Do not scale it beyond 4 replicas unless you understand the consequences***

### <a name="artemis"></a>Artemis

Artemis supports clustering in [many different configurations](https://activemq.apache.org/components/artemis/documentation/latest/ha.html).  The configuration supported by these charts is for either single-replica (no HA) or Primary-Backup pair only (for HA).

Primary-Backup clustering works by having one replica be ***active***, while another replica is in ***passive*** mode, shadowing its operations and ready to pounce the moment it detects that the live server has gone down. At that point, the passive replica becomes the ***active*** replica. When the original replica comes back up, it will now assume the ***passive*** role until the current ***live*** replica fails (or is taken offline), and so on.

The single-pair primary-backup configuration for clustering offers sufficient guarantees regarding possible message loss to be acceptable for HA purposes.

Notably, none of the other configuration models Artemis supports provide any stronger guarantees against message loss in the event of a crash. For example: It's possible to deploy many, many primary-backup pairs of Artemis replicas as part of a larger cluster, providing both horizontal scaling for througput, and high-availabiliy for reliability. However, this approach offers no guarantees that a message being processed by a pair of replicas, which then proceed to crash, will not be lost.  Since multiple Primary-Backup pairs offers no additional protections against message loss, there's little benefit to be gained from running multiple Primary-Backup pairs.

Thus, the cluster configuration these charts render only supports up to two replicas: the primary, and the backup.

#### Rescaling

You may safely rescale Artemis between 1 or 2 replicas at any time. Scaling beyond 2 replicas will only result in the additional replicas entering ***passive*** mode without any guarantees they will ever be used.

### <a name="artifacts"></a>Artifacts

The Artifacts component is generally a stateless, read-only server.

#### Rescaling

You may rescale the Artifacts component at any time, and by any means you wish, without requiring a re-deployment. Take care not to scale it to 0 as this may disrupt the application's ability to recover some components which require access to the artifacts it serves up.

### <a name="pentaho"></a>Pentaho

Pentaho supports multi-replica clustering. The Pentaho clustering solution is limited to 4 replicas, since replica counts above that require additional considerations for session sharing, and other synchronization overhead issues.

#### Rescaling

You may rescale Pentaho after deployment by altering the replica count. ***Do not scale it beyond 4 replicas unless you understand the consequences***

### <a name="Proxy"></a>Proxy

The Proxy component is a pre-configured HAProxy instance whose sole purpose is to support session cookie tracking (i.e. `JSESSIONID`) for ArkCase and Pentaho. By default it will deploy 2 replicas in high-availability mode, which should be more than enough for most deployments.

#### Rescaling

You may rescale the Proxy after deployment by altering the replica count. When increasing the replica count, the older replicas must be re-started so they may discover the newly-added ones.

### <a name="solr"></a>Solr

Solr supports both clustering, and subsequent sharding (partitioning).  For these charts, both are supported. Solr is perhaps the component that has the most flexible clustering support in this suite.  By default, the number of replicas does not affect the number of shards (1 shard per replica). In the near future this will be able to be modified.

The "replica loss" restriction is governed by a `PodDisruptionBudget`.

#### Rescaling

You may NOT rescale Solr after deployment, unless you intend to clear out and re-build the indexes from scratch. This is because of the replica support discussed above: it's impossible to anticipate *which* replicas will house *which* replicas. As a result, if you scale down too aggressively, you may inadvertently destroy all replicas of (one or more) shard(s). So take your time, and plan out the number of Solr replicas in advance. If you end up needing more replicas later on, you are probably also well-served performing a full re-index of the data (and perhaps also the document content, if applicable), to further bolster performance. As a result, it makes more sense for you to nuke your old indexes as part of the Solr re-scaling effort.

Regardless, re-scaling may only happen as a result of a deployment (update or re-deployment).

### <a name="zookeeper"></a>ZooKeeper

ZooKeeper is, by its very nature, cluster-aware.  The current clustering strategy allows for dynamic cluster growth. The deployment will ensure that an odd number of replicas are deployed at any time. Whether the operators choose to scale the ZooKeeper instance to an even number later is beyond the chart's control. More importantly, ZooKeeper quorum rules will apply here.

ZooKeeper can get very heavy, very quickly. It's generally not recommended (or necessary!) to have very many replicas. In general, for medium-large environments you will rarely need more than `3` or `5` replicas.  For super-large environments you *may* need `7` or even `9`. However, once you start going with that large number of replicas, synchronization overhead needs to be accounted for, and more sophisticated configuration and data partitioning is required in order for ZooKeeper to function efficiently. Thus, if you find yourself requiring something that large, it's generally a better idea to find a hosted solution that will better cover your needs.  That said, this chart allows (for testing purposes) up to 255 replicas to be configured for ZooKeeper, which is the maximum allowed for a cluster.

Similarly, the number of replicas will dictate the number of acceptable failures before the cluster is deemed inoperable, and taken offline by the K8s Cluster. This is governed by a `PodDisruptionBudget` object which will allow up to `half - 1` replicas to go offline and still keeping the cluster operational.  So, for instance, if you deploy a `5` replica cluster, you can "lose" (i.e. experience crashes) up to `2` replicas before the cluster becomes inoperable. This math comes directly from ZooKeeper's requirements to always have at least half of your replicas available.

This configuration is done automatically as part of the clustering scenario.

#### Rescaling

You may safely rescale ZooKeeper up or down at runtime, but it is strongly recommended that the number of replicas always be an odd number.

## <a name="non-clustered-details"></a>Non-Clustered Component Details

As discussed above, there are some components for which the complexity of implementing a robust clustering solution makes it not worth while pursuing as part of this effort. As a result, the following components cannot be clustered using these Helm charts:

* Samba

  Samba provides an AD-compatible LDAP implementation which is used by many components (ArkCase, Pentaho, Alfresco). The selection of using Samba for these charts hinges around simplicity of deployment and sufficiency of service. It's enough for most simple deployments, and unless your production environment *requires* an HA setup, it's also robust enough to be trusted for most simpler setups.
  
  Regardless, clustering an AD deployment ***of any kind*** is "its own course in Microsoft University", to put it mildly. As a result, if your deployment ***requires*** (either technically or contractually) a highly-available, and/or highly-performant AD implementation, we strongly recommend consider you consider other alternatives which provide a robust implementation of just such a solution, like [Microsoft Entra (formerly Azure AD)](https://learn.microsoft.com/en-us/entra/), or [AWS Directory Service](https://aws.amazon.com/directoryservice/).

* SQL Database

  The SQL Database flavors supported by these Helm charts are MariaDB 10.6 and PostgreSQL 13.  Although both can be deployed into simple clusters, it was determined that this would offer a false sense of security in what is arguably the most critical component of the entire deployment - the one that ***cannot*** fail, the one that ***cannot*** break.  As a result, providing the ability to deploy a small, simplistic cluster with either of those offerings would result in little more than a placebo.

  Therefore, if your deployment ***requires*** (either technically or contractually) a highly-available, and/or highly-performant SQL Database implementation, we strongly recommend you consider other alternatives which provide a robust implementation, such as [Amazon RDS](https://aws.amazon.com/rds/), [Azure DB for PostgreSQL](https://azure.microsoft.com/en-us/products/postgresql/), or [Azure DB for MariaDB](https://azure.microsoft.com/en-us/products/mariadb/), or [Azure DB for MySQL](https://azure.microsoft.com/en-us/products/mysql/).

* Alfresco

  Alfresco provides document storage for ArkCase, and is the second most important component in the entire stack due to the critical nature of the data it houses. Clustering Alfresco can be quite challenging, and the variations that are possible when looking to achieve this are mind-numbing, to say the least. Attempting to minimize the complexity therein would result in a cluster deployment that would be litte more than a placebo.

  Therefore, if your deployment ***requires*** (either technically or contractually) a highly-available, and/or highly-performant Alfresco instance, we strongly recommend you contact your Alfresco vendor, and request a consultation for the purposes of identifying an Alfresco Partner that might be able to help you meet this requirement.

* Step-CA

  Step-CA provides CA services to the cluster, allowing each pod to obtain its own SSL certificates which in turn allows the entire cluster to communicate securely at all times, with full trust. At this time, and due to the fact that Step-CA is so robust, simple, and requires so few resources, it makes no sense to attempt to cluster the deployment.  In particular, Step-CA is only required during certain container bootup operations. During normal operations, it's generally silent, without receiving traffic. Therefore, the urgency of clustering this component is simply not there yet.

  Should the CA's data be lost or destroyed, the solution would be to re-boot the deployment, as this will cause the data to be re-generated, new certificates (and trusts) to be issued, and then all would be right with the world once more, transparently and automatically. In fact, it's actually desirable to destroy the CA data and induce a reboot of all the pods periodically, just to ensure that certificate security is maintained.