
# [ArkCase](https://www.arkcase.com/) Helm Chart Library

Welcome to the [ArkCase](https://www.arkcase.com/) Helm Chart Library!

<a name="toc"></a>Here's a table of contents so you can quickly reach the documentation section you're most interested in:

 - [Overview](#overview)
 - [Preparation for Deployment](#preparation)
 - [Deployment](#deployment)
 - [Security](#security)
 - Configuration
   - [Licenses](docs/Licenses.md)
   - [Service Type Overrides](docs/Service_Overrides.md)
   - [Ingress and SSL/TLS Access](docs/Ingress.md)
   - [Persistence Layer](docs/Persistence.md)
   - [Externally-provided Services](docs/External_Services.md)
   - [Deploying Custom ArkCase Versions](docs/Custom_Arkcase.md)
   - [Development](docs/Development.md)
   - [Resource Requests and Limits](docs/Resources.md)
   - [Clustering](docs/Clustering.md)

## <a name="overview"></a>Overview

This repository houses the set of Helm charts and supporting library charts for deploying [ArkCase](https://www.arkcase.com/) in a [Kubernetes](https://kubernetes.io/) environment, running on [Linux](https://www.linux.org/) (for now, this is the only supported platform). These charts have only been tested in vanilla Kubernetes, [Rancher Desktop](https://arkcase.github.io/ark_helm_charts/) and [EKS](https://aws.amazon.com/eks/) environments. However, it's not unreasonable to expect these charts to work OOTB with other stacks such as [OpenShift](https://www.redhat.com/en/technologies/cloud-computing/openshift/kubernetes-engine), [MiniKube](https://minikube.sigs.k8s.io/docs/start/), and [K3s](https://k3s.io/) or [K3d](https://k3d.io/).

The charts are designed to facilitate the application's deployment and configuration for (almost) any deployment environment, and are meant to facilitate the deployment of an entire, working stack in a matter of minutes.

Specifically, the stack is comprised of the following separate components, each covered by its own chart and (set of) container(s):

 - [ArkCase](https://www.arkcase.com/), the core application
 - [Solr](https://solr.apache.org/), for search services
 - [Samba](https://www.samba.org/), for [Active Directory](https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/get-started/virtual-dc/active-directory-domain-services-overview) LDAP services
 - [ActiveMQ](https://activemq.apache.org/), for message queue and pub/sub services
 - [PostgreSQL](https://www.postgresql.org/)/[MariaDB](https://mariadb.org/), for database storage (only one instance is needed)
 - [Pentaho](https://www.hitachivantara.com/en-us/products/dataops-software/data-integration-analytics.html) (for reporting services)
 - [Alfresco](https://www.alfresco.com/), for content storage services

In particular, Pentaho and Alfresco are offered in both Enterprise and Community editions. The edition deployed is automatically selected by the framework, by way of detecting the presence of the [required license data](docs/Licenses.md) in the configuration at deployment time.

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

***NOTE:** production mode and development mode no longer exist. The chart now has a single, unique deployment mode: *production*.**

The simplest way to deploy the chart is by using helm, and referencing any additional configuration files you may need (such as licenses, or other configurations):

    $ helm install arkcase arkcase/app -f licenses.yaml -f ingress.yaml -f conf.yaml

The contents of the configuration files are discussed in depth in other documents. Look through the [table of contents](#toc) to find what you're looking for.

The above command will result in a deployment of pre-configured containers, interoperating with each other in order to support the included ArkCase instance. The number and types of containers may vary due to configurations. For instance: if you select to use an external LDAP service, then the Samba container will not be started. The same applies for other [external services](docs/External_Services.md).

## <a name="security"></a>Security

Due to the highly varied nature of the security requriements each deployer may choose to require or enforce, it's impossiblte to anticipate and support them beyond granting the ability to run (portions of) the stack under service accounts. This helm chart supports the following syntax for indicating service account usage:

```yaml

global:
  security:
    # This service account will be used for all pods and components
    serviceAccountName: "arkcase-service-account"
```

You can also specify the value using `--set global.security.serviceAccountName=arkcase-service-account` at deploy time as part of the `helm` command.

Finally, this chart currently doesn't support individualized service accounts for each component because no such requirement has been identified. This is not, however, out of the question should a solid use-case for this functionality be discovered.
