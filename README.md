# Containers overview

The following sections help you to understand what containerized deployment is, and the deployment options available for Arkcase when using containers.

## Deployment concepts

In addition to the standard deployment methods for non-containerized deployment, Arkcase provides case management packaged in the form of Docker containers, for companies who choose to use containerized and orchestrated deployment tools. While this is a much more advanced approach to deployment, it is expected that customers who choose this approach have the necessary skills to manage its complexity.

You can start Arkcase from a number of Docker images. These images are available in the Amazon Elastic Container Registery (ECR). However, starting individual Docker containers based on these images, and configuring them to work together can be complicated. To make things easier, a **Helm Chart**  is available to quickly start Arkcase.  These charts are a deployment template which can be used as the basis for your specific deployment needs. 

The following is a list of concepts and technologies that you'll need to understand as part of deploying and using Content Services. If you know all about Docker, then you can skip this part.

### Virtual Machine Monitor (Hypervisor)

A Hypervisor is used to run other OS instances on your local host machine. Typically it's used to run a different OS on your machine, such as Windows on a Mac. When you run another OS on your host it is called a guest OS, and it runs in a Virtual Machine (VM).

### Image

An image is a number of layers that can be used to instantiate a container. This could be, for example, Java and Apache Tomcat. You can find all kinds of Docker images on the public repository [Docker Hub](https://hub.docker.com/){:target="_blank"}. There are also private image repositories (for things like commercial enterprise images), such as the one Arkcase uses called Amazon ECR.

### Container

An instance of an image is called a container. If you start this image, you have a running container of this image. You can have many running containers of the same image.

### Docker

Docker is one of the most popular container platforms. [Docker](https://www.docker.com/) provides functionality for deploying and running applications in containers based on images.

### Docker Compose

When you have many containers making up your solution, such as with Content Services, and you need to configure each individual container so that they all work well together, then you need a tool for this. Docker Compose is such a tool for defining and running multi-container Docker applications locally. With Compose, you use a [YAML](https://en.wikipedia.org/wiki/YAML) file to configure your application's services. Then, with a single command, you create and start all the services from your configuration.

### Dockerfile

A **Dockerfile** is a script containing a successive series of instructions, directions, and commands which are run to form a new Docker image. Each command translates to a new layer in the image, forming the end product. The Dockerfile replaces the process of doing everything manually and repeatedly. When a Dockerfile finishes building, the end result is a new image, which you can use to start a new Docker container.

### Difference between containers and virtual machines

It's important to understand the difference between using containers and using VMs. Here's a comparison from the Docker site - [What is a Container](https://www.docker.com/resources/what-container):

The main difference is that when you run a container, you are not starting a complete new OS instance. This makes containers much more lightweight and quicker to start. A container also takes up much less space on your hard-disk as it doesn't have to ship the whole OS.

## Arkcase Docker images
The Arkcase Docker images are available in the Amazon Elastic Container Registry (ECR). 

The following Docker images relate to Arkcase:
* https://github.com/arkcase/ark_arkcase_core - Case Management Core Product (Arkcase)
* https://github.com/ArkCase/ark_cloudconfig - Configuration Server
* https://github.com/ArkCase/ark_pentaho_ee - Reporting Server
* https://github.com/ArkCase/ark_activemq - Messaging Server
* https://github.com/ArkCase/ark_snowbound - Viewer Server
* https://github.com/ArkCase/ark_solr - Search Server

Additional Docker images that may or may not be part of your deployment:
* https://github.com/ArkCase/ark_samba - Lightweight Directory Access Protocal (LDAP) Server
* https://github.com/ArkCase/ark_postgres - PostgreSQL Database Server
* https://github.com/ArkCase/ark_mariadb - MariaDB (MySQL) Database Server
* https://github.com/ArkCase/ark_gateway_apache - Reverse Proxy
 
Diagnostics and Bootstrap Docker images:
* https://github.com/ArkCase/ark_nettest - network testing tools out-of-the-box
* https://github.com/ArkCase/ark_dbinit - mechanism to render DB initialization files which can then be consumed by a database container
* ark_common - common framework of utlity tools including provisioning PVCs

## What's deployed in Arkcase Helm Chart

When you deploy Content Services, a number of containers are started.

* Case Management (Arkcase):
  * Configuration Server
  * Reporting Server
  * Messaging Server
  * Viewer Server
  * Search Server
* PostgreSQL Database Server
* DB initialization 

## Prerequisites

If you are deploying only a portion of the stack to Kubernetes, please verify the combation of Virtual Machine based infrastructure and products are compatable with the Container based containers with Arkcase Support Team.

### Helm charts

To deploy Content Services using Helm charts, you need to install the following software:

* [AWS CLI](https://github.com/aws/aws-cli#installation) - the command line interface for Amazon Web Services.
* [Kubectl](https://kubernetes.io/docs/tasks/tools/) - the command line tool for Kubernetes.
* [Helm](https://github.com/helm/helm#install) - the tool for installing and managing Kubernetes applications.
  * There are Helm charts that allow you to deploy Content Services in a Kubernetes cluster, for example, on AWS.

# Install using Helm

Arkcase provides tested Helm charts as a "deployment template" for customers who want to take advantage of the container orchestration benefits of Kubernetes. These Helm charts are undergoing continual development and improvement, and shouldn't be used "as is" for your production environments, but should help you save time and effort deploying Content Services for your organization.

The Helm charts in this repository provide a PostgreSQL database in a Docker container and don't configure any logging. This design was chosen so that you can install them in a Kubernetes cluster without changes, and they're flexible enough for adopting to your actual environment.

You should use these charts in your environment only as a starting point, and modify them so that Content Services integrates into your infrastructure. You typically want to remove the PostgreSQL container, and connect directly to your database (this might require custom images to get the required JDBC driver in the container).

Another typical change is the integration of your company-wide monitoring and logging tools.

## Customize

To customize the Helm deployment, for example applying AMPs, we recommend following the best practice of creating your own custom Docker image(s). The following customization guidelines walk you through this process.

Any customizations (including major configuration changes) should be done inside the Docker image, resulting in the creation of a new image with a new tag. This approach allows changes to be tracked in the source code (Dockerfile) and rolling updates to the deployment in the Kubernetes cluster.

The Helm chart configuration customization should only include environment-specific changes (for example DB server connection properties) or altered Docker image names and tags. The configuration changes applied via `--set` will only be reflected in the configuration stored in Kubernetes cluster, a better approach would be to have those in source control i.e. maintain your own values files.

## Using custom Docker images

Once you've created your custom image, you can either change the default values in the appropriate values file in the HELM Chart, or you can override the values via the `--set` command-line option during the install:

## DNS

1. Create a FQDN Arkcase will utilize

2. Create a public certificate for the hosted services. 

3. Update the .Arkcase configuration bundle

4. Configure Ingress Controller if necessary

5. Customize Helm Chart if necessary

6. Install Helm Chart

## .Arkcase 

.Arkcase is a configuration bundle for Case Management application

## HELM Configuration options

Parameters bundled in helm are most infrastructure parameters, with the larger configuration bundled within the .Arkcase bundle.

| Parameter | Description |
| --------- | ----------- |
| parameter1 | description
| parameter2 | description
| parameter3 | description
| parameter4 | description
| parameter5 | description


## Troubleshooting

Here's some help for diagnosing and resolving any issues you may encounter.
