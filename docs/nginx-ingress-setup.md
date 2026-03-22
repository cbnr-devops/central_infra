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

### How the Nginx Controller Picks Up Ingress Rules Across Namespaces

A common question: the Ingress resource lives in the `default` namespace, but the nginx controller pod runs in the `ingress-nginx` namespace — how does it work?

The Ingress resource is just a **configuration object** stored in the Kubernetes API. It doesn't execute anything on its own. When the nginx controller pod starts, it's configured to **watch for Ingress resources across all namespaces** via the Kubernetes API.

```
ingress-nginx namespace                default namespace
┌──────────────────────────┐           ┌─────────────────────────────────┐
│ nginx controller pod     │──watches──→│ Ingress: shared-ingress-staging │
│                          │           │ Service: starship-fleet-service  │
│ (generates nginx.conf    │           │ Service: solar-system-service    │
│  and reloads nginx)      │           └─────────────────────────────────┘
└──────────────────────────┘
```

The flow:
1. You create the Ingress in the `default` namespace
2. The nginx controller pod (in `ingress-nginx` namespace) **detects it** via the Kubernetes API
3. It reads the annotations (`rewrite-target: /$2`) and the routing rules
4. It **generates an nginx.conf** inside its pod and reloads nginx
5. This is visible in the controller logs as:
   ```
   "Configuration changes detected, backend reload required"
   "Backend successfully reloaded"
   ```

The namespace of the Ingress only matters for **finding the backend services** — the Ingress in `default` namespace can only reference services in the `default` namespace.

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

### End-to-End Request Flow Comparison

**ALB Ingress (original setup)**

```
Internet
   ↓
ALB (created by your ingress.yaml)  ← scheme, target-type, health-check all in ingress.yaml
   ↓
/starfleet → forwards /starfleet as-is (no rewrite possible)
   ↓
starship-fleet-service (port 80) → Pod (port 8000)
   ↓
App receives /starfleet → 404 (no such route)
```

One resource (`ingress.yaml`) controls everything — the ALB creation, its scheme, and routing.

**Nginx Ingress (current setup)**

```
Internet
   ↓
NLB (created by ingress-nginx-controller Service)  ← scheme annotation lives on this Service
   ↓
Nginx Controller Pod (reads your ingress.yaml)      ← routing + rewrite rules live in ingress.yaml
   ↓
/starfleet/live → rewrite-target strips prefix → /live
   ↓
starship-fleet-service (port 80) → Pod (port 8000)
   ↓
App receives /live → 200 ✓
```

Two resources:
- **Controller's Service** → creates and configures the NLB (public/private)
- **Your `ingress.yaml`** → only defines routing and rewrite rules

**The key difference**

- **ALB**: Ingress → creates LB → routes traffic (all-in-one, but no path rewriting)
- **Nginx**: Service → creates NLB → forwards TCP to nginx pod → nginx reads Ingress → rewrites path → routes traffic (split across two resources, but supports rewriting)
