# EKS Authentication & Access Control

## Why do we need auth and ConfigMap for EKS?

EKS clusters are created by AWS, but `kubectl` (and the Terraform `kubernetes` provider) don't automatically know how to talk to them. They need three things:

1. **`host`** — where is the cluster? (the API server endpoint)
2. **`cluster_ca_certificate`** — is this really my cluster? (TLS certificate to verify identity)
3. **`token`** — who am I? (proof that you're authorized)

Without authentication configured, `kubectl` has no credentials to present to the EKS API server. The cluster rejects requests because it doesn't know who you are.

### Terraform provider setup

```hcl
data "aws_eks_cluster" "cluster" {
  name = module.dev_cluster.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.dev_cluster.cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}
```

- **`aws_eks_cluster` data source** — fetches the cluster's endpoint URL and CA certificate from AWS
- **`aws_eks_cluster_auth` data source** — generates a short-lived authentication token using your AWS IAM identity
- **`kubernetes` provider** — passes all three to Terraform so it can create Kubernetes resources (like ConfigMaps) inside the cluster

The **`aws-auth` ConfigMap** maps AWS IAM roles/users to Kubernetes RBAC permissions. Without it, even authenticated AWS users can't do anything in the cluster.

---

## What happens when you type `kubectl get pods`

```
kubectl get pods
       │
       ▼
┌─────────────────────────┐
│  AWS IAM says:           │   ← Authentication (who are you?)
│  "This is ec2-cli-user"  │
└──────────┬──────────────┘
           ▼
┌─────────────────────────┐
│  aws-auth ConfigMap      │   ← Translation (IAM → K8s identity)
│  ec2-cli-user →          │
│  group: system:masters   │
└──────────┬──────────────┘
           ▼
┌─────────────────────────┐
│  K8s RBAC says:          │   ← Authorization (can you do this?)
│  system:masters =        │
│  full access ✓           │
└──────────┬──────────────┘
           ▼
      Pod list returned
```

### Step by step

1. **kubectl sends the request** — `~/.kube/config` tells kubectl where to send the request and how to authenticate (it runs `aws eks get-token` behind the scenes)
2. **EKS authenticates you** — The API server confirms: "This is AWS IAM user `ec2-cli-user`." But Kubernetes doesn't natively understand IAM users, so it needs a translation layer.
3. **The `aws-auth` ConfigMap translates** — Looks up your IAM ARN and maps it to a Kubernetes username and group
4. **Kubernetes RBAC authorizes** — Checks if your group (`system:masters`) has permission to list pods. `system:masters` is superadmin, so the answer is yes.
5. **Pod list returned**

---

## Key EKS module settings explained

### `cluster_endpoint_public_access = true`

Makes the Kubernetes API server reachable from the public internet. Anyone with valid credentials can call `kubectl` from anywhere.

- **OK for dev/learning:** Yes
- **OK for production:** No — use private access with VPN/bastion

### `manage_aws_auth_configmap = true`

Tells the EKS Terraform module to manage the `aws-auth` ConfigMap. This is good practice — managing it through Terraform means it's version-controlled, reproducible, and won't drift.

### `aws_auth_users` block

```hcl
aws_auth_users = [
  {
    userarn  = "arn:aws:iam::312018064574:user/ec2-cli-user"
    username = "ec2-cli-user"
    groups   = ["system:masters"]
  }
]
```

Grants the IAM user `ec2-cli-user` full cluster admin access. Issues with this approach:

1. **`system:masters` is too broad** — equivalent of root
2. **Hardcoded IAM user** — better to use IAM roles instead (temporary credentials, more flexible)

---

## Private endpoint access

Setting `cluster_endpoint_public_access = false` means the API server is only reachable from within the VPC. Your `kubectl` and Terraform commands would break unless you're inside the VPC.

### Options to make private access work

1. **Bastion host / jump box** — EC2 instance in the VPC, SSH in and run `kubectl`
2. **VPN** (e.g., AWS Client VPN) — Connect local machine to the VPC
3. **AWS SSM Session Manager** — Start a session on an instance inside the VPC
4. **CI/CD runner inside the VPC** — e.g., CodeBuild or GitHub Actions self-hosted runner

### Middle ground for dev

```hcl
cluster_endpoint_public_access       = true
cluster_endpoint_private_access      = true
cluster_endpoint_public_access_cidrs = ["<your-IP>/32"]
```

This restricts the public endpoint to only your IP — IP whitelisting (allowlisting).

---

## CIDR notation

CIDR (Classless Inter-Domain Routing) describes a range of IP addresses in compact notation.

### Format: `IP/number`

The number after `/` says how many bits are fixed. The remaining bits are flexible.

| CIDR            | Meaning                          | # of addresses |
| --------------- | -------------------------------- | -------------- |
| `10.0.0.5/32`  | Exactly **one** IP (10.0.0.5)   | 1              |
| `10.0.0.0/24`  | 10.0.0.**0 – 255**              | 256            |
| `10.0.0.0/16`  | 10.0.**0.0 – 255.255**          | 65,536         |
| `0.0.0.0/0`    | **Every** IP address             | All of them    |

The bigger the `/number`, the smaller the range.

### IP whitelisting

`cluster_endpoint_public_access_cidrs = ["<your-IP>/32"]` means "only this exact IP can reach the cluster's public endpoint." Same concept as whitelisting — only approved entities are allowed in.

This pattern shows up everywhere in AWS: Security Groups, S3 bucket policies, NACLs, etc.

---

## How large orgs handle access

### The typical stack

```
┌─────────────────────────────┐
│  SSO (Okta / Azure AD)      │  ← Who are you?
├─────────────────────────────┤
│  IAM Roles (per team)       │  ← What AWS identity do you get?
├─────────────────────────────┤
│  aws-auth ConfigMap         │  ← IAM Role → K8s group mapping
├─────────────────────────────┤
│  K8s RBAC (per namespace)   │  ← What can you do inside the cluster?
├─────────────────────────────┤
│  Private endpoint + VPN     │  ← Can you even reach the cluster?
└─────────────────────────────┘
```

### 1. Private endpoint + VPN/network access

The cluster endpoint is private only. Developers connect via corporate VPN.

### 2. IAM Roles (not users) + SSO

No long-lived IAM users. Each team gets an IAM role. Developers authenticate via SSO, which lets them assume their team's role with temporary credentials.

### 3. Scoped RBAC per team

Instead of everyone being `system:masters`, each team gets limited permissions:

| Team         | Can access             | Permissions                          |
| ------------ | ---------------------- | ------------------------------------ |
| Payments     | `payments` namespace   | Full CRUD on pods, deployments, etc. |
| Frontend     | `frontend` namespace   | Read-only                            |
| Platform/SRE | Everything             | Full admin                           |

### 4. Separate clusters per environment

- **dev** → more relaxed access, broader teams
- **staging** → tighter, fewer teams
- **production** → very restricted, SRE + CI/CD only

### 5. CI/CD has its own identity

Humans don't deploy to prod — pipelines do, with their own scoped IAM role.

---

## Where roles are defined (three layers)

```
1. IAM Roles        → standalone AWS resources (Terraform)
2. aws-auth mapping → inside the EKS module (Terraform)
3. RBAC rules       → separate Kubernetes resources (Terraform or YAML)
                      applied to the cluster after it's created
```

All three are independent but connected by **naming** — the group name in `aws-auth` (e.g., `"payments-team"`) must match the group name in the RBAC `RoleBinding` subject. That string is the glue.

### Layer 1: IAM Roles (AWS side)

```hcl
resource "aws_iam_role" "team_payments" {
  name = "team-payments-eks-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = "arn:aws:iam::123456:saml-provider/Okta"
      }
      Action = "sts:AssumeRoleWithSAML"
    }]
  })
}
```

### Layer 2: aws-auth ConfigMap (the bridge)

```hcl
aws_auth_roles = [
  {
    rolearn  = aws_iam_role.team_payments.arn
    username = "{{SessionName}}"
    groups   = ["payments-team"]
  },
  {
    rolearn  = aws_iam_role.team_platform.arn
    username = "{{SessionName}}"
    groups   = ["system:masters"]
  }
]
```

### Layer 3: Kubernetes RBAC

```hcl
resource "kubernetes_role" "payments_admin" {
  metadata {
    name      = "payments-admin"
    namespace = "payments"
  }

  rule {
    api_groups = ["", "apps"]
    resources  = ["pods", "deployments", "services"]
    verbs      = ["get", "list", "create", "update", "delete"]
  }
}

resource "kubernetes_role_binding" "payments_team_binding" {
  metadata {
    name      = "payments-team-binding"
    namespace = "payments"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "payments-admin"
  }

  subject {
    kind = "Group"
    name = "payments-team"   # matches the group in aws-auth
  }
}
```

### Typical repo structure

```
terraform/
├── modules/
│   ├── eks-cluster/        # cluster + aws-auth mappings
│   ├── iam-roles/          # IAM role definitions per team
│   └── k8s-rbac/           # Kubernetes Role + RoleBinding definitions
└── envs/
    ├── dev/
    ├── staging/
    └── prod/               # each env wires them together
```

All three layers are defined in Terraform so everything is version-controlled and reviewable via PRs.
