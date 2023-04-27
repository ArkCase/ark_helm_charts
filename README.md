
# [ArkCase](https://www.arkcase.com/) Helm Chart Library

***NOTE**: In a rare first, this documentation is slightly ahead of the code it covers. If something described here doesn't work with the current version of the charts, check in within a few days, and it more than likely will. These charts will remain in a constant state of flux until they reach 1.0 status, as we're using them to guide the development roadmap. Adjustments to the docs will be made if/when we find better/cleaner ways to do things on the backend.*

Welcome to the [ArkCase](https://www.arkcase.com/) Helm Chart Library!

Here's a table of contents so you can quickly reach the documentation section you're most interested in:

 - [Overview](#overview)
 - [Preparation for Deployment](#preparation)
 - [Deployment](#deployment)
   - [Development](#development)
   - [Production](#production)
 - [Configuration](#configuration)
   - [Advanced](#advanced)
   - [Licenses](#licenses)
   - [Ingress and SSL/TLS Access](#ingress)
   - [Persistence Layer](#persistence)
   - [Externally-provided Services](#external-services)
   - [Deploying Custom ArkCase Versions](#custom-arkcase)

## <a name="overview"></a>Overview

This repository houses the set of Helm charts and supporting library charts for deploying [ArkCase](https://www.arkcase.com/) in a [Kubernetes](https://kubernetes.io/) environment, running on [Linux](https://www.linux.org/) (for now, this is the only supported platform). These charts have only been tested in vanilla Kubernetes and [EKS](https://aws.amazon.com/eks/) environments. However, it's not unreasonable to expect these charts to work OOTB with other stacks such as [OpenShift](https://www.redhat.com/en/technologies/cloud-computing/openshift/kubernetes-engine), [MiniKube](https://minikube.sigs.k8s.io/docs/start/), and [K3s](https://k3s.io/).

The charts are designed to facilitate the application's deployment and configuration for (almost) any deployment environment, and are meant to facilitate the deployment of an entire, working stack in a matter of minutes.

Specifically, the stack is comprised of the following separate components, each covered by its own chart and (set of) container(s):

 - [ArkCase](https://www.arkcase.com/), the core application
 - [Solr](https://solr.apache.org/), for search services
 - [Samba](https://www.samba.org/), for [Active Directory](https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/get-started/virtual-dc/active-directory-domain-services-overview) LDAP services
 - [ActiveMQ](https://activemq.apache.org/), for message queue and pub/sub services
 - [PostgreSQL](https://www.postgresql.org/)/[MariaDB](https://mariadb.org/), for database storage (only one instance is needed)
 - [Pentaho](https://www.hitachivantara.com/en-us/products/dataops-software/data-integration-analytics.html) (for reporting services)
 - [Alfresco](https://www.alfresco.com/), for content storage services

In particular, Pentaho and Alfresco are offered in both Enterprise and Community editions. The edition deployed is automatically selected by the framework, by way of detecting the presence of the [required license data](#licenses) in the configuration at deployment time.

## <a name="preparation"></a>Preparation for Deployment

This is a very simple, high-level checklist of tasks you should complete before attempting to deploy these charts. Many of these tasks are out-of-scope, and are left as an exercise to the reader, mainly because it is covered by ample tutorial documentation easily accessible all over the internet, written by more qualified authors.

If you find challenges with any of these steps, remember: [Google](https://www.google.com/) (or [Bing](https://www.bing.com/), or [DuckDuckGo](https://duckduckgo.com/)) is your friend. If you still can't figure it out, drop us a line and we'll try to help as best we can.

Without further ado ... the steps:

 1. Deploy a Kubernetes cluster

	 *There are so many variations on how this may be accomplished that we leave it to the reader to figure out this step.*

 2. (optional, recommended) Deploy an Ingress Controller to the cluster (in our examples we will use the [HAProxy](https://haproxy-ingress.github.io/) ingress controller with minimum configuration)

 3. Install [Helm](https://helm.sh/docs/intro/install/)

 4. Add the ArkCase chart repository to Helm's repository list, like so:

        $ helm repo add arkcase https://arkcase.github.io/ark_helm_charts/
        $ helm repo update

## <a name="preparation"></a>Deployment

Before you can deploy ArkCase, it's important to understand that it can be deployed in two modes: [*production*](#production) mode, and [*development*](#development) mode. By default, if deployed with no configurations, the charts will build an application in ***development*** mode. This may change in the near future, but for now this is the default mode of operation.

The simplest way to deploy the chart is by using helm, and referencing any additional configuration files you may need (such as licenses, or other configurations):

    $ helm install arkcase arckase/arkcase-0.1.0 -f licenses.yaml -f ingress.yaml -f conf.yaml

The contents of the configuration files are discussed in the [configuration section](#configuration).

The above command will result in a deployment of pre-configured containers, interoperating with each other in order to support the included ArkCase instance. The number and types of containers may vary due to configurations. For instance: if you select to use an external LDAP service, then the Samba container will not be started. The same applies for other [external services](#external-services).

### <a name="development"></a>Development

The mode of operation mainly affects the persistence layer. In *development* mode, all persistence is handled via ***hostPath*** volumes. In development mode it's still possible to configure the persistence layer to use a combination of rendered ***hostPath*** volumes, with actual cluster-provided volumes (i.e. [GlusterFS](https://www.gluster.org/), [Ceph](https://docs.ceph.com/en/quincy/), [NFS](https://en.wikipedia.org/wiki/Network_File_System), etc). You can find more details on how to do this [in this document](docs/Persistence.md).

The intent of supporting *development* mode is to facilitate the charts' use by developers in single-cluster environments, where persistence can be provided safely by a single host. This lowers the environment bar required for a developer to get an instance up and running, for testing and development purposes.

In the near future, enabling development mode will also enable many other features related to the deployment location for the actual ArkCase WAR file, as well as the configuration directory (a.k.a.: *.arkcase*). Through these features, Developers will be able to deploy the whole stack *except* for ArkCase, and with specific configuration on their environments, make their own ArkCase instance connect to the development stack.

### <a name="production"></a>Production

In *production* mode, things become more ***real***, if you will. No hostPath volumes are rendered, and instead all generated persistence is managed via volume claim templates declared with each Pod or StatefulSet. The particulars of the persistence layer are described [here](#persistence).

To enable production mode ***explicitly***, you'll need to set this configuration value (in YAML syntax):

```yaml
# Enable production mode
global.mode: "production"
```

Production mode may also be enabled implicitly by setting a default *storageClassName* for the persistence layer, like so:

```yaml
# Enable production mode by setting a default storageClassName
global.persistence.default.storageClassName: "someStorageClassName"
```

If production mode is enabled explicitly, but a default *storageClassName* is not configured, all volume claim templates rendered will lack that stanza and thus will be expected to be provisioned by the cluster with [the default storage class](https://kubernetes.io/docs/tasks/administer-cluster/change-default-storage-class/). Specifically, it is possible to enable *development* mode explicitly even with a default *storageClassName* configured, by explicitly setting the `global.mode` configuration value to `"development"`.

Finally, you may refer to the [documentation on the persistence layer](#persistence) for more details on how to configure that particular aspect of the deployment.

## <a name="configuration"></a>Configuration

### <a name="licenses"></a>Licenses

The information on how to configure component licenses can be found [in this document](docs/Licenses.md).

### <a name="ingress"></a>Ingress and SSL/TLS Access

The information on how to configure the ingress, and the SSL/TLS certificates for secure access can be found [in this document](docs/Ingress.md).

### <a name="persistence"></a>Persistence

The information on how to configure the persistence layer can be found [in this document](docs/Persistence.md).

### <a name="external-services"></a>External Services

The information on how to configure the stack to consume services provided by external components (i.e. an external database, an external AD instance, etc.) can be found [in this document](docs/External_Services.md).

### <a name="custom-arkcase"></a>Deploying Custom ArkCase Versions

The information on how to deploy your custom ArkCase version with this stack can be found [in this document](docs/Custom_Arkcase.md).
