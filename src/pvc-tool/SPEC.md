# pvc-tool: Design

This is how the chart and its tools work, and why. The [README](README.md) covers how to use them.

## Purpose

Moving an application's persistent data, PVC by PVC, between storage classes, namespaces or clusters, without the application's help: its workloads are scaled down, and the chart's pods read (or write) the PVCs directly. The S3 mode, with the tools in `tools/`, moves whole namespaces between clusters, so that a cluster can be torn down and rebuilt (or its environments moved to another one) and the data restored into equivalent deployments.

## The Jobs (clone and s3 modes)

- **One Job per PVC** (or pair of PVCs, when cloning), named `${release}-${pvcName}`, or with a hash suffix if that's longer than 63 characters or taken by a Job that isn't the release's. One pod mounting every PVC can't work when the volumes can't all be attached to the same node; one pod per PVC can be scheduled wherever its volume can be. Jobs also can't create PVCs of their own, as a StatefulSet's `volumeClaimTemplates` would when scaled.
- **The plan comes from the cluster.** The chart `lookup`s the namespace's PVCs (filesystem PVCs only, not being deleted) and Jobs at install time: every PVC in the namespace gets a Job. That's why a restore must only re-create the PVCs it has data for (see `--skip-missing` below).
- **Attempts and failures.** The pod (`scripts/migrate-pvc`) attempts the work up to `maxAttempts` times, then exits non-zero. A failure that a retry can't fix (no archive to download, a restored tree that doesn't match the export's listing) exits at once with code `100`, without retrying.
- **The Job's `podFailurePolicy`**, whose first matching rule wins:
  1. `Ignore` when the pod has the `DisruptionTarget` condition: it was evicted, preempted or killed by a node drain, so it's replaced without counting against `backoffLimit`. A drained pod exits with 143 (SIGTERM), so this must come before the next rule.
  2. `FailJob` on any non-zero exit code of the work's container: the pod already retried, so the Job fails at once.

  A pod that's lost otherwise (e.g. with its node) is replaced, up to `backoffLimit` times.
