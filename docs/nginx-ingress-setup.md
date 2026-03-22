# Nginx Ingress Setup for Staging Cluster

## Problem

We have two apps (solar-system and starship-fleet) sharing a single ingress on the EKS staging cluster (`arn:aws:eks:ap-southeast-2:312018064574:cluster/staging-cluster`). Both apps serve their homepage on `/`, so we need path-based routing with prefix stripping.

### Why not ALB?

We initially used the AWS ALB ingress controller, but ALB **does not support path rewriting**. When routing `/starfleet/live` to the starship-fleet app, the ALB forwards the full path `/starfleet/live` — the app only knows `/live`, so it returns 404.

## Solution: Nginx Ingress Controller

Nginx ingress supports `rewrite-target`, which strips the path prefix before forwarding to the backend.

### Architecture

```
Internet
   ↓
NLB (internet-facing, created by ingress-nginx-controller Service)
   ↓
Nginx Controller Pod (reads Ingress rules)
   ↓
/starfleet/live → rewrite → /live → starship-fleet-service → Pod (port 8000)
/solar/info     → rewrite → /info → solar-system-service    → Pod (port 80)
```

### Two Resources Involved

| Resource | Namespace | Purpose |
|---|---|---|
| `ingress-nginx-controller` Service | `ingress-nginx` | Creates the NLB, controls public/private access |
| `shared-ingress-staging` Ingress | `default` | Defines routing rules and path rewriting |

## Installation

### 1. Install Nginx Ingress Controller

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.12.0/deploy/static/provider/aws/deploy.yaml
```

### 2. Make the NLB Internet-Facing

By default, the NLB is internal (private IPs). To make it publicly accessible:

```bash
kubectl annotate svc -n ingress-nginx ingress-nginx-controller \
  service.beta.kubernetes.io/aws-load-balancer-scheme=internet-facing --overwrite
```

### 3. Apply the Ingress

```bash
kubectl apply -f ingress.yaml
```

## How Path Rewriting Works

The annotation `nginx.ingress.kubernetes.io/rewrite-target: /$2` works with regex capture groups in the path.

```yaml
path: /starfleet(/|$)(.*)
```

| Part | Meaning |
|---|---|
| `/starfleet` | Literal prefix match |
| `(/\|$)` | Capture group `$1` — matches `/` or end of string |
| `(.*)` | Capture group `$2` — matches everything after the prefix |

### Rewrite Examples

| Incoming Request | $2 (captured) | Rewritten To |
|---|---|---|
| `/starfleet/live` | `live` | `/live` |
| `/starfleet/starship` | `starship` | `/starship` |
| `/starfleet/` | (empty) | `/` |
| `/starfleet` | (empty) | `/` |

## Verification

```bash
# Check ingress status
kubectl get ingress shared-ingress-staging

# Check NLB is internet-facing with public IPs
aws elbv2 describe-load-balancers --query 'LoadBalancers[?contains(DNSName,`ingressn`)].{State:State.Code,Scheme:Scheme,DNS:DNSName}'

# Test routes
curl http://<NLB-DNS>/starfleet/live
curl http://<NLB-DNS>/solar/
```

## Key Differences: ALB vs Nginx Ingress

| | ALB Ingress | Nginx Ingress |
|---|---|---|
| Who creates the LB? | The Ingress resource | The controller's Service |
| LB type | ALB (Layer 7) | NLB (Layer 4) |
| LB config lives in | `ingress.yaml` | Controller's Service |
| Path rewriting | Not supported | Supported via `rewrite-target` |
| Scheme annotation | `alb.ingress.kubernetes.io/scheme` on Ingress | `service.beta.kubernetes.io/aws-load-balancer-scheme` on Service |
