# Azure Managed Prometheus and Grafana for dev-cluster

This repo already provisions the Azure Monitor workspace, Azure Managed Grafana, the AKS metrics add-on, and the Prometheus data collection rule in `terraform/azure/modules/monitoring`.

## 1. Confirm Grafana can read Managed Prometheus

In Azure Portal:

1. Open `dev-monitor-workspace`.
2. Go to Access control (IAM).
3. Confirm the managed identity for `dev-grafana` has `Monitoring Data Reader`.
4. Open `dev-grafana`.
5. Go to Integrations > Azure Monitor workspaces.
6. Confirm `dev-monitor-workspace` is connected.

Azure creates a Prometheus data source in Grafana for the Azure Monitor workspace.

## 2. Enable application scraping in AKS and Service Monitors

Apply the Azure Monitor metrics settings ConfigMap:

```bash
kubectl apply -f kubernetes/monitoring/ama-metrics-settings-configmap.yaml
```

Apply the monitors:

```bash
kubectl apply -f kubernetes/monitoring/solar-starfleet-servicemonitors.yaml
```

# Application Grafana Dashboard Catalog

Use one Grafana folder per service:

```text
Dashboards
├── Solar System Service
│   ├── Service Overview
│   ├── HTTP Performance
│   ├── Pods & Resources
│   └── Errors & Reliability
└── Starship Fleet Service
    ├── Service Overview
    ├── HTTP Performance
    ├── Pods & Resources
    └── Errors & Reliability
```

Use the `Managed_Prometheus_dev-monitor-workspace` data source for all PromQL panels.

Replace `$service` with one of:

```text
solar-system
starship-fleet
```

## Dashboard Variables

Create these variables in each dashboard.

### `namespace`

Query:

```promql
label_values(kube_pod_info, namespace)
```

Default:

```text
dev
```

### `service`

Use a custom value per service dashboard for pod-name matching:

```text
solar-system
```

or:

```text
starship-fleet
```

### `k8s_service`

Use the Kubernetes Service name stored in the Prometheus `service` label:

```text
solar-system-service
```

or:

```text
starship-fleet-service
```

### `pod`

Query:

```promql
label_values(kube_pod_info{namespace="$namespace", pod=~"$service.*"}, pod)
```

Recommended dashboard settings:

- Time range: `Last 1 hour`
- Refresh: `30s`
- Data source: `Managed_Prometheus_dev-monitor-workspace`

## 1. Service Overview

Main summary dashboard for each service.

| Panel | PromQL | Visualization | Settings |
|---|---|---|---|
| Service Up | `count(container_cpu_usage_seconds_total{namespace="$namespace", pod=~"$service.*", container!="", image!=""})` | Stat | Thresholds: `0` red, `1+` green |
| Running Pods | `sum(kube_pod_status_phase{namespace="$namespace", pod=~"$service.*", phase="Running"})` | Stat | Unit: `short` |
| CPU Usage | `sum(rate(container_cpu_usage_seconds_total{namespace="$namespace", pod=~"$service.*", container!="", image!=""}[5m]))` | Time series | Unit: `cores` |
| Memory Usage | `sum(container_memory_working_set_bytes{namespace="$namespace", pod=~"$service.*", container!="", image!=""})` | Time series | Unit: `bytes` |
| Pod Restarts | `sum(increase(kube_pod_container_status_restarts_total{namespace="$namespace", pod=~"$service.*"}[1h]))` | Stat | Thresholds: `0` green, `1+` red |
| Pods Ready | `sum(kube_pod_status_phase{namespace="$namespace", pod=~"$service.*", phase="Running"})` | Gauge | Min: `0`, max: expected replicas |

Suggested top row:

```text
[Service Up] [Running Pods] [Request Rate] [Error %] [p95 Latency] [Restarts]
```

## 2. HTTP Performance

Use this dashboard when the application exposes Prometheus HTTP metrics.