- **No voluntary disruption while running.** The pods carry `cluster-autoscaler.kubernetes.io/safe-to-evict: "false"` and `karpenter.sh/do-not-disrupt: "true"`. Neither applies to finished pods, so idle nodes are still scaled down, and the garbage collector then deletes the finished pods that were on them (the Jobs, and their status, stay).
- **Retrying a Job** means re-creating it (`kubectl replace --force`, without its controller-generated selector and labels): Jobs are immutable.
- **Credentials**: IRSA (`s3.irsaRole`: the chart's ServiceAccount gets the `eks.amazonaws.com/role-arn` annotation), static keys in a Secret, or the SDK's default chain.

## The S3 tar format

### Objects

For a PVC named `${pvc}`, under `s3://${bucket}/${prefix}/${namespace}/`:

| Object | Contents |
|---|---|
| `${pvc}.tar.gz` | The archive: GNU `tar`, with numeric ownership, permissions, sparse files, and ACLs and extended attributes if the image's `tar` supports them. `lost+found` and the restore marker are left out. |
| `${pvc}.listing.gz` | One line per entry the archive has: `path<TAB>type mode uid:gid size` (no size for directories, whose size depends on the filesystem), sorted in the C locale. |
| `${pvc}.record` | Written last: `version=1`, `started=<epoch, fractional>`, `archive=<identity>`, `listing=<identity>`. An object's identity is its `ETag`, `ContentLength`, `LastModified` and `VersionId` (from `head-object`). |

ETags are only compared for equality. They aren't MD5s, since the buckets are encrypted with SSE-KMS.

### Export

1. If a record exists, the export is skipped when all of these hold:
   - the archive and the listing are the very objects it names;
   - nothing in the PVC has a ctime newer than `started` (unlike the mtime, nothing can set the ctime back);
   - the PVC still matches the listing (ignoring entries `tar` can't archive).
2. Otherwise the old record is deleted: until a new one is stored, the export isn't complete.
3. `started` is taken, and the PVC is listed.
4. `tar` archives the PVC into S3 (`tar | aws s3 cp -`, with the size given so multipart uploads can handle it), indexing what it archives into a file (`--verbose --index-file`, with `--quoting-style=literal` so its paths are written like `find`'s).
5. The index is compared with the listing:
   - **The same:** fine.
   - **Left out, but `tar` can't archive it:** sockets and doors (`find`'s `s` and `D` types). They belong to the processes that made them, which make them anew when they start, so they're reported (the first 10 are named), and dropped from the listing.
   - **Anything else left out, or archived without being in the listing:** the export fails, showing the differences.
6. With `s3.verify`, the archive is downloaded again and compared with the PVC (`tar --diff`).
7. The listing (of what the archive has) is stored, then the record.

### Restore

1. No archive: fail at once (code `100`).
2. If the PVC has a restore marker (`.pvc-tool-restore` at its root), the restore is skipped when all of these hold:
   - the archive and the listing are the ones the marker names;
   - nothing in the PVC changed since the marker (ctime, `-cnewer`);
   - the PVC still matches the listing.
3. Otherwise the PVC is emptied, except for `lost+found`. `tar` can't remove what isn't in the archive, and its skip options would keep files left half-written by an interrupted attempt.
4. The archive is extracted (`aws s3 cp - | tar --extract`), with each entry's path logged unless `s3.terse` is set.
5. With `s3.verify`, the archive is downloaded again and compared with the PVC (`tar --diff`).
6. The PVC is listed and compared with the stored listing. Entries the listing has that `tar` can't archive are reported (the listings of older exports have them); any other difference fails at once (code `100`): the archive itself must be off.
7. The marker is written, and the PVC root's mtime is put back to what the archive set. The marker is touched a second later, so that writing it doesn't count as a change.

## Moving namespaces (`tools/`)

The tools run on a workstation, with `kubectl` (and the kube contexts), `helm`, `jq` and the AWS CLI. Each namespace is named `context/namespace`, so any number of them can run at once.

### Bucket layout

```
s3://${bucket}/${sourceContext}/${sourceNamespace}/_k8s/namespace.json        the namespace's definition
                                                  _k8s/pvcs.json             its PVCs' definitions
                                                  _k8s/original-*.json       both, as they were
                                                  ${pvc}.tar.gz, .listing.gz, .record
```

The definitions are stripped of what ties them to the old cluster: PVs and volume names, the nodes they were bound on, owner references, status, Rancher's projects (its `cattle.io` keys), and kubectl's last-applied configuration. Helm's ownership marks are kept, so the application's chart adopts the PVCs it renders itself. Secrets aren't exported: passwords a chart would otherwise generate (and the restored data depends on) must be pinned in its values.

### The migrations table

One line per namespace: `source-context/namespace target-context[/namespace]`, or `-` when it stays where it is. `#` starts a comment, and no two lines may share a source or a target.

- **Buckets follow the target.** Each namespace's data goes into the bucket of the context it's going to (`-b context=bucket`), so that the bucket can live as long as the target's environment, wherever the source was.
- **Values follow the context a run happens in:** the source's when extracting, the target's when restoring (`-v context=values.yaml`, holding that cluster's `s3.irsaRole`).
- **Idempotence.** `start-migrations` starts each namespace at most once: a namespace whose release is installed counts as started. The Jobs skip the work that was already done, so every tool can be run again and again.

### Restore preconditions

- The export must be complete: every PVC in `pvcs.json` has its record.
  - With `--skip-missing`, the PVCs without one are reported, left out (not re-created), and listed in the target namespace's `armedia.com/pvc-tool-missing-pvcs` annotation. `restore-namespace` and `watch-migrations restore` keep reporting them until the annotation is removed.
  - A PVC that's left out but already exists in the target is refused: the chart would try to restore it.
- Every storage class the PVCs will use must exist, mapped with `-s old=new` (`*=new` for every other class, `old=` for the default class).
- An existing namespace may have no PVCs other than the exported ones.

### IRSA

The IAM roles are created up front by Terraform (`terraform/aws-federal/pvc-migration` in fleet-infrastructure), one per cluster name, each trusting the OIDC providers of the clusters it lists (old and new), with full access to every migration bucket and its KMS key. A role can only trust OIDC providers in its own account. `tools/check-irsa` diagnoses a role that can't be assumed.

### Exit codes

| Tool | 0 | 1 | 2 |
|---|---|---|---|
| `wait-for-context-transfers` | All complete, or nothing to wait for | A transfer failed | The cluster can't be reached |
| `watch-migrations` | All complete | A transfer failed (after the retries), or some namespaces were never started | A context unreachable for 5 rounds |
| `scan-pvc-volumes` | Every volume exists | Some are missing | Errors |
| `start-migrations`, `remove-migrations` | Every namespace done | Some failed (or were left alone) | |

Showing the usage always exits with `1`.

## Known limitations

- **Paths with newlines** break the listings, which are line-based.
- **Sockets and doors** aren't restored, since `tar` can't archive them.
- **Only what's in PVCs moves.** External databases (RDS), Secrets, and cluster-scoped objects are out of scope.
- **Logs:** a finished transfer's log goes with its pod, so a node scale-down that deletes the pod loses it, but not the Job's status.
- **The mirror format** (`s3-fs-mirror`) works, but the tools only drive the tar format.

## Tests

[tests/](tests/README.md) has the suites: `migrate-pvc` itself, run as a pod would against a mock S3, and the tools, against real `kube-apiserver`s (no controllers: the suites set the Jobs' status themselves) and a mock AWS.
