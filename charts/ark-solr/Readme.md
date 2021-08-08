The following table shows the configuration options for the Solr helm chart:
| Parameter                                     | Description                           | Default Value                                                       |
| --------------------------------------------- | ------------------------------------- | --------------------------------------------------------------------- |
| `port`                                        | The port that Solr will listen on | `8983`                                                                |
| `service.port`                                        | The port that Solr will listen on | `8983`                                                                |
| `image.repository`                                        |  |  check the values.yaml for more information                                                           |
| `image.tag`| | check the values.yaml more information|
| `nameOverride`| name of the k8s workload ad chart name | `ark-solr` |
|`service.type`| service type of k8s workload for internal communication | `ClusterIP`|
|`persistence.storageClass` | type of storage used | `gp2`|
|`persistence.size` | persistent volume size | `8`|