| Panel | PromQL | Visualization | Settings |
|---|---|---|---|
| Request Rate | `sum(rate(http_requests_total{namespace="$namespace", service="$k8s_service"}[5m]))` | Time series | Unit: `req/s` |
| Request Rate by Route | `sum by (route) (rate(http_requests_total{namespace="$namespace", service="$k8s_service"}[5m]))` | Time series | Legend: `{{route}}` |
| Request Rate by Method | `sum by (method) (rate(http_requests_total{namespace="$namespace", service="$k8s_service"}[5m]))` | Bar chart | Good for GET/POST split |
| Error Rate | `sum(rate(http_requests_total{namespace="$namespace", service="$k8s_service", status=~"5.."}[5m])) or vector(0)` | Time series | Unit: `req/s` |
| Error Percentage | `100 * (sum(rate(http_requests_total{namespace="$namespace", service="$k8s_service", status=~"5.."}[5m])) or vector(0)) / sum(rate(http_requests_total{namespace="$namespace", service="$k8s_service"}[5m]))` | Gauge | Unit: `percent` |
| p95 Latency | `histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket{namespace="$namespace", service="$k8s_service"}[5m])))` | Time series | Unit: `seconds` |
| p99 Latency | `histogram_quantile(0.99, sum by (le) (rate(http_request_duration_seconds_bucket{namespace="$namespace", service="$k8s_service"}[5m])))` | Time series | Unit: `seconds` |

Error percentage gauge thresholds:

```text
0-1%   green
1-5%   yellow
5%+    red
```

Latency thresholds:

```text
0-250ms     green
250ms-1s    yellow
1s+         red
```

## 3. Pods & Resources

Use this dashboard to debug pod and container runtime behavior.

| Panel | PromQL | Visualization | Settings |
|---|---|---|---|
| CPU by Pod | `sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="$namespace", pod=~"$service.*", container!="", image!=""}[5m]))` | Time series | Legend: `{{pod}}`, unit: `cores` |
| Memory by Pod | `sum by (pod) (container_memory_working_set_bytes{namespace="$namespace", pod=~"$service.*", container!="", image!=""})` | Time series | Legend: `{{pod}}`, unit: `bytes` |
| CPU by Container | `sum by (pod, container) (rate(container_cpu_usage_seconds_total{namespace="$namespace", pod=~"$service.*", container!="", image!=""}[5m]))` | Time series | Legend: `{{pod}} / {{container}}`, unit: `cores` |
| Memory by Container | `sum by (pod, container) (container_memory_working_set_bytes{namespace="$namespace", pod=~"$service.*", container!="", image!=""})` | Time series | Legend: `{{pod}} / {{container}}`, unit: `bytes` |
| Network Receive | `sum by (pod) (rate(container_network_receive_bytes_total{namespace="$namespace", pod=~"$service.*"}[5m]))` | Time series | Unit: `bytes/sec` |
| Network Transmit | `sum by (pod) (rate(container_network_transmit_bytes_total{namespace="$namespace", pod=~"$service.*"}[5m]))` | Time series | Unit: `bytes/sec` |
| Pod Phase | `sum by (phase) (kube_pod_status_phase{namespace="$namespace", pod=~"$service.*"})` | Bar chart or pie chart | Shows Running/Pending/Failed |

## 4. Errors & Reliability

Use this dashboard to answer whether the service is healthy.

For $k8s_service --> solar-system-service or starship-fleet-service

| Panel | PromQL | Visualization | Settings |
|---|---|---|---|
| 4xx Rate | `sum(rate(http_requests_total{namespace="$namespace", service="$k8s_service", status=~"4.."}[5m])) or vector(0)` | Time series | Client/API usage issues |
| 5xx Rate | `sum(rate(http_requests_total{namespace="$namespace", service="$k8s_service", status=~"5.."}[5m])) or vector(0)` | Time series | Server/service issues |
| Errors by Route | `sum by (route, status) (rate(http_requests_total{namespace="$namespace", service="$k8s_service", status=~"4..|5.."}[5m]))` | Bar chart | Legend: `{{route}} {{status}}` |
| Restarts by Pod | `sum by (pod) (increase(kube_pod_container_status_restarts_total{namespace="$namespace", pod=~"$service.*"}[1h]))` | Bar chart | Red when non-zero |
| Not Ready Pods | `sum(kube_pod_status_phase{namespace="$namespace", pod=~"$service.*", phase!="Running"}) or vector(0)` | Stat | Thresholds: `0` green, `1+` red |
| Container Waiting Reasons | `sum(kube_pod_container_status_waiting_reason{namespace="$namespace", pod=~"$service.*"}) or vector(0)` | Stat | Thresholds: `0` green, `1+` red |


