# Azure Managed Prometheus and Grafana for dev-cluster

This repo already provisions the Azure Monitor workspace, Azure Managed Grafana, the AKS metrics add-on, and the Prometheus data collection rule in `terraform/azure/modules/monitoring`.

## 1. Apply or refresh the Azure infrastructure

```bash
cd terraform/azure/envs/dev
terraform init
terraform plan
terraform apply
```

Expected Azure resources:

- AKS: `dev-cluster`
- Azure Monitor workspace: `dev-monitor-workspace`
- Azure Managed Grafana: `dev-grafana`
- Resource group: `central-dev-rg`

## 2. Confirm Grafana can read Managed Prometheus

In Azure Portal:

1. Open `dev-monitor-workspace`.
2. Go to Access control (IAM).
3. Confirm the managed identity for `dev-grafana` has `Monitoring Data Reader`.
4. Open `dev-grafana`.
5. Go to Integrations > Azure Monitor workspaces.
6. Confirm `dev-monitor-workspace` is connected.

Azure creates a Prometheus data source in Grafana for the Azure Monitor workspace.

## 3. Enable application scraping in AKS

Apply the Azure Monitor metrics settings ConfigMap:

```bash
az aks get-credentials \
  --resource-group central-dev-rg \
  --name dev-cluster \
  --overwrite-existing

kubectl apply -f kubernetes/monitoring/ama-metrics-settings-configmap.yaml
```

The Azure Monitor metrics pods usually restart within a few minutes.

## 4. Expose service metrics

Each application should expose Prometheus metrics at `/metrics`.

For the ServiceMonitor manifests in this repo to work, the Kubernetes services must have:

```yaml
metadata:
  labels:
    app: solar-system
spec:
  ports:
    - name: metrics
      port: 80
      targetPort: 80
```

and:

```yaml
metadata:
  labels:
    app: starship-fleet
spec:
  ports:
    - name: metrics
      port: 8000
      targetPort: 8000
```

Apply the monitors:

```bash
kubectl apply -f kubernetes/monitoring/solar-starfleet-servicemonitors.yaml
```

If your services use different labels or ports, update the `selector.matchLabels` and `endpoints.port` values first.

## 5. Validate ingestion

Check the collector:

```bash
kubectl get pods -n kube-system -l rsName=ama-metrics
kubectl get servicemonitor -n dev
```

In Grafana, open Explore and run:

```promql
up{cluster="dev-cluster"}
```

Then narrow to the apps:

```promql
up{cluster="dev-cluster", namespace="dev"}
```

Useful starter queries:

```promql
sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="dev"}[5m]))
sum by (pod) (container_memory_working_set_bytes{namespace="dev"})
sum by (pod) (rate(kube_pod_container_status_restarts_total{namespace="dev"}[5m]))
sum by (service) (rate(http_requests_total{namespace="dev"}[5m]))
histogram_quantile(0.95, sum by (le, service) (rate(http_request_duration_seconds_bucket{namespace="dev"}[5m])))
```

The last two require your applications to emit `http_requests_total` and `http_request_duration_seconds_bucket`.

## 6. Build dashboards

Start with the built-in dashboards under Grafana's `Managed Prometheus` folder:

- `Kubernetes / Compute Resources / Cluster`
- `Kubernetes / Compute Resources / Namespace (Pods)`
- `Kubernetes / Compute Resources / Workload`
- `Node Exporter / Nodes`

Create a custom `Solar + Starfleet` folder with these panels:

- Cluster health: `up`, node CPU, node memory, pod restarts.
- Solar service: request rate, error rate, p95 latency, pod CPU/memory.
- Starfleet service: request rate, error rate, p95 latency, pod CPU/memory.
- Database-facing view: app latency/error panels filtered by routes that touch PostgreSQL.

## 7. Recommended app metrics

Instrument both services with:

- `http_requests_total{service, method, route, status}`
- `http_request_duration_seconds_bucket{service, method, route}`
- `process_cpu_seconds_total`
- `process_resident_memory_bytes`
- app-specific counters such as `solar_planet_requests_total` and `starfleet_ship_requests_total`

Keep labels low-cardinality. Avoid labels such as raw URL, user ID, request ID, or unbounded object names.
