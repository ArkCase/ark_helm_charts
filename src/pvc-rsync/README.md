# RSYNC PVC Access

This chart creates a StatefulSet that mounts all PVCs in a given Namespace, and exposes them as modules in an [rsync daemon](https://en.wikipedia.org/wiki/Rsync).  This allows one to either extract the data, or transfer data in from another source.

This tool is similar to [pv-migrate](https://github.com/utkuozdemir/pv-migrate), but differs in that it exposes all PVCs at once.

It also exposes a _*scripts*_ module that can be used to download all the utility scripts with which uploads into the PVC can be performed. Even though the pod allows both upload _and_ download, it's primarily used to migrate from one cluster into another.

## The direct approach

The script `rsync-pvcs` lets you copy all the PVCs mounted within a given directory into the target server, under the assumption that the the directory contains a set of subdirectories named after each PVC being copied over, and that the target server also exposes similarly-named PVCs.

The script is intelligent enough to retry (infintely) on data transfer timeouts, but fail the transfers on other less-temporary failures.

Clearly, this script requires the ability for the source Pod/Server to connect into the target Pod/server over port 873/tcp

## The roundabout approach

If direct networking is a challenge, but you can execute a `kubectl exec` into the target Pod, fear not! The script `copy-pvcs-to-pod` does just about the same thing as the `rsync-pvcs`, but instead of using direct networking, it uses `kubectl exec` as a "remote shell channel".

Yes. This is not ideal. We know that. But it may be necessary under extreme circumstances when direct networking isn't an option.
