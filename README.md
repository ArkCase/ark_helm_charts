# [ArkCase](https://www.arkcase.com/) Helm Chart Library

Welcome to the [ArkCase](https://www.arkcase.com/) Helm Chart Library!

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
 - [Tika](https://tika.apache.org/), for document metadata and text extraction services

In particular, Pentaho and Alfresco are offered in both Enterprise and Community editions. The edition deployed is automatically selected by the framework, by way of detecting the presence of the [required license data](#licenses) in the configuration at deployment time.

Further documentation on development, configuration, and deployment can be found [here](repo/README.md) and [here](https://arkcase.github.io/ark_helm_charts/).