## Suggested Overview Layout

Use this layout for the first service dashboard in each folder:

```text
Row 1:
[Service Up] [Running Pods] [Request Rate] [Error %] [p95 Latency] [Restarts]

Row 2:
[CPU Usage over Time] [Memory Usage over Time]

Row 3:
[Request Rate by Route] [Latency p95/p99]

Row 4:
[Errors by Route] [Pod Restarts]
```

## Required Application Metrics

Kubernetes CPU, memory, pod phase, readiness, and restart queries work from AKS/Managed Prometheus metrics.

HTTP request, error, and latency panels require the applications to expose metrics such as:

```text
http_requests_total{service, method, route, status}
http_request_duration_seconds_bucket{service, method, route}
process_cpu_seconds_total
process_resident_memory_bytes
solar_planet_requests_total
starfleet_ship_requests_total
```

Keep labels low-cardinality. Avoid labels such as raw URL, user ID, request ID, or unbounded object names.

# PostgreSQL Database Dashboard Catalog

Create a separate Grafana folder:

```text
PostgreSQL Database
```

Use the `Azure Monitor` data source for Azure PostgreSQL server metrics:

```text
Service: Microsoft.DBforPostgreSQL/flexibleServers
Resource group: central-dev-rg
Resource: dev-solar-postgres
```

Use `Managed_Prometheus_dev-monitor-workspace` only for app-to-DB metrics emitted by the solar-system and starship-fleet apps.

## 1. PostgreSQL / Overview

| Panel | Azure Metric | Visualization | Settings |
|---|---|---|---|
| DB Alive | `is_db_alive` | Stat | `1` green, `0` red |
| CPU % | `cpu_percent` | Gauge | Green < 70, yellow 70-85, red > 85 |
| Memory % | `memory_percent` | Gauge | Green < 70, yellow 70-85, red > 85 |
| Storage % | `storage_percent` | Gauge | Green < 70, yellow 70-85, red > 85 |
| Active Connections | `active_connections` | Stat | Current connection count |
| Failed Connections | `connections_failed` | Time series | Aggregation: `Sum` |

## 2. PostgreSQL / Connections

| Panel | Azure Metric | Visualization | Settings |
|---|---|---|---|
| Active Connections | `active_connections` | Time series | Aggregation: average |
| Successful Connections | `connections_succeeded` | Time series | Aggregation: sum |
| Failed Connections | `connections_failed` | Time series | Aggregation: sum |
| Max Connections | `max_connections` | Stat | Unit: short |
| Sessions by State | `sessions_by_state` | Bar chart or time series | Split by `State` |
| Sessions by Wait Event | `sessions_by_wait_event_type` | Bar chart or table | Split by `WaitEventType` |

## 3. PostgreSQL / Performance

| Panel | Azure Metric | Visualization | Settings |
|---|---|---|---|
| CPU Usage | `cpu_percent` | Time series | Unit: percent |
| Memory Usage | `memory_percent` | Time series | Unit: percent |
| Oldest Query | `longest_query_time_sec` | Stat or time series | Unit: seconds |
| Oldest Transaction | `longest_transaction_time_sec` | Stat or time series | Unit: seconds |
| Oldest Backend | `oldest_backend_time_sec` | Time series | Unit: seconds |
| Transaction ID Usage | `maximum_used_transactionIDs` | Gauge | Watch for wraparound risk |

## 4. PostgreSQL / Storage

