# PVC Tool

This chart works on all the PVCs in a given Namespace, in one of three modes (set with the `mode` value):

  * ***rsync*** (default): a single StatefulSet mounts all the PVCs, and exposes them as modules in an [rsync daemon](https://en.wikipedia.org/wiki/Rsync) (see [RSYNC PVC Access](#rsync-pvc-access)).
  * ***clone***: each PVC's data is copied into a new PVC named `${clonePrefix}-${pvcName}`, optionally with a different `storageClassName` (see [Clone and S3 Modes](#clone-and-s3-modes)).
  * ***s3***: each PVC's data is uploaded into S3 as a `.tar.gz` file (see [Clone and S3 Modes](#clone-and-s3-modes)).

## Clone and S3 Modes

In these modes, instead of one pod mounting every PVC (which can't work when the volumes can't all be attached to the same node), each PVC (or pair of old and new PVCs) gets its own StatefulSet, so its pod can be scheduled wherever its volumes can be attached. Each pod copies its data, verifies the copy, and then becomes ***Ready*** whatever the outcome, with the exit status stored in `/.pod.result` (`0` means success). To repeat the work for a PVC, delete its pod.

PVCs named `${something}-0` through `${something}-N` most likely came from the same StatefulSet's `volumeClaimTemplates`. They're handled by a single StatefulSet with `N+1` replicas, whose `volumeClaimTemplates` match the existing PVCs' names, so each pod mounts only the PVCs with its own ordinal. The StatefulSet's name is chosen by splitting `${something}` at a dash, such that it collides with no other StatefulSet or pod in the namespace (e.g. `data-arkcase-search-0` through `data-arkcase-search-2` will be handled by a StatefulSet named `arkcase-search`, or `search` if `arkcase-search` already exists). If no split works, or the ordinals aren't contiguous from `0`, each PVC gets a StatefulSet of its own, named `${releaseName}-${pvcName}`. This requires Kubernetes 1.28 or later, for the `apps.kubernetes.io/pod-index` pod label.

Each pod receives these environment variables:

|Variable|Modes|Description|
|--------|-----|-----------|
|`SOURCE_PVC`|both|The name of the PVC being copied, mounted at `/source`|
|`TARGET_PVC`|clone|The name of the new PVC, mounted at `/target`|
|`S3_BUCKET`|s3|The value of `s3.bucket`|
|`S3_REGION`|s3|The value of `s3.region` (if given)|
|`S3_PREFIX`|s3|`${s3.prefix}/${namespace}/${SOURCE_PVC}` (the object is `${S3_PREFIX}.tar.gz`)|
|`S3_ENDPOINT`|s3|The value of `s3.endpoint` (if given)|

### Clone

```
helm install pvc-tool arkcase/pvc-tool --set mode=clone --set storageClassName=new-storage-class
```

The new PVCs are annotated with `helm.sh/resource-policy: keep`, so they survive the chart's removal. If `storageClassName` isn't given, they'll use the cluster's default storage class. The copy is done with `rsync`, and is verified by comparing the type, permissions, ownership, size and path of every file in both volumes.

### S3

```
helm install pvc-tool arkcase/pvc-tool \
    --set mode=s3 \
    --set s3.bucket=some-bucket \
    --set s3.region=us-east-1 \
    --set s3.prefix=pvc-tool-prefix
```

This will upload each PVC's data into `s3://some-bucket/pvc-tool-prefix/${namespace}/${pvcName}.tar.gz`. The archives are created with GNU `tar`, preserving numeric ownership, permissions, sparse files, and (if the `tar` in the image supports them) ACLs and extended attributes. To restore one, extract it as root with `tar --numeric-owner -xzpf ...`.

  * `s3.accessKey` and `s3.secretKey`: if given, they're stored in a Secret and passed in as `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`. Otherwise, the AWS CLI's default credential chain is used (e.g. the node's instance profile, or IRSA/Pod Identity via `serviceAccountName`).
  * `s3.endpoint`: the endpoint URL for S3-compatible stores.
  * `s3.verify` (default `true`): download each archive after uploading it, and compare its file listing against the PVC's contents.

### Container Image

The pods in these modes need `bash`, `rsync` (clone mode), GNU `tar`, `gzip` and the `aws` CLI (s3 mode), plus GNU `coreutils`, `findutils` and `diffutils`. Set `image.registry`, `image.repository` and `image.tag` to an image that provides them.

### Automation

The `tools/convert-pvc-sc` script installs the chart in clone mode, waits for every pod to finish, and uninstalls it. Any arguments after `--` are passed to `helm install`:

```
tools/convert-pvc-sc my-namespace pvc-tool -- --set storageClassName=new-storage-class
```

The `tools/reassign-pvcs` script can then swap the new volumes in, under the old PVCs' names.

# RSYNC PVC Access

In the ***rsync*** mode, this chart creates a StatefulSet that mounts all PVCs in a given Namespace, and exposes them as modules in an [rsync daemon](https://en.wikipedia.org/wiki/Rsync).  This allows one to either extract the data from the PVCs, or transfer data into them from another source.

This tool is similar to [pv-migrate](https://github.com/utkuozdemir/pv-migrate), but differs in that it exposes all PVCs at once, and thus allows you to handle them in batch (i.e. when moving an application between namespaces).

It also exposes a ***scripts*** module that can be used to download all the utility scripts with which uploads into the PVC can be performed. Even though the pod allows both upload _and_ download, it's primarily used to migrate persistent data from one cluster or namespace into another.

## External Access

In the AI5 environment, external access can be enabled by way of setting the value `externalDns.name` to the hostname you want your pod's service to be exposed as. This will cause an annotation to be added with that value. The annotation's name by default is `external-dns.alpha.kubernetes.io/hostname`, but can be set with the value `externalDns.annotation`.

For example:

`helm install pvc-tool arkcase/pvc-tool --set externalDns.name=pvc-tool.arkcase.net`

This will export the service such that you may connect to it using `rsync-pvcs (pull|push) rsync://pvc-tool.arkcase.net ...`.

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
