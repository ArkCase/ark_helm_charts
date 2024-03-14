# RSYNC PVC Access

This chart creates a StatefulSet that mounts all PVCs in a given Namespace, and exposes them as modules in an [rsync daemon](https://en.wikipedia.org/wiki/Rsync).  This allows one to either extract the data from the PVCs, or transfer data into them from another source.

This tool is similar to [pv-migrate](https://github.com/utkuozdemir/pv-migrate), but differs in that it exposes all PVCs at once, and thus allows you to handle them in batch (i.e. when moving an application between namespaces).

It also exposes a ***scripts*** module that can be used to download all the utility scripts with which uploads into the PVC can be performed. Even though the pod allows both upload _and_ download, it's primarily used to migrate persistent data from one cluster or namespace into another.

## External Access

In the AI5 environment, external access can be enabled by way of setting the value `externalDns.name` to the hostname you want your pod's service to be exposed as. This will cause an annotation to be added with that value. The annotation's name by default is `external-dns.alpha.kubernetes.io/hostname`, but can be set with the value `externalDns.annotation`.

For example:

`helm install pvc-rsync arkcase/pvc-rsync --set externalDns.name=pvc-rsync.arkcase.net`

This will export the service such that you may connect to it using `rsync-pvcs (pull|push) rsync://pvc-rsync.arkcase.net ...`.

## How to use it

The execution is made up of two parts:

  * Identifying the Source Data
  * Executing the Data Transfer

### Identifying the Source Data

This step identifies the source data to be copied over, and lists it out in a two-column format (separated by spaces), with the first column being the PVC Name, and the remainder of the line being the directory where the PVC's data is stored, like so:


|PVC Name|PVC Directory|
|--------|-------------|
|my-test-pvc|/some/directory/in/my/computer|


This allows the user to determine whatever means they see fit to identify how the PVCs' data is to be populated or downloaded.  Two utility scripts are provided for ease-of-use:

  * ***list-pvcs***: scours the given directory (or the current one, if none is given) and produces a listing consisting of the base name of any subdirectories as the PVC name, and the fully-qualified path as the source directory. If the directory's name isn't a valid PVC name, a line for that directory will be rendered as a comment, simply to facilitate the user's life when identifying why a particular subdirectory may not have been included.

  * ***list-pvcs-from-hostpath***: scours the given directory (or the current one, if none is given) under the assumption that it's the storage root for a namespace's ***hostpath*** storage area, as implemented by the [Hostpath Provisioner](https://github.com/ArkCase/ark_helm_charts/tree/main/src/hostpath-provisioner) helm chart, and outputs the expected mappings.

### Executing the Data Transfer

Once the user has identified how the PVCs are to be mapped to local directories, the next decision is to execute the desired transfer using the ***rsync-pvcs*** script:

```
rsync-pvcs (push|pull) server-spec [pvc-list-file]
```

The script "eats" the contents of the `pvc-list-file` (if not provided, or given as `-`, ***STDIN*** is used), formatted as descried above, and proceeds to execute the copies in turn, one by one. No validation is performed to protect against a PVC being read from or written to twice. Likewise, no protection to reading from or writing to a local directory more than once. The user is left to their own devices in deciding how to map the data from the source to the target.

This tool only supports upload or download in such a way that the destination folder ends up being a copy of the source folder.

  * In ***push*** mode, the data is copied from the local directory into the target server.
  * In ***pull*** mode, the data is copied from the target server into the local directory.

For robustness, the script is intelligent enough to retry (infintely) on data transfer timeouts as detected by `rsync`, but will fail the transfers on any other failures.

## Supported Connectivity Methods

Not all environments are created equal, and sometimes one must navigate firewalls and other networking issues in order to get a job done.  The ***rsync-pvcs*** script supports four connectivity models which should cover most if not all connectivity requirements:

  * ***rsync://[user@]hostname***: Direct connection to `rsync` (port `873/tcp`)
  * ***ssh://[user@]hostname***: Use `ssh` as the transport layer (port `22/tcp`)
  * ***kubectl://podName[@namespace]***: Use `kubectl exec ...` as the transport layer (port may vary, generally `6443/tcp`)
  * ***rsh://[user@]hostname***: Use the value of RSYNC_RSH as the remote shell ... this is the most flexible of all, since it allows you to use any mechanism you desire to achieve connectivity to the remote location.