| Panel | Azure Metric | Visualization | Settings |
|---|---|---|---|
| Storage Used | `storage_used` | Time series | Unit: bytes |
| Storage Free | `storage_free` | Stat or time series | Unit: bytes |
| Storage % | `storage_percent` | Gauge | Green < 70, yellow 70-85, red > 85 |
| Backup Storage Used | `backup_storage_used` | Time series | Unit: bytes |
| Transaction Log Storage | `txlogs_storage_used` | Time series | Unit: bytes |
| Database Size | `database_size_bytes` | Time series | Unit: bytes |

## 5. PostgreSQL / IO & Network

| Panel | Azure Metric | Visualization | Settings |
|---|---|---|---|
| IOPS | `iops` | Time series | Unit: ops/sec |
| Read IOPS | `read_iops` | Time series | Unit: ops/sec |
| Write IOPS | `write_iops` | Time series | Unit: ops/sec |
| Disk Queue Depth | `disk_queue_depth` | Time series | Unit: short |
| Read Throughput | `read_throughput` | Time series | Unit: bytes/sec |
| Write Throughput | `write_throughput` | Time series | Unit: bytes/sec |
| Network In | `network_bytes_ingress` | Time series | Unit: bytes |
| Network Out | `network_bytes_egress` | Time series | Unit: bytes |

## 6. PostgreSQL / Reliability

| Panel | Azure Metric | Visualization | Settings |
|---|---|---|---|
| DB Alive | `is_db_alive` | Stat | `1` green, `0` red |
| Failed Connections | `connections_failed` | Time series | Aggregation: sum |
| Deadlocks | `deadlocks` | Stat or time series | Threshold: `0` green, `1+` red |
| CPU Saturation | `cpu_percent` | Gauge | Green < 70, yellow 70-85, red > 85 |
| Memory Saturation | `memory_percent` | Gauge | Green < 70, yellow 70-85, red > 85 |
| Storage Saturation | `storage_percent` | Gauge | Green < 70, yellow 70-85, red > 85 |
| Disk IOPS Consumed % | `disk_iops_consumed_percentage` | Gauge | Green < 70, yellow 70-85, red > 85 |
| Disk Bandwidth Consumed % | `disk_bandwidth_consumed_percentage` | Gauge | Green < 70, yellow 70-85, red > 85 |

## 7. PostgreSQL / App DB Calls

These panels use Managed Prometheus because the metrics come from the application code.

### Solar System

| Panel | PromQL | Visualization | Settings |
|---|---|---|---|
| DB Lookup Rate | `rate(planet_db_lookup_duration_seconds_count{namespace="dev"}[5m])` | Time series | Unit: ops/sec |
| p95 DB Lookup Latency | `histogram_quantile(0.95, sum by (le) (rate(planet_db_lookup_duration_seconds_bucket{namespace="dev"}[5m])))` | Time series | Unit: seconds |
| DB Lookup Errors | `sum(rate(planet_db_lookup_errors_total{namespace="dev"}[5m])) or vector(0)` | Stat or time series | Threshold: `0` green, `>0` red |
| Data Source Split | `sum by (source) (rate(planet_data_source_total{namespace="dev"}[5m]))` | Bar chart or time series | Shows DB vs JSON fallback |

### Starship Fleet

| Panel | PromQL | Visualization | Settings |
|---|---|---|---|
| DB Lookup Rate | `rate(starship_db_lookup_duration_seconds_count{namespace="dev"}[5m])` | Time series | Unit: ops/sec |
| p95 DB Lookup Latency | `histogram_quantile(0.95, sum by (le) (rate(starship_db_lookup_duration_seconds_bucket{namespace="dev"}[5m])))` | Time series | Unit: seconds |
| DB Lookup Errors | `sum(rate(starship_db_lookup_errors_total{namespace="dev"}[5m])) or vector(0)` | Stat or time series | Threshold: `0` green, `>0` red |
| Data Source Split | `sum by (source) (rate(starship_data_source_total{namespace="dev"}[5m]))` | Bar chart or time series | Shows DB vs JSON fallback |
