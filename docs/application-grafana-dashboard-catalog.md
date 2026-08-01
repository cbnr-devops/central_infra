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
| Request Rate | `sum(rate(http_requests_total{namespace="$namespace", service="$service"}[5m]))` | Time series | Unit: `req/s` |
| Request Rate by Route | `sum by (route) (rate(http_requests_total{namespace="$namespace", service="$service"}[5m]))` | Time series | Legend: `{{route}}` |
| Request Rate by Method | `sum by (method) (rate(http_requests_total{namespace="$namespace", service="$service"}[5m]))` | Bar chart | Good for GET/POST split |
| Error Rate | `sum(rate(http_requests_total{namespace="$namespace", service="$service", status=~"5.."}[5m]))` | Time series | Unit: `req/s` |
| Error Percentage | `100 * sum(rate(http_requests_total{namespace="$namespace", service="$service", status=~"5.."}[5m])) / sum(rate(http_requests_total{namespace="$namespace", service="$service"}[5m]))` | Gauge | Unit: `percent` |
| p95 Latency | `histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket{namespace="$namespace", service="$service"}[5m])))` | Time series | Unit: `seconds` |
| p99 Latency | `histogram_quantile(0.99, sum by (le) (rate(http_request_duration_seconds_bucket{namespace="$namespace", service="$service"}[5m])))` | Time series | Unit: `seconds` |

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
