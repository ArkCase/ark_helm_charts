# pvc-tool Tests

```
tests/run                      # every suite
tests/run migrate-pvc skip-missing   # just these
```

Each suite runs in a fresh container of the test image (`Dockerfile`: Debian, with the AWS CLI, `jq`, GNU `tar`, `attr`, `openssl` and `python3`), against a fresh mock AWS ([moto](https://github.com/getmoto/moto), `Dockerfile.moto`). `run` builds both images, fetches the `etcd`, `kube-apiserver`, `kubectl` and `helm` binaries into `tests/.bin` on the first run (`fetch-binaries`, pinned versions), copies the chart and its tools into the container (with `docker cp`, so a remote Docker daemon works too: `DOCKER_HOST` and friends are honored), runs the suite, and reports. Each suite's output goes to `tests/.last-<suite>.log`. It exits with `0` if every suite passed.

Set `S3FS_MIRROR` to an `s3-fs-mirror` binary to also test the mirror format in the `migrate-pvc` suite.

## The suites

| Suite | What it tests |
|---|---|
| `migrate-pvc` | The pods' script, run as a Job's pod would (its exit status is the result): uploads and downloads, verification against the listing, records and markers (what makes an export or restore skip, or redo, its work), restore markers, retries |
| `migrate-pvc-sockets` | Sockets: left out of the archive and the listing (reported), restores of older exports whose listings have them, a `tar` that leaves out something it could have archived (fails), real differences on restore (fail, without retrying) |
| `migrate-pvc-terse` | Extractions log each entry, unless `S3_TERSE` |
| `namespace-tools` | `extract-namespace`, `restore-namespace`, `wait-for-context-transfers`, `retry-context-transfers`: preconditions, definitions, storage class maps, `--retry-only`, `--no-wait` |
| `migrations` | `start-migrations` and `watch-migrations`: the table, buckets that follow the target, values per context, retries, unreachable contexts |
| `remove-migrations` | Removing the releases: running transfers, `-f`, foreign releases, dry runs |
| `skip-missing` | `--skip-missing`: incomplete exports, the namespace annotation, the reports that follow it |
| `scan-pvc-volumes` | PVCs whose EBS volumes are gone, in-tree and CSI volumes, namespaces found by label or by their workloads, snapshots |
| `check-irsa` | Its diagnoses: the token, the provider, the role's trust, the annotation |

The cluster suites use `clusters`: an `etcd` and a `kube-apiserver` for each of the contexts `aws-fedramp-test`, `-stage` and `-prod`, inside the container (`clusters rebuild <context>` wipes one, as a rebuilt cluster). There are no controllers, so nothing runs the Jobs: the suites set their status (`--subresource=status`) to what a pod would have made of them, and test what the tools do with it.

## Writing one

A suite is an executable in `suites/` that prints `PASS: ...` or `FAIL: ...` for each check, and exits with the number of failures. In its container:

| Path | What |
|---|---|
| `/t/bin` | `etcd`, `kube-apiserver`, `kubectl`, `helm` |
| `/t/tools` | The chart's `tools/` |
| `/t/chart` | The chart |
| `/t/clusters` | The clusters' script (kubeconfig in `/w/kubeconfig`) |
| `/migrate-pvc` | The pods' script |

The environment points the AWS CLI at moto (`AWS_ENDPOINT_URL`, and `S3_ENDPOINT` for `migrate-pvc`), with its fake credentials, in `us-east-1`.
