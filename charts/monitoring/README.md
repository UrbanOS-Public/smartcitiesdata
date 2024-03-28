# monitoring

![Version: 1.1.8](https://img.shields.io/badge/Version-1.1.8-informational?style=flat-square) ![AppVersion: 1.0](https://img.shields.io/badge/AppVersion-1.0-informational?style=flat-square)

A combination of the community Prometheus and Grafana charts.

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| https://grafana.github.io/helm-charts | grafana | 6.50.8 |
| https://prometheus-community.github.io/helm-charts | prometheus | 19.6.1 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| adminDeploy | bool | `true` |  |
| global.ingress.annotations | object | `{}` |  |
| grafana.admin.existingSecret | string | `"manual-grafana-secrets"` |  |
| grafana.admin.passwordKey | string | `"grafana-admin-password"` |  |
| grafana.admin.userKey | string | `"grafana-admin-username"` |  |
| grafana.dashboardProviders."dashboardproviders.yaml".apiVersion | int | `1` |  |
| grafana.dashboardProviders."dashboardproviders.yaml".providers[0].disableDeletion | bool | `false` |  |
| grafana.dashboardProviders."dashboardproviders.yaml".providers[0].editable | bool | `true` |  |
| grafana.dashboardProviders."dashboardproviders.yaml".providers[0].folder | string | `""` |  |
| grafana.dashboardProviders."dashboardproviders.yaml".providers[0].name | string | `"default"` |  |
| grafana.dashboardProviders."dashboardproviders.yaml".providers[0].options.path | string | `"/var/lib/grafana/dashboards/default"` |  |
| grafana.dashboardProviders."dashboardproviders.yaml".providers[0].orgId | int | `1` |  |
| grafana.dashboardProviders."dashboardproviders.yaml".providers[0].type | string | `"file"` |  |
| grafana.dashboardProviders."dashboardproviders.yaml".providers[1].disableDeletion | bool | `false` |  |
| grafana.dashboardProviders."dashboardproviders.yaml".providers[1].editable | bool | `true` |  |
| grafana.dashboardProviders."dashboardproviders.yaml".providers[1].folder | string | `""` |  |
| grafana.dashboardProviders."dashboardproviders.yaml".providers[1].name | string | `"kube"` |  |
| grafana.dashboardProviders."dashboardproviders.yaml".providers[1].options.path | string | `"/var/lib/grafana/dashboards/kube"` |  |
| grafana.dashboardProviders."dashboardproviders.yaml".providers[1].orgId | int | `1` |  |
| grafana.dashboardProviders."dashboardproviders.yaml".providers[1].type | string | `"file"` |  |
| grafana.dashboardProviders."dashboardproviders.yaml".providers[2].disableDeletion | bool | `false` |  |
| grafana.dashboardProviders."dashboardproviders.yaml".providers[2].editable | bool | `true` |  |
| grafana.dashboardProviders."dashboardproviders.yaml".providers[2].folder | string | `""` |  |
| grafana.dashboardProviders."dashboardproviders.yaml".providers[2].name | string | `"urbanos"` |  |
| grafana.dashboardProviders."dashboardproviders.yaml".providers[2].options.path | string | `"/var/lib/grafana/dashboards/urbanos"` |  |
| grafana.dashboardProviders."dashboardproviders.yaml".providers[2].orgId | int | `1` |  |
| grafana.dashboardProviders."dashboardproviders.yaml".providers[2].type | string | `"file"` |  |
| grafana.dashboards.kube.kube-cluster.datasource | string | `"Prometheus"` |  |
| grafana.dashboards.kube.kube-cluster.gnetId | int | `6873` |  |
| grafana.dashboards.kube.kube-cluster.revision | int | `2` |  |
| grafana.dashboards.kube.kube-namespace.datasource | string | `"Prometheus"` |  |
| grafana.dashboards.kube.kube-namespace.gnetId | int | `6876` |  |
| grafana.dashboards.kube.kube-namespace.revision | int | `2` |  |
| grafana.dashboards.kube.kube-pods.datasource | string | `"Prometheus"` |  |
| grafana.dashboards.kube.kube-pods.gnetId | int | `6879` |  |
| grafana.dashboards.kube.kube-pods.revision | int | `1` |  |
| grafana.dashboards.kube.kube-prometheus.datasource | string | `"Prometheus"` |  |
| grafana.dashboards.kube.kube-prometheus.gnetId | int | `2` |  |
| grafana.dashboards.kube.kube-prometheus.revision | int | `2` |  |
| grafana.dashboards.urbanos.urban-os-kafka-exporter.datasource | string | `"Prometheus"` |  |
| grafana.dashboards.urbanos.urban-os-kafka-exporter.gnetId | int | `14809` |  |
| grafana.dashboards.urbanos.urban-os-kafka-exporter.revision | int | `1` |  |
| grafana.dashboards.urbanos.urban-os-kube-all-nodes.datasource | string | `"Prometheus"` |  |
| grafana.dashboards.urbanos.urban-os-kube-all-nodes.gnetId | int | `14810` |  |
| grafana.dashboards.urbanos.urban-os-kube-all-nodes.revision | int | `1` |  |
| grafana.dashboards.urbanos.urban-os-overview.datasource | string | `"Prometheus"` |  |
| grafana.dashboards.urbanos.urban-os-overview.gnetId | int | `14806` |  |
| grafana.dashboards.urbanos.urban-os-overview.revision | int | `1` |  |
| grafana.dashboards.urbanos.urban-os-phoenix-api-metrics.datasource | string | `"Prometheus"` |  |
| grafana.dashboards.urbanos.urban-os-phoenix-api-metrics.gnetId | int | `14811` |  |
| grafana.dashboards.urbanos.urban-os-phoenix-api-metrics.revision | int | `1` |  |
| grafana.dashboards.urbanos.urban-os-pipeline-health.datasource | string | `"Prometheus"` |  |
| grafana.dashboards.urbanos.urban-os-pipeline-health.gnetId | int | `14805` |  |
| grafana.dashboards.urbanos.urban-os-pipeline-health.revision | int | `1` |  |
| grafana.datasources."datasources.yaml".apiVersion | int | `1` |  |
| grafana.datasources."datasources.yaml".datasources[0].access | string | `"proxy"` |  |
| grafana.datasources."datasources.yaml".datasources[0].isDefault | bool | `true` |  |
| grafana.datasources."datasources.yaml".datasources[0].name | string | `"Prometheus"` |  |
| grafana.datasources."datasources.yaml".datasources[0].type | string | `"prometheus"` |  |
| grafana.datasources."datasources.yaml".datasources[0].url | string | `"http://monitoring-prometheus-server"` |  |
| grafana.fullnameOverride | string | `"monitoring-grafana"` |  |
| grafana.rbac.namespaced | bool | `true` |  |
| grafana.securityContext.fsGroup | int | `1000` |  |
| grafana.securityContext.runAsGroup | int | `1000` |  |
| grafana.securityContext.runAsUser | int | `1000` |  |
| grafana.service.enabled | bool | `true` |  |
| grafana.service.type | string | `"NodePort"` |  |
| grafana.serviceAccount.create | bool | `false` |  |
| grafana.serviceAccount.name | string | `"default"` |  |
| grafana.sidecar.dashboards.enabled | bool | `true` |  |
| grafanaIngress.annotations | object | `{}` |  |
| prometheus.kube-state-metrics.enabled | bool | `false` |  |
| prometheus.prometheus-pushgateway.enabled | bool | `false` |  |
| prometheus.server.fullnameOverride | string | `"monitoring-prometheus-server"` |  |
| prometheus.server.namespaces[0] | string | `nil` |  |
| prometheus.server.resources.limits.cpu | string | `"500m"` |  |
| prometheus.server.resources.limits.memory | string | `"1Gi"` |  |
| prometheus.server.resources.requests.cpu | string | `"250m"` |  |
| prometheus.server.resources.requests.memory | string | `"500Mi"` |  |
| prometheus.server.securityContext.fsGroup | int | `1000` |  |
| prometheus.server.securityContext.runAsGroup | int | `1000` |  |
| prometheus.server.securityContext.runAsUser | int | `1000` |  |
| prometheus.server.useExistingClusterRoleName | string | `"prometheus-admin-cluster-role"` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[0].name | string | `"Sites"` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[0].rules[0].alert | string | `"SiteDown"` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[0].rules[0].annotations.description | string | `"{{ $labels.instance }} of job {{ $labels.job }} has been down for more than 2 minutes."` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[0].rules[0].annotations.summary | string | `"Instance {{ $labels.instance }} down"` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[0].rules[0].expr | string | `"probe_success == 0"` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[0].rules[0].for | string | `"2m"` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[0].rules[0].labels.severity | string | `"error"` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[1].name | string | `"api_status"` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[1].rules[0].alert | string | `"APIStatusDown"` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[1].rules[0].annotations.description | string | `"{{ $labels.instance }} of job {{ $labels.job }} has been down for more than 1 minutes."` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[1].rules[0].annotations.summary | string | `"Instance {{ $labels.instance }} down"` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[1].rules[0].expr | string | `"probe_success == 0"` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[1].rules[0].for | string | `"1m"` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[1].rules[0].labels.severity | string | `"error"` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[2].name | string | `"api_response"` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[2].rules[0].alert | string | `"APIResponseTime"` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[2].rules[0].annotations.description | string | `"{{ $labels.instance }} of job {{ $labels.job }} is taking more than 3 seconds."` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[2].rules[0].annotations.summary | string | `"Instance {{ $labels.instance }} is taking longer response time"` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[2].rules[0].expr | string | `"probe_duration_seconds > 3"` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[2].rules[0].for | string | `"1m"` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[2].rules[0].labels.severity | string | `"error"` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[3].name | string | `"K8S_Nodes"` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[3].rules[0].alert | string | `"LowMemory"` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[3].rules[0].annotations.description | string | `"{{ $labels.instance }} has {{ $value }} percent memory left."` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[3].rules[0].annotations.summary | string | `"Low Memory on Instance {{ $labels.instance }}"` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[3].rules[0].expr | string | `"(node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes * 100) < 20"` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[3].rules[0].for | string | `"5m"` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[3].rules[0].labels.severity | string | `"warning"` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[3].rules[1].alert | string | `"LowDisk"` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[3].rules[1].annotations.description | string | `"{{ $labels.instance }} has {{ $value }} percent disk left."` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[3].rules[1].annotations.summary | string | `"Low Disk on Instance {{ $labels.instance }}"` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[3].rules[1].expr | string | `"(node_filesystem_avail_bytes{device=~\"/dev/.*\"} / node_filesystem_size_bytes{device=~\"/dev/.*\"} * 100) < 15"` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[3].rules[1].for | string | `"5m"` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[3].rules[1].labels.severity | string | `"warning"` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[3].rules[2].alert | string | `"LowClusterCPU"` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[3].rules[2].annotations.description | string | `"Kubernetes cluster has {{ $value }} cores left. New deployments and cron jobs may fail to launch."` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[3].rules[2].annotations.summary | string | `"Kubernetes cluster low on CPU cores"` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[3].rules[2].expr | string | `"(cluster:capacity_cpu:sum - cluster:guarantees_cpu:sum) < 1"` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[3].rules[2].labels.severity | string | `"warning"` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[3].rules[3].alert | string | `"LowClusterMemory"` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[3].rules[3].annotations.description | string | `"Kubernetes cluster has {{ $value | humanize }} memory left. New deployments and cron jobs may fail to launch."` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[3].rules[3].annotations.summary | string | `"Kubernetes cluster has less than {{ 1000000000.0 | humanize }} memory available"` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[3].rules[3].expr | string | `"(cluster:capacity_memory_bytes:sum - cluster:guarantees_memory_bytes:sum) < 1000000000"` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[3].rules[3].labels.severity | string | `"warning"` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[3].rules[4].alert | string | `"NotReady"` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[3].rules[4].annotations.description | string | `"{{ $labels.node }} is not ready"` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[3].rules[4].annotations.summary | string | `"Status not Ready on Node {{ $labels.node }}"` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[3].rules[4].expr | string | `"kube_node_status_condition{condition=\"Ready\", status=\"true\"} != 1"` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[3].rules[4].labels.severity | string | `"error"` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[4].name | string | `"consumer_group_event_stream_lag"` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[4].rules[0].alert | string | `"ConsumerGroupEventStreamLag"` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[4].rules[0].annotations.description | string | `"The lag for consumer group {{ $labels.consumergroup }} is {{ humanize $value }}."` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[4].rules[0].annotations.summary | string | `"Consumer Group lag for topic {{ $labels.topic }} is greater than 10,000"` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[4].rules[0].expr | string | `"pipeline:event_stream:lag > 10000"` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[4].rules[0].labels.severity | string | `"warning"` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[5].name | string | `"low_disk_space"` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[5].rules[0].alert | string | `"LowDiskSpace"` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[5].rules[0].annotations.description | string | `"Low disk space for Server {{ $labels.persistentvolumeclaim }}, only {{ $value | printf \"%.2f\" }}% space is left."` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[5].rules[0].annotations.summary | string | `"Server disk space is below 15%"` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[5].rules[0].expr | string | `"(kubelet_volume_stats_available_bytes / kubelet_volume_stats_capacity_bytes * 100)  < 15"` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[5].rules[0].labels.severity | string | `"warning"` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[6].name | string | `"rule_failure"` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[6].rules[0].alert | string | `"RuleFailure"` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[6].rules[0].annotations.description | string | `"One of the recording rules defined in Prometheus has failed to execute. This is often due to issues with info metrics, but may have other causes. Look at the rules section of the Prometheus interface for more info."` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[6].rules[0].annotations.summary | string | `"Prometheus has failed to precalculate one or more metrics"` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[6].rules[0].expr | string | `"rate(prometheus_rule_evaluation_failures_total{rule_group=~\".*rules.*\"}[2m]) > 0"` |  |
| prometheus.serverFiles."alerting_rules.yml".groups[6].rules[0].labels.severity | string | `"warning"` |  |
| prometheus.serviceAccounts.server.create | bool | `false` |  |
| prometheus.serviceAccounts.server.name | string | `"default"` |  |
| prometheusIngress.annotations | object | `{}` |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.12.0](https://github.com/norwoodj/helm-docs/releases/v1.12.0)
