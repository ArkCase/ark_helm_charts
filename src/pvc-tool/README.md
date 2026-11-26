# PVC Tool

This chart works on all the PVCs in a given Namespace, in one of three modes (set with the `mode` value):

  * ***rsync*** (default): a single StatefulSet mounts all the PVCs, and exposes them as modules in an [rsync daemon](https://en.wikipedia.org/wiki/Rsync) (see [RSYNC PVC Access](#rsync-pvc-access)).
  * ***clone***: each PVC's data is copied into a new PVC named `${clonePrefix}-${pvcName}`, optionally with a different `storageClassName` (see [Clone and S3 Modes](#clone-and-s3-modes)).
  * ***s3***: each PVC's data is uploaded into S3 (as a `.tar.gz` file, or a tree of objects made with `s3-fs-mirror`), or downloaded from there (see [Clone and S3 Modes](#clone-and-s3-modes)).

## Clone and S3 Modes

In these modes, instead of one pod mounting every PVC (which can't work when the volumes can't all be attached to the same node), each PVC (or pair of old and new PVCs) gets a Job of its own, named `${releaseName}-${pvcName}`, so its pod can be scheduled wherever its volumes can be attached. If that name is longer than 63 characters, or a Job that isn't this release's already has it, a hash of the PVC's name is used as its suffix instead. Each Job runs a single pod at a time, which mounts its PVCs by name, so nothing the chart creates can create PVCs of its own. Its annotations `armedia.com/pvc-tool-source` and `armedia.com/pvc-tool-target` hold the names of the PVCs it works on.

Each pod copies its data, verifies the copy, and exits: the Job then either ***completes***, or ***fails***. The pod attempts the work up to `maxAttempts` times, and once it gives up, the Job fails right away. A pod that's lost instead (e.g. along with its node) is replaced, up to `backoffLimit` times (evicted or preempted pods don't count). To repeat the work for a PVC, re-create its Job (see `tools/retry-context-transfers`).

Each pod receives these environment variables:

|Variable|Modes|Description|
|--------|-----|-----------|
|`SOURCE_PVC`|clone, s3 upload|The name of the PVC being copied, mounted (read-only) at `/source`|
|`TARGET_PVC`|clone, s3 download|The name of the PVC being copied into, mounted at `/target`|
|`S3_DIRECTION`|s3|The value of `s3.direction` (`upload` or `download`)|
|`S3_BUCKET`|s3|The value of `s3.bucket`|
|`S3_REGION`|s3|The value of `s3.region` (if given)|
|`S3_PREFIX`|s3|`${s3.prefix}/${s3.namespace}/${pvcName}`: the archive is `s3://${S3_BUCKET}/${S3_PREFIX}.tar.gz` (or the tree is at `s3://${S3_BUCKET}/${S3_PREFIX}/`)|
|`S3_FORMAT`|s3|The value of `s3.format` (`tar` or `mirror`)|
|`S3_VERIFY`|s3 (tar)|The value of `s3.verify`|
|`S3_ENDPOINT`|s3|The value of `s3.endpoint` (if given)|
|`S3_RESUME`|s3 (mirror)|The value of `s3.resume`|
|`S3_CONCURRENCY`, `S3_BWLIMIT`|s3 (mirror)|The values of `s3.concurrency` and `s3.bwlimit` (if given)|

Either way, each target ends up as an exact copy of its source (`lost+found` is left alone). `rsync` and `s3-fs-mirror` delete what isn't in the source, and skip what already matches, so a restarted pod resumes where the previous one left off. A download of a `.tar.gz` archive has to re-read the whole archive anyway, so it empties the target PVC first.

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
    --set s3.prefix=pvc-tool-prefix \
    --set s3.irsaRole=arn:aws:iam::123456789012:role/pvc-tool
