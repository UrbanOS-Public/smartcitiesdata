# urban-os

![Version: 1.13.59](https://img.shields.io/badge/Version-1.13.59-informational?style=flat-square) ![AppVersion: 1.0](https://img.shields.io/badge/AppVersion-1.0-informational?style=flat-square)

Master chart that deploys the UrbanOS platform. See the individual dependency readmes for configuration options.

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| file://../alchemist | alchemist | >= 1.0.0 |
| file://../andi | andi | >= 1.0.0 |
| file://../discovery-api | discovery-api | >= 1.0.0 |
| file://../discovery-streams | discovery-streams | >= 1.0.0 |
| file://../discovery-ui | discovery-ui | >= 1.0.0 |
| file://../external-services | external-services | >= 1.0.0 |
| file://../forklift | forklift | >= 1.0.0 |
| file://../kafka | kafka | >= 1.0.0 |
| file://../kubernetes-data-platform | kubernetes-data-platform | >= 1.0.0 |
| file://../monitoring | monitoring | >= 1.0.0 |
| file://../performancetesting | performancetesting | >= 0.0.0 |
| file://../persistence | persistence | >= 1.0.0 |
| file://../raptor | raptor | >= 1.0.0 |
| file://../reaper | reaper | >= 1.0.0 |
| file://../valkyrie | valkyrie | >= 1.0.0 |
| https://helm.elastic.co | elasticsearch | 7.17.3 |
| https://helm.releases.hashicorp.com | vault | 0.27.0 |
| https://operator.min.io/ | minio-operator(operator) | 5.0.12 |
| https://operator.min.io/ | minio-tenant(tenant) | 5.0.12 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| alchemist | object | `{"enabled":true}` | See dependent chart for configuration details |
| andi | object | `{"enabled":true,"fullnameOverride":"andi"}` | See dependent chart for configuration details |
| discovery-api | object | `{"elasticsearch":{"host":"elasticsearch-master:9200","tls":false},"enabled":true}` | See dependent chart for configuration details |
| discovery-api.elasticsearch.host | string | `"elasticsearch-master:9200"` | This is the default location of the chart-provided elasticsearch instance |
| discovery-api.elasticsearch.tls | bool | `false` | Set this to true to require the api to connect to elasticsearch via https. TLS must be configured on the elasticsearch cluster |
| discovery-streams | object | `{"enabled":true}` | See dependent chart for configuration details |
| discovery-ui | object | `{"enabled":true}` | See dependent chart for configuration details |
| elasticsearch | object | `{"enabled":true,"replicas":2}` | By default, the urbanOS chart stands up its own elasticsearch instance. Disable this if you plan to provide your own. TLS will be disabled by default, but can be configured using the chart   documentation below https://github.com/elastic/helm-charts/tree/master/elasticsearch#configuration |
| forklift | object | `{"enabled":true,"fullnameOverride":"forklift"}` | See dependent chart for configuration details |
| global.auth.auth0_domain | string | `""` |  |
| global.auth.jwt_issuer | string | `""` |  |
| global.auth.raptor_url | string | `""` |  |
| global.buckets.hiveStorageBucket | string | `""` | Required. Bucket that extracted data is written to. *Note*: Bucket names are globally unique in S3 or cluster unique in Minio |
| global.buckets.hostedFileBucket | string | `""` | Required. Bucket to store Host type datasets. *Note*: Bucket names are globally unique in S3 or cluster unique in Minio |
| global.buckets.region | string | `"us-west-2"` | S3 Bucket region. Ignored when using Minio |
| global.ingress | object | `{"dnsZone":"localhost","rootDnsZone":"localhost"}` | Common ingress configuration |
| global.ingress.dnsZone | string | `"localhost"` | Domain name for the platform |
| global.ingress.rootDnsZone | string | `"localhost"` | Root domain name for the platform. Often the same as `dnsZone` |
| global.kafka.brokers | string | `"pipeline-kafka-bootstrap:9092"` | This is the default url for the kafka cluster deployed with the chart. Override this if you are using an external kafka cluster. |
| global.objectStore | object | `{"accessKey":[],"accessSecret":[],"hiveStoragePath":"","host":"","port":80}` | Connection info for connecting to s3 for the persistence layer |
| global.presto.url | string | `"http://kubernetes-data-platform-presto:8080"` | This is the default url that presto is deployed to with the chart. Override this if you are using an external presto cluster. |
| global.redis.host | string | `"redis.external-services"` | The url to a Redis instance. *Note*: Most apps in the platform require access to a Redis instance, and one is not currently included in the chart. |
| global.redis.password | string | `""` |  |
| global.require_admin_api_key | bool | `false` |  |
| global.require_api_key | bool | `false` | Determines whether a user is required to log in in order to see public data in the discovery suite |
| global.subdomains.andi | string | `"andi"` |  |
| global.subdomains.discoveryApi | string | `"data"` |  |
| global.subdomains.discoveryUi | string | `"discovery"` |  |
| global.subdomains.raptor | string | `"raptor"` |  |
| global.subdomains.share | string | `"sharedata"` |  |
| global.vault.endpoint | string | `"vault:8200"` | A url to a vault instance. Reaper and Andi use vault to read and store secrets for dataset ingestion. *Note*: Currently, only the provided vault chart works with UrbanOS |
| kafka.enabled | bool | `true` |  |
| kubernetes-data-platform.enabled | bool | `false` |  |
| kubernetes-data-platform.metastore.allowDropTable | bool | `true` |  |
| kubernetes-data-platform.metastore.timeout | string | `"360m"` |  |
| kubernetes-data-platform.minio.enable | bool | `false` | Minio is an experimental way to gain platform independence from S3 |
| kubernetes-data-platform.postgres.db.name | string | `"metastore"` |  |
| kubernetes-data-platform.postgres.db.user | string | `"metastore"` |  |
| kubernetes-data-platform.postgres.enable | bool | `false` | Include in-cluster postgres for the metastore |
| kubernetes-data-platform.postgres.tls.enable | bool | `true` |  |
| kubernetes-data-platform.postgres.tls.mode | string | `"verify-full"` |  |
| kubernetes-data-platform.postgres.tls.rootCertPath | string | `"/etc/ssl/certs/ca-certificates.crt"` |  |
| kubernetes-data-platform.presto.deploy.container.resources | object | `{"limits":{"cpu":2,"memory":"2Gi"},"requests":{"cpu":1,"memory":"2Gi"}}` | Resource configuration for the presto workers |
| kubernetes-data-platform.presto.deployPrometheusExporter | bool | `true` |  |
| kubernetes-data-platform.presto.jvm.maxHeapSize | string | `"1536M"` | Heap size for the presto workers, should be relative to available resources |
| kubernetes-data-platform.presto.task.writerCount | int | `1` |  |
| kubernetes-data-platform.presto.useJmxExporter | bool | `true` |  |
| kubernetes-data-platform.presto.workers | int | `2` |  |
| minio-operator.enabled | bool | `true` |  |
| minio-operator.operator.replicaCount | int | `1` |  |
| minio-operator.operator.resources.limits.cpu | string | `"200m"` |  |
| minio-operator.operator.resources.limits.ephemeral-storage | string | `"500Mi"` |  |
| minio-operator.operator.resources.limits.memory | string | `"256Mi"` |  |
| minio-operator.operator.resources.requests.cpu | string | `"200m"` |  |
| minio-operator.operator.resources.requests.ephemeral-storage | string | `"500Mi"` |  |
| minio-operator.operator.resources.requests.memory | string | `"256Mi"` |  |
| minio-tenant.enabled | bool | `true` |  |
| minio-tenant.tenant.buckets[0].name | string | `"presto-hive-storage"` |  |
| minio-tenant.tenant.certificate.requestAutoCert | bool | `false` |  |
| minio-tenant.tenant.configuration.name | string | `"minio1-env-configuration"` |  |
| minio-tenant.tenant.env[0].name | string | `"MINIO_BROWSER_LOGIN_ANIMATION"` |  |
| minio-tenant.tenant.env[0].value | string | `"off"` |  |
| minio-tenant.tenant.exposeServices.console | bool | `true` |  |
| minio-tenant.tenant.exposeServices.minio | bool | `true` |  |
| minio-tenant.tenant.name | string | `"minio1"` |  |
| minio-tenant.tenant.pools[0].affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution[0].labelSelector.matchExpressions[0].key | string | `"v1.min.io/tenant"` |  |
| minio-tenant.tenant.pools[0].affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution[0].labelSelector.matchExpressions[0].operator | string | `"In"` |  |
| minio-tenant.tenant.pools[0].affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution[0].labelSelector.matchExpressions[0].values[0] | string | `"minio1"` |  |
| minio-tenant.tenant.pools[0].affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution[0].labelSelector.matchExpressions[1].key | string | `"v1.min.io/pool"` |  |
| minio-tenant.tenant.pools[0].affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution[0].labelSelector.matchExpressions[1].operator | string | `"In"` |  |
| minio-tenant.tenant.pools[0].affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution[0].labelSelector.matchExpressions[1].values[0] | string | `"pool-0"` |  |
| minio-tenant.tenant.pools[0].affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution[0].topologyKey | string | `"kubernetes.io/hostname"` |  |
| minio-tenant.tenant.pools[0].name | string | `"pool-0"` |  |
| minio-tenant.tenant.pools[0].resources.limits.cpu | string | `"500m"` |  |
| minio-tenant.tenant.pools[0].resources.limits.memory | string | `"2Gi"` |  |
| minio-tenant.tenant.pools[0].resources.requests.cpu | string | `"500m"` |  |
| minio-tenant.tenant.pools[0].resources.requests.memory | string | `"2Gi"` |  |
| minio-tenant.tenant.pools[0].servers | int | `1` |  |
| minio-tenant.tenant.pools[0].storageClassName | string | `"standard"` |  |
| minio-tenant.tenant.pools[0].volumesPerServer | int | `4` |  |
| minio-tenant.tenant.users[0].name | string | `"tenant-user-0"` |  |
| monitoring | object | `{"enabled":false}` | By default monitoring is disabled as it is optional, but we recommend it be enabled for production deployments |
| performancetesting.enabled | bool | `false` |  |
| performancetesting.endpoints.ANDI_URL | string | `""` |  |
| performancetesting.endpoints.API_KEY | string | `""` |  |
| performancetesting.endpoints.DISCOVERY_URL | string | `""` |  |
| persistence.enabled | bool | `true` |  |
| raptor | object | `{"enabled":true,"fullnameOverride":"raptor"}` | See dependent chart for configuration details |
| reaper | object | `{"enabled":true,"fullnameOverride":"reaper"}` | See dependent chart for configuration details |
| secrets.minio.base64UserAccessKey | string | `"inject-during-deployment"` |  |
| secrets.minio.base64UserSecretKey | string | `"inject-during-deployment"` |  |
| secrets.minio.rootPassword | string | `"inject-during-deployment"` |  |
| secrets.minio.rootUserName | string | `"inject-during-deployment"` |  |
| valkyrie | object | `{"enabled":true,"fullnameOverride":"valkyrie","replicaCount":1}` | See dependent chart for configuration details |
| vault.global.openshift | bool | `true` |  |
| vault.injector.resources.limits.cpu | string | `"250m"` |  |
| vault.injector.resources.limits.memory | string | `"256Mi"` |  |
| vault.injector.resources.requests.cpu | string | `"250m"` |  |
| vault.injector.resources.requests.memory | string | `"256Mi"` |  |
| vault.server.ha.enabled | bool | `true` |  |
| vault.server.ha.raft.enabled | bool | `true` |  |
| vault.server.resources.limits.cpu | string | `"250m"` |  |
| vault.server.resources.limits.memory | string | `"256Mi"` |  |
| vault.server.resources.requests.cpu | string | `"250m"` |  |
| vault.server.resources.requests.memory | string | `"256Mi"` |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.12.0](https://github.com/norwoodj/helm-docs/releases/v1.12.0)
