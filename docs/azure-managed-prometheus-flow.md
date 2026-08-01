# Azure Managed Prometheus Flow

This setup has three layers: Terraform-managed Azure resources, Azure's built-in Kubernetes scraping, and repo-managed custom scrape configuration.

## 1. Terraform Links AKS, Prometheus, and Grafana

Terraform creates and connects:

```text
AKS dev-cluster
  -> Azure Monitor Workspace dev-monitor-workspace
  -> Azure Managed Grafana dev-grafana
```

Important resources:

- `azurerm_monitor_workspace`: stores Managed Prometheus metrics.
- `azurerm_monitor_data_collection_rule`: defines the Prometheus metrics flow.
- `azurerm_monitor_data_collection_rule_association`: attaches that flow to `dev-cluster`.
- `azurerm_dashboard_grafana`: creates Azure Managed Grafana.
- `azure_monitor_workspace_integrations`: adds the Prometheus workspace as a Grafana data source.
- `Monitoring Data Reader` role: lets Grafana read metrics from the workspace.

This is why Grafana has the data source:

```text
Managed_Prometheus_dev-monitor-workspace
```

## 2. Azure Automatically Scrapes Kubernetes Metrics

The AKS module enables the Azure Monitor metrics add-on:

```hcl
monitor_metrics {
  annotations_allowed = null
  labels_allowed      = null
}
```

Azure then runs the `ama-metrics` collector inside AKS and scrapes standard Kubernetes targets such as:

- kubelet
- cAdvisor
- node exporter
- kube-state-metrics
- CoreDNS

That is why Grafana automatically shows Microsoft-managed dashboards under:

```text
Azure Managed Prometheus
```

Examples:

- `Kubernetes / Kubelet`
- `Node Exporter / Nodes`
- `Kubernetes / Networking / DNS`
- `Overview`

## 3. What `kubernetes/monitoring` YAML Files Do

These files are for custom scrape behavior, mainly application metrics.

### `ama-metrics-settings-configmap.yaml`

Configures the Azure Monitor Prometheus collector in `kube-system`.

It enables app scrape support for the `dev` namespace:

```text
pod annotation based scraping -> enabled
namespaces -> dev
```

It also keeps standard cluster targets enabled, such as kubelet, cAdvisor, kube-state-metrics, node exporter, and CoreDNS.

### `solar-starfleet-servicemonitors.yaml`

Defines `ServiceMonitor` resources for:

- `solar-system`
- `starship-fleet`

Each monitor tells Azure Managed Prometheus:

```text
Find the matching Kubernetes Service.
Scrape /metrics every 30 seconds.
Send the metrics to dev-monitor-workspace.
```

This only works when the services expose Prometheus metrics on `/metrics` and have the expected labels and named `metrics` port.

## Short Summary

```text
Terraform
  Creates and links AKS, Azure Monitor Workspace, and Grafana.

Azure built-in collector
  Scrapes Kubernetes cluster metrics automatically.

kubernetes/monitoring YAML
  Adds or customizes app-level scraping for solar-system and starship-fleet.
```

Cluster dashboards appeared automatically because Azure knows how to collect standard Kubernetes metrics. Application request/error/latency dashboards require the apps to expose Prometheus metrics such as `http_requests_total` and `http_request_duration_seconds_bucket`.