```

How each PVC's data is stored depends on `s3.format`:

  * `tar` (default): as `s3://some-bucket/pvc-tool-prefix/${namespace}/${pvcName}.tar.gz`, created with GNU `tar`, preserving numeric ownership, permissions, sparse files, and (if the `tar` in the image supports them) ACLs and extended attributes. An interrupted transfer starts over. With `s3.verify` (the default), the archive is downloaded again after the transfer, and compared against the PVC with `tar --diff`. Next to the archive goes `${pvcName}.listing.gz`: the path, type, permissions, ownership and size of every entry in the PVC. After a download, the PVC must match it, or the pod fails (without retrying). Last goes `${pvcName}.record`, which says the export is complete, when it started, and which archive and listing it made (their ETags, sizes, times and versions). An export that's run again, and finds its record, only does the work again if the archive or the listing aren't the recorded ones anymore, or anything in the PVC changed since the export started (by its ctime, which, unlike the modification time, nothing can set back), or the PVC doesn't match the listing. A download likewise leaves a `.pvc-tool-restore` marker at the root of the PVC (which never makes it into an archive), and when it's run again, only does the work again if the archive or the listing changed, or anything in the PVC changed after the marker, or the PVC doesn't match the listing.
  * `mirror`: as a tree under `s3://some-bucket/pvc-tool-prefix/${namespace}/${pvcName}/`, with `s3-fs-mirror`: one object per file, directory, symlink and so on, at the same relative path, with each entry's ownership, permissions, times and extended attributes in its object's metadata. Hardlinks, sparse files, FIFOs and devices are handled too. An interrupted copy resumes where it left off, down to the partly transferred files (see `s3.resume`). The tree's root directory object, `${S3_PREFIX}/`, says whether the upload is complete. Re-uploading into the same prefix updates the tree in place.

Use a new `s3.prefix` for each backup (e.g. a date) to keep the previous one intact.

To copy the data back into PVCs, deploy the application so it creates its PVCs, scale it down to 0 so the PVCs are released, and install the chart with `s3.direction=download`:

```
helm install pvc-tool arkcase/pvc-tool \
    --set mode=s3 \
    --set s3.direction=download \
    --set s3.bucket=some-bucket \
    --set s3.region=us-east-1 \
    --set s3.prefix=pvc-tool-prefix \
    --set s3.irsaRole=arn:aws:iam::123456789012:role/pvc-tool
```

