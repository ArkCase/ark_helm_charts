## Containers overview

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

Docker is one of the most popular container platforms. [Docker](https://www.docker.com/){:target="_blank"} provides functionality for deploying and running applications in containers based on images.

### Docker Compose

When you have many containers making up your solution, such as with Content Services, and you need to configure each individual container so that they all work well together, then you need a tool for this. Docker Compose is such a tool for defining and running multi-container Docker applications locally. With Compose, you use a [YAML](https://en.wikipedia.org/wiki/YAML){:target="_blank"} file to configure your application's services. Then, with a single command, you create and start all the services from your configuration.

### Dockerfile

A **Dockerfile** is a script containing a successive series of instructions, directions, and commands which are run to form a new Docker image. Each command translates to a new layer in the image, forming the end product. The Dockerfile replaces the process of doing everything manually and repeatedly. When a Dockerfile finishes building, the end result is a new image, which you can use to start a new Docker container.

### Difference between containers and virtual machines

It's important to understand the difference between using containers and using VMs. Here's a comparison from the Docker site - [What is a Container](https://www.docker.com/resources/what-container){:target="_blank"}:

The main difference is that when you run a container, you are not starting a complete new OS instance. This makes containers much more lightweight and quicker to start. A container also takes up much less space on your hard-disk as it doesn't have to ship the whole OS.

## Arkcase Docker images
The Arkcase Docker images are available in the Amazon Elastic Container Registry (ECR). 

The following Docker images relate to Arkcase:
* https://github.com/arkcase/ark_arkcase_core - Case Management Core Product
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
* https://github.com/ArkCase/ark_dbinit - mechanism to render SQL initialization files which can then be consumed by a database container


ark_helm_charts
===============

Collection of Helm charts for ArkCase.

How to update the repo?
-----------------------

Whenever you add a new Helm chart or make changes to an existing one,
you need to update the repo. In order to do that, you need to clone
this repo on your local computer and run the following (you need to
have `helm` installed on your local computer):

  1. Create a branch
  2. If creating a new chart, add the new chart to
     [the charts directory](charts)
  3. Run `$ helm package charts/*`
  4. Run `$ helm repo index --url https://arkcase.github.io/ark_helm_charts/ .`
  5. Commit the tarball(s) that helm created and the `index.yaml` file
  6. Run `$ git push`
  7. The new Helm chart (or changes to existing Helm charts) will be
     available once the PR is accepted and merged into the `develop`
     branch
