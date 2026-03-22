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

### Authentication step (WHO are you?)

```
kubectl get pods
       │
       ▼
   ~/.kube/config says: run `aws eks get-token`
       │
       ▼
   AWS STS verifies your IAM credentials (access key + secret key)
       │
       ▼
   Returns a short-lived token (valid ~15 minutes)
       │
       ▼
   kubectl sends this token to the EKS API server
       │
       ▼
   EKS API server calls AWS IAM: "Is this token valid?"
       │
       ▼
   AWS IAM responds: "Yes, this is ec2-cli-user"
```

At this point, the API server knows **who you are** — but that doesn't mean you can do anything. You're authenticated, not authorized.

### Which account does `aws eks get-token` use?

The token is generated for whichever **AWS IAM identity is currently configured** on the machine where you run it. AWS resolves the identity using a credential chain — checked in this order of priority:

1. **Environment variables** — `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` (if set)
2. **AWS CLI profile** — `~/.aws/credentials` (configured via `aws configure`)
3. **EC2 Instance Role** — IAM role attached to the EC2 instance itself

In our setup, the EC2 instance (`ubuntu@ip-172-31-38-97`) has `ec2-cli-user` credentials configured via `aws configure`, so `aws eks get-token` generates a token for `arn:aws:iam::312018064574:user/ec2-cli-user`.

To verify which identity is being used at any time, run:

```bash
aws sts get-caller-identity
```

This shows the account ID, ARN, and user/role name. That's the same identity that `aws eks get-token` generates a token for, and the same ARN that gets looked up in the `aws-auth` ConfigMap.

### Authorization step (CAN you do this?)

```
   API server now knows: this is ec2-cli-user
       │
       ▼
   Looks up aws-auth ConfigMap in kube-system namespace
       │
       ▼
   Finds: ec2-cli-user → Kubernetes group "system:masters"
       │
       ▼
   Checks Kubernetes RBAC: does "system:masters" have
   permission to "list" resource "pods"?
       │
       ▼
   system:masters is bound to the built-in ClusterRole
   "cluster-admin" which allows ALL verbs on ALL resources
       │
       ▼
   Result: ALLOWED ✓ → returns the pod list
```

### Key difference between the two steps

| | Authentication | Authorization |
|---|---|---|
| **Question** | Who are you? | What can you do? |
| **Handled by** | AWS IAM + STS | Kubernetes RBAC |
| **Proof** | Token from `aws eks get-token` | `aws-auth` ConfigMap + RBAC roles |
| **Can fail independently** | Yes — bad credentials | Yes — valid user but no permissions |

- **Without authentication:** "I don't know who you are" → request rejected
- **Without authorization (no `aws-auth` entry):** "I know who you are, but you have no permissions" → request rejected

---

## Key EKS module settings explained

### `cluster_endpoint_public_access = true`

Makes the Kubernetes API server reachable from the public internet. Anyone with valid credentials can call `kubectl` from anywhere.

- **OK for dev/learning:** Yes
- **OK for production:** No — use private access with VPN/bastion

### `manage_aws_auth_configmap = true`

This tells the EKS Terraform module: **"I want you to create and manage the `aws-auth` ConfigMap in the `kube-system` namespace for me."**

Without this, the ConfigMap either doesn't exist or isn't managed by Terraform — meaning you'd have to manually create it with `kubectl`. Managing it through Terraform is good practice because it's version-controlled, reproducible, and won't drift.

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

This is the content that gets written into the `aws-auth` ConfigMap. It creates this mapping:

```
AWS IAM world                                          Kubernetes world
─────────────                                          ────────────────
arn:aws:iam::312018064574:user/ec2-cli-user  →  username: ec2-cli-user
                                                 group: system:masters
```

Each field explained:

| Field | Value | What it means |
|---|---|---|
| `userarn` | `arn:aws:iam::312018064574:user/ec2-cli-user` | The AWS IAM identity to match — when someone authenticates with this ARN, apply this mapping |
| `username` | `ec2-cli-user` | The Kubernetes username assigned to this person (shows up in audit logs) |
| `groups` | `["system:masters"]` | The Kubernetes group(s) this user belongs to — `system:masters` = full cluster admin |

**How it connects to `kubectl get pods`:**

1. On the EC2 instance, `aws configure` is set up with `ec2-cli-user` credentials
2. `kubectl get pods` triggers `aws eks get-token` which generates a token for `arn:aws:iam::312018064574:user/ec2-cli-user`
3. EKS API server receives the token, confirms the identity with AWS IAM
4. Looks up that ARN in the `aws-auth` ConfigMap → finds this entry
5. Maps you to Kubernetes user `ec2-cli-user` in group `system:masters`
6. `system:masters` has full access → request allowed

**Without this block**, step 4 fails — your ARN isn't in the ConfigMap, so Kubernetes doesn't know what permissions to give you, and every request is denied.

**Issues with this approach for production:**

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