Each PVC in the namespace becomes an exact copy of the archive (or tree) with its name (except for `lost+found`). If there's none for a PVC, its pod fails right away (without retrying), and leaves the PVC alone. If a tree's upload wasn't complete, whatever is there is restored, but the pod fails. To download data that was uploaded from a different namespace, set `s3.namespace` to that namespace's name.

  * `s3.irsaRole`: the ARN of an IAM role for the pods to assume via [IRSA](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html). A ServiceAccount named `serviceAccountName` (default: the release's name) is created with the `eks.amazonaws.com/role-arn` annotation, and the pods run as it. The role's trust policy must allow `system:serviceaccount:${namespace}:${serviceAccountName}`.
  * `s3.accessKey` and `s3.secretKey`: static credentials, instead of `s3.irsaRole`. They're stored in a Secret, and passed in as `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`. If neither these nor `s3.irsaRole` are given, the AWS SDK's default credential chain is used (e.g. the node's instance profile, or an existing ServiceAccount set with `serviceAccountName`).
  * `s3.region`: the bucket's region. Required if it's not the cluster's own region (or, without IRSA, the one in the AWS configuration).
  * `s3.endpoint`: the endpoint URL for S3-compatible stores.
  * `s3.direction` (default `upload`): `upload` copies each PVC into S3, `download` copies from S3 into each PVC.
  * `s3.namespace` (default: the release's namespace): the `${namespace}` part of the trees' prefixes.
  * `s3.format` (default `tar`): `tar` or `mirror`, as above.
  * `s3.verify` (default `true`, tar only): compare each archive against the PVC after the transfer.
  * `s3.resume` (default `verify`, mirror only): what to do with a partly transferred file when resuming: `verify` checks what was already transferred against the local copy (on the local disk only) before continuing, `blind` continues without checking, and `restart` transfers the file again.
  * `s3.concurrency` (default `8`, mirror only): how many files each pod transfers at the same time.
  * `s3.bwlimit` (default: no limit, mirror only): the bandwidth limit for each pod, in bytes per second (e.g. `50M`).
  * `s3.extraArgs` (mirror only): more arguments for `s3-fs-mirror` (e.g. `[ "--verbose" ]`).

The IAM role needs these permissions on the bucket (and, for a bucket encrypted with a KMS key, `kms:GenerateDataKey` and `kms:Decrypt` on the key):

  * On the bucket: `s3:ListBucket` and `s3:ListBucketMultipartUploads`.
  * On its objects: `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject`, `s3:AbortMultipartUpload` and `s3:ListMultipartUploadParts`.

### Container Image

The pods in these modes need `bash`, `rsync` (clone mode), GNU `tar`, `gzip` and the `aws` CLI (s3 mode, tar format), `s3-fs-mirror` (s3 mode, mirror format), plus GNU `coreutils`, `findutils` and `diffutils`. Set `image.registry`, `image.repository` and `image.tag` to an image that provides them.

### Automation

The `tools/convert-pvc-sc` script installs the chart in clone mode, waits for every Job to finish (with `tools/wait-for-context-transfers`), and uninstalls it. Any arguments after `--` are passed to `helm install`, so it can also drive the s3 mode:

```
tools/convert-pvc-sc my-namespace pvc-tool -- --set storageClassName=new-storage-class
tools/convert-pvc-sc my-namespace pvc-tool -- --set mode=s3 --set s3.direction=download --set s3.bucket=some-bucket
```

The `tools/reassign-pvcs` script can then swap the new volumes in, under the old PVCs' names.

### Moving Namespaces Between Clusters

These scripts move a namespace, with its PVCs and their data, between clusters through S3. They take each namespace as `context/namespace`, so any number of them can run at the same time, from any number of contexts. A namespace's data goes into the bucket under `${sourceContext}/${sourceNamespace}/`: its definitions in `_k8s/`, and each PVC's `.tar.gz`, `.listing.gz` and `.record`. The scripts run on a workstation, with `kubectl` (and the contexts), `helm`, `jq` and the AWS CLI (with access to the bucket), and drive the chart's s3 mode (tar format). The bucket is given with `-b` (or `MIGRATION_BUCKET`), and any arguments after `--` go to `helm install` (e.g. `-f values.yaml`, with `image.*`, `s3.region` and `s3.irsaRole`; the scripts set everything else in `s3.*`).

  1. Scale down the namespace's workloads, and export it:

     ```
     tools/extract-namespace -b aws-mig-202611-stage aws-fedramp-test/cust-my-demo -- -f pvc-tool-aws-fedramp-test.yaml
     ```

     The namespace must exist, and none of its PVCs may be in use, or nothing is done. Then its definition and its PVCs' definitions are stored, minus what ties them to the old cluster (their volumes, nodes, owners such as StatefulSets, and Rancher projects; Helm's ownership marks are kept, so the application's chart adopts the PVCs it renders itself), and the chart is installed into the namespace to export its PVCs' data, one Job per PVC. Then it waits for them, like `tools/wait-for-context-transfers`.

  2. `tools/wait-for-context-transfers aws-fedramp-test [namespace...]` waits for the context's transfer Jobs: it exits with `0` once they all completed, `1` as soon as any of them failed (naming them), and `2` if the cluster can't be reached. It only reads, so it can be run as often as needed. `tools/retry-context-transfers aws-fedramp-test [namespace...]` re-creates the failed Jobs, so they run again.

     To pick up an interrupted run, run the same command again with `--retry-only`: it starts nothing, but waits for the transfers that were already started, and re-creates the ones that fail (up to `--max-retries` times, default 3). It exits with `1` if the namespace's transfers were never started (and it has something to transfer): run it without `--retry-only` to start them. It doesn't need the bucket.

  3. Tear down the old cluster once all its transfers completed, and build the new one.

  4. Restore the namespace into the new cluster (under the same name, unless the target says otherwise, as in `aws-fedramp-stage/other-name`):

     ```
     tools/restore-namespace -b aws-mig-202611-stage -s gp2=gp3 aws-fedramp-test/cust-my-demo aws-fedramp-stage -- -f pvc-tool-aws-fedramp-stage.yaml
     ```

     The export must be complete (every PVC has its record), every storage class its PVCs will use must exist (map them with `-s old=new`; `-s '*=new'` for every other class, and `-s old=` for the cluster's default), and if the namespace exists already, it may not have PVCs other than the exported ones, or nothing is done. Then the namespace and its PVCs are re-created, and the chart restores their data, comparing each PVC against its archive and its source's listing, and it waits for the Jobs.

  5. Deploy the application: it finds its PVCs in place. Secrets aren't exported, so any password a chart would otherwise generate (and the restored data depends on) must be given in its values.

Either script only waits when the namespace's transfers were already started (the release is installed), and exits with `0` right away when the namespace has no PVCs. Since the Jobs skip the work when it was already done (see the records and markers above), the scripts can be run again and again, and even a re-installed release won't repeat a transfer needlessly. `-r` names the release (default `pvc-tool`, which is also the name of the ServiceAccount it creates for IRSA).

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
