# kubernetes-data-platform

![Version: 1.7.5](https://img.shields.io/badge/Version-1.7.5-informational?style=flat-square)

Hadoop-less data platform for the Smart City OS

## Source Code

* <https://github.com/UrbanOS-Public/kdp>
* <https://github.com/prestodb/presto>
* <https://github.com/apache/hive>
* <https://github.com/minio/minio>
* <https://github.com/helm/helm>

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| global.buckets.hiveStorageBucket | string | `"placeholderName"` |  |
| global.environment | string | `"sandbox"` |  |
| global.ingress.annotations | object | `{}` |  |
| global.objectStore.accessKey | string | `"accessKey"` |  |
| global.objectStore.accessSecret | string | `"accessSecret"` |  |
| hook.container.image | string | `"alpine"` |  |
| hook.container.tag | string | `"3.8"` |  |
| metastore.allowDropTable | bool | `false` |  |
| metastore.deploy.container.image | string | `"smartcitiesdata/metastore"` |  |
| metastore.deploy.container.pullPolicy | string | `"Always"` |  |
| metastore.deploy.container.resources.limits.cpu | int | `2` |  |
| metastore.deploy.container.resources.limits.memory | string | `"1.5Gi"` |  |
| metastore.deploy.container.resources.requests.cpu | int | `2` |  |
| metastore.deploy.container.resources.requests.memory | string | `"1.5Gi"` |  |
| metastore.deploy.container.tag | string | `"0.11.1"` |  |
| metastore.deploy.replicas | int | `1` |  |
| metastore.deploy.updateStrategy.rollingUpdate.maxSurge | int | `1` |  |
| metastore.deploy.updateStrategy.rollingUpdate.maxUnavailable | int | `1` |  |
| metastore.deploy.updateStrategy.type | string | `"RollingUpdate"` |  |
| metastore.jvm.gcMethod.g1.heapRegionSize | string | `"32M"` |  |
| metastore.jvm.gcMethod.type | string | `"UseG1GC"` |  |
| metastore.jvm.maxHeapSize | string | `"768M"` |  |
| metastore.service.port | int | `9083` |  |
| metastore.service.type | string | `"ClusterIP"` |  |
| metastore.timeout | string | `"1m"` |  |
| metastore.warehouseDir | string | `"hive-s3"` |  |
| minio.deploy.container.image | string | `"minio/minio"` |  |
| minio.deploy.container.pullPolicy | string | `"IfNotPresent"` |  |
| minio.deploy.container.tag | string | `"RELEASE.2019-01-16T21-44-08Z"` |  |
| minio.deploy.replicas | int | `1` |  |
| minio.deploy.updateStrategy.rollingUpdate.maxSurge | int | `1` |  |
| minio.deploy.updateStrategy.rollingUpdate.maxUnavailable | int | `1` |  |
| minio.deploy.updateStrategy.type | string | `"RollingUpdate"` |  |
| minio.enable | bool | `true` |  |
| minio.externalMinio | bool | `false` |  |
| minio.gateway.enable | bool | `false` |  |
| minio.gateway.type | string | `"azure"` |  |
| minio.googleCredentials.client_email | string | `""` |  |
| minio.googleCredentials.client_id | string | `""` |  |
| minio.googleCredentials.client_x509_cert_url | string | `""` |  |
| minio.googleCredentials.private_key | string | `""` |  |
| minio.googleCredentials.private_key_id | string | `""` |  |
| minio.googleCredentials.project_id | string | `""` |  |
| minio.ingress.enable | bool | `true` |  |
| minio.service.port | int | `9000` |  |
| minio.service.type | string | `"NodePort"` |  |
| minio.storage.mode | string | `"ReadWriteOnce"` |  |
| minio.storage.size | string | `"5Gi"` |  |
| postgres.db.name | string | `"metastore"` |  |
| postgres.db.password | string | `"password123"` |  |
| postgres.db.user | string | `"hive"` |  |
| postgres.deploy.container.image | string | `"postgres"` |  |
| postgres.deploy.container.pullPolicy | string | `"IfNotPresent"` |  |
| postgres.deploy.container.tag | string | `"11.1-alpine"` |  |
| postgres.deploy.replicas | int | `1` |  |
| postgres.deploy.updateStrategy.rollingUpdate.maxSurge | int | `1` |  |
| postgres.deploy.updateStrategy.rollingUpdate.maxUnavailable | int | `1` |  |
| postgres.deploy.updateStrategy.type | string | `"RollingUpdate"` |  |
| postgres.enable | bool | `true` |  |
| postgres.service.port | int | `5432` |  |
| postgres.service.type | string | `"ClusterIP"` |  |
| postgres.storage.mode | string | `"ReadWriteOnce"` |  |
| postgres.storage.persist | bool | `false` |  |
| postgres.storage.size | string | `"5Gi"` |  |
| postgres.tls.enable | bool | `false` |  |
| postgres.tls.mode | string | `"verify-full"` |  |
| postgres.tls.rootCertPath | string | `"/etc/ssl/certs/ca-certificates.crt"` |  |
| presto.deploy.container.image | string | `"smartcitiesdata/presto"` |  |
| presto.deploy.container.pullPolicy | string | `"Always"` |  |
| presto.deploy.container.resources.limits.cpu | int | `2` |  |
| presto.deploy.container.resources.limits.memory | string | `"2Gi"` |  |
| presto.deploy.container.resources.requests.cpu | int | `1` |  |
| presto.deploy.container.resources.requests.memory | string | `"2Gi"` |  |
| presto.deploy.container.tag | string | `"0.11.3"` |  |
| presto.deploy.deployPrometheusExporter | bool | `false` |  |
| presto.deploy.replicas | int | `1` |  |
| presto.deploy.updateStrategy.rollingUpdate.maxSurge | int | `1` |  |
| presto.deploy.updateStrategy.rollingUpdate.maxUnavailable | int | `1` |  |
| presto.deploy.updateStrategy.type | string | `"RollingUpdate"` |  |
| presto.deploy.useJmxExporter | bool | `false` |  |
| presto.environment | string | `"production"` |  |
| presto.ingress.annotations."alb.ingress.kubernetes.io/healthcheck-path" | string | `"/v1/cluster"` |  |
| presto.ingress.enable | bool | `false` |  |
| presto.jvm.gcMethod.g1.heapRegionSize | string | `"32M"` |  |
| presto.jvm.gcMethod.type | string | `"UseG1GC"` |  |
| presto.jvm.maxHeapSize | string | `"1536M"` |  |
| presto.logLevel | string | `"INFO"` |  |
| presto.query.heapHeadroomPerNode | string | `"0.75GB"` |  |
| presto.query.maxMemory | string | `"1GB"` |  |
| presto.query.maxMemoryPerNode | string | `"0.5GB"` |  |
| presto.query.maxTotalMemoryPerNode | string | `"0.6GB"` |  |
| presto.service.port | int | `8080` |  |
| presto.service.type | string | `"NodePort"` |  |
| presto.task.writerCount | int | `1` |  |
| presto.workers | int | `0` |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.12.0](https://github.com/norwoodj/helm-docs/releases/v1.12.0)
