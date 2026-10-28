# Azure Bastion and AKS management host

This document describes the Bastion-backed management path deployed for the dev
environment, how it reaches AKS and private Azure services, how authentication
works today, and how organizations normally harden the same pattern.

## Purpose

The management host provides an administrative workstation inside the dev
network without assigning a public IP to the VM. Azure Bastion provides the
controlled entry path from an operator laptop.

It is intended for interactive diagnostics and exceptional operational work,
not for normal application deployments. Repeatable changes should continue to
flow through Terraform and Azure Pipelines.

## Repository implementation

The implementation is in:

- `terraform/azure/modules/management-host/main.tf`
- `terraform/azure/modules/management-host/cloud-init.yaml`
- `terraform/azure/envs/dev/main.tf`
- `terraform/azure/modules/aks/main.tf`

### Deployed components

| Component | Configuration |
| --- | --- |
| VNet | `central-dev-vnet`, `10.0.0.0/16` |
| Bastion | `central-dev-bastion`, Standard SKU |
| Bastion subnet | `AzureBastionSubnet`, `10.0.4.0/26` |
| Management VM | `central-dev-management-vm` / host name `dev-management` |
| Management subnet | `management-subnet`, `10.0.5.0/27` |
| VM public IP | None |
| VM outbound access | Dev NAT Gateway |
| VM OS | Ubuntu Server 22.04 LTS Gen2 |
| VM identity | System-assigned managed identity |
| Interactive sign-in | Microsoft Entra SSH extension |
| Local fallback | SSH public key, password authentication disabled |
| Installed tools | Azure CLI, `kubectl`, `kubelogin`, Helm, Git, `jq` |

Standard Bastion enables native-client tunneling and file copy in addition to
portal-based access. Terraform enables `tunneling_enabled`,
`file_copy_enabled`, and `copy_paste_enabled`.

## Connection architecture

```text
Operator laptop
   |
   | Azure login + native Bastion SSH command
   | TLS to Azure Bastion public endpoint
   v
Azure Bastion Standard
   | NIC in AzureBastionSubnet (10.0.4.0/26)
   | SSH/22 across central-dev-vnet
   v
Management VM (private IP only, 10.0.5.0/27)
   |
   +-- kubectl -> HTTPS/443 -> AKS API server
   |                        (source exits through dev NAT Gateway)
   |
   +-- ACR -> private DNS -> 10.0.3.5 private endpoint
   |
   +-- other Azure/private services reachable from central-dev-vnet
   |
   `-- internet updates -> dev NAT Gateway -> static public IP
```

The management subnet NSG allows inbound TCP/22 only from the Bastion subnet.
The VM has no public IP. Therefore, inbound SSH cannot arrive directly from the
internet even though Bastion itself has a Standard public IP.

## What Bastion does and does not do

Bastion is a managed transport service. It:

- Terminates the operator's Bastion connection.
- Carries SSH or RDP traffic to a private VM address.
- Avoids exposing a VM public IP and inbound internet SSH rule.

Bastion does **not**:

- Run `kubectl` itself.
- Grant Kubernetes permissions.
- Make the VM identity an AKS administrator.
- Proxy arbitrary Azure Portal data-plane traffic through the VNet.
- Replace AKS, Azure, or Linux authorization.

The commands run on the management VM after SSH authentication succeeds.

## Signing in to the VM

The VM has the `AADSSHLoginForLinux` extension. The operator's Entra user object
is granted `Virtual Machine Administrator Login` at the VM scope. These are the
two main requirements for Entra SSH:

1. The extension integrates Linux SSH authentication with Microsoft Entra ID.
2. Azure RBAC decides who may log in and whether they receive administrator or
   regular-user privileges.

The earlier extension deployment failure occurred because this extension did
not support `enableAutomaticUpgrade = true`. The current Terraform enables
minor-version upgrades but does not request unsupported automatic upgrades.

The local administrator and SSH public key are retained as a break-glass path.
Password authentication is disabled. The private key must remain outside the
repository and should be stored and audited like any privileged credential.

A typical native connection starts with Azure CLI authentication on the laptop:

```bash
az login
az account set --subscription <subscription-id>

az network bastion ssh \
  --name central-dev-bastion \
  --resource-group central-dev-rg \
  --target-resource-id <management-vm-resource-id> \
  --auth-type AAD
```

Use the Terraform `management_vm_id` and `bastion_name` outputs rather than
manually reconstructing resource IDs.

## How `kubectl` reaches AKS

`az aks get-credentials` writes a cluster entry, user entry, and context into
the VM user's kubeconfig:

```bash
az aks get-credentials \
  --resource-group central-dev-rg \
  --name dev-cluster \
  --overwrite-existing
```

`kubectl` reads that kubeconfig and calls the AKS control-plane API over HTTPS.
It does not normally connect directly to individual pods or node VMs.

The current AKS API is public but network-restricted. Terraform allows only:

- The CI/CD NAT Gateway public IP.
- The dev NAT Gateway public IP.

The management VM has no default Azure outbound path; its subnet is explicitly
associated with the dev NAT Gateway. Its API request therefore appears to AKS
with the allowlisted dev NAT IP. This explains why `kubectl` works from the
management VM while it does not work directly from an arbitrary laptop network.

When `kubectl` requests pod logs or an exec session, it still calls the API
server. The control plane coordinates the request with the appropriate node and
kubelet.

## Authentication and authorization layers

Several similar-sounding controls apply at different layers:

| Layer | Question answered | Mechanism |
| --- | --- | --- |
| Bastion/VM network | Can the laptop reach SSH on the VM? | Bastion and subnet NSG |
| VM authentication | Who may open a Linux session? | Entra SSH plus VM login Azure RBAC role |
| AKS network | Can this source reach the API endpoint? | API authorized IP ranges |
| AKS authentication | Which identity is making the API call? | AKS-managed Entra integration in the next phase |
| Kubernetes authorization | What may that identity do? | Azure RBAC for Kubernetes Authorization in the next phase |
| Azure resource management | May the identity read/update the AKS Azure resource? | Azure management-plane RBAC |

Passing one layer does not bypass another. For example, successful Entra SSH to
the VM does not automatically authorize `kubectl` operations.

## AKS identity design

Before the migration, a live-cluster check returned `aadProfile: null` and
`disableLocalAccounts: false`. The first migration apply enabled AKS-managed
Entra integration and Azure RBAC. Interactive validation confirmed that the
operator's Entra object ID was recognized and authorized by AKS.

The migration replaces that client-certificate model with:

- AKS-managed Microsoft Entra integration for human and automation identity.
- Azure RBAC for Kubernetes Authorization.
- Short-lived Entra tokens obtained through `kubelogin` for interactive access.
- Explicit Azure role assignments for operators and deployment identities.
- Identity-based Terraform and Helm access rather than long-lived cluster
  client certificates.

The migration was deliberately divided into two applies because Terraform
refreshes existing Helm releases during planning:

1. Enable managed Entra and Azure RBAC, and create operator/pipeline role
   assignments while the existing certificate remains available as rollback.
2. After validating Entra access, change the Helm provider to `kubelogin` and
   set `local_account_disabled = true` to remove certificate administration.

Attempting both changes in the first plan would have made Helm request an Entra
token from a cluster that did not yet accept Entra authentication. The second
apply changes the Helm provider to `kubelogin` and disables local accounts,
removing the temporary certificate fallback.

The presence of `kubelogin` on the management VM is preparation for an
Entra-integrated cluster; installing the binary alone does not enable Entra
integration.

This distinction is important because the Entra SSH login identity and the AKS
Kubernetes identity are separate concerns.

## `kubelogin`, AKS-managed Entra integration, and Azure RBAC

For a standalone introduction, implementation examples, login modes and a
troubleshooting runbook, see [`kubelogin-guide.md`](kubelogin-guide.md).

### Why all three are needed

These components solve three different parts of one Kubernetes API request:

| Component | Responsibility | Question answered |
| --- | --- | --- |
| AKS-managed Entra integration | Identity and token validation | Who is making this request? |
| `kubelogin` | Obtaining and refreshing the client token | How does `kubectl` obtain proof of that identity? |
| Azure RBAC for Kubernetes Authorization | Permission evaluation | What may that identity do in this cluster or namespace? |

They are complementary rather than alternatives. Entra integration without an
authorization model can identify a caller but does not define which Kubernetes
actions the caller may perform. Azure RBAC cannot authorize a Kubernetes caller
unless AKS first has a verified identity. `kubelogin` does not grant access at
all; it only supplies the short-lived Entra token used during authentication.

The complete interactive request flow is:

```text
Operator signs in with az login
        |
        v
kubectl reads the kubeconfig exec section
        |
        v
kubelogin obtains an Entra access token from the Azure CLI session
        |
        v
kubectl sends HTTPS request + bearer token to the AKS API server
        |
        v
AKS-managed Entra validates token, tenant, audience and identity
        |
        v
Azure RBAC checks role assignments at cluster/namespace scope
        |
        +-- allowed  -> Kubernetes API performs the operation
        `-- denied   -> Kubernetes API returns Forbidden (HTTP 403)
```

For pipeline Terraform and Helm operations, the flow is similar. The Azure
DevOps service connection signs Azure CLI in as its service principal;
`kubelogin` uses that Azure CLI session; and the Helm provider presents the
resulting token to AKS. Azure RBAC then evaluates the service principal's AKS
role assignment.

### Why the old pipeline appeared to need only a service principal

The pipeline talks to two independent APIs:

| API | Used by | Authentication before migration |
| --- | --- | --- |
| Azure Resource Manager (`management.azure.com`) | Terraform AzureRM provider and Azure CLI | Azure DevOps service principal |
| Kubernetes API (`dev-cluster` endpoint) | Helm provider and `kubectl` | AKS-issued client certificate and private key |

The service principal authenticated Terraform to Azure Resource Manager. That
allowed Terraform to read and modify the AKS Azure resource. It did not by
itself authenticate the Helm provider to the Kubernetes API.

The current Terraform configuration fills that second gap with these values
from the AKS resource:

```hcl
client_certificate = base64decode(module.aks.kube_config_client_certificate)
client_key         = base64decode(module.aks.kube_config_client_key)
```

Consequently, the Kubernetes API sees the identity represented by the cluster
certificate, not the Azure DevOps service principal. The service principal is
how the pipeline reaches Azure and obtains the cluster information; the client
certificate is the separate credential that authorizes the Helm/Kubernetes
connection. Azure DevOps tasks can hide this distinction, which makes the
pipeline look as if one service-principal login handled both APIs.

The migration removes that hidden second identity:

```text
Before
------
Service principal -> Azure Resource Manager
AKS client certificate -> Kubernetes API

After
-----
Service principal -> Azure Resource Manager
Same service principal, represented by short-lived Entra token -> Kubernetes API
```

`kubelogin` is the adapter that obtains the second API's token for the already
authenticated service-principal identity. It does not introduce another
principal or another permission layer.

This requirement is not caused by MDP. A self-hosted agent using the same
managed-Entra design would also need `kubelogin` or another compatible Entra
exec-credential provider. MDP only means the executable must be present in the
custom image or installed for each ephemeral job.

### Why replace cluster certificates

The previous kubeconfig contained a client certificate and private key that
acted as a powerful cluster credential. Whoever copied that credential could
use it until it expired or was rotated. It was not naturally tied to the user's
Entra lifecycle, group membership, MFA, or Conditional Access session.

The target identity-based model provides:

- Short-lived tokens instead of reusable cluster-admin certificate material.
- Immediate control through Entra account and group lifecycle.
- Separate identities and role assignments for humans and pipelines.
- Better attribution in authentication and audit records.
- Azure scope inheritance and namespace-scoped role assignments.
- A familiar least-privilege model consistent with other Azure resources.

Setting `local_account_disabled = true` is the final enforcement step. Managed
Entra integration can be enabled while local certificate accounts remain
available, but that would leave a path around the intended identity model. The
two-step rollout retains the certificate only long enough to validate Entra and
Azure RBAC before removing that fallback.

`az aks get-credentials` deserves a separate distinction: it writes the API
endpoint, cluster CA and authentication instructions into kubeconfig. It does
not by itself make the caller a Kubernetes administrator. The caller still
needs a valid Entra sign-in and an Azure RBAC role that permits the requested
operation.

### AKS-managed Entra integration

With managed Entra integration enabled, AKS delegates user authentication to
Microsoft Entra ID. Kubeconfig uses an `exec` credential plugin rather than
embedding a durable user certificate. The operator receives a short-lived
token after Entra authentication.

Benefits include:

- Central user and group lifecycle.
- Conditional Access and MFA support where applicable.
- Short-lived tokens instead of distributed client certificates.
- Group-based access and auditable identity.

### `kubelogin`

`kubelogin` is the Kubernetes credential plugin used to obtain and refresh
Microsoft Entra tokens for an Entra-integrated cluster. A common interactive
workflow after enabling integration is:

```bash
az login
az aks get-credentials \
  --resource-group central-dev-rg \
  --name dev-cluster \
  --overwrite-existing

kubelogin convert-kubeconfig -l azurecli
kubectl auth whoami
kubectl get nodes
```

`-l azurecli` tells `kubelogin` to use the Azure CLI session. Other login modes
serve automation, managed identity, device code, or workload identity use
cases. Interactive device-code login may be incompatible with some Conditional
Access policies, so organizations normally standardize an approved mode.

Never run `kubelogin` merely because the binary exists. The kubeconfig must
actually contain an Entra exec credential and the cluster must have Entra
integration enabled.

### Kubernetes RBAC versus Azure RBAC for Kubernetes

After authentication, AKS must authorize the request. There are two broad
models:

1. **Kubernetes RBAC:** Kubernetes `Role`, `ClusterRole`, `RoleBinding`, and
   `ClusterRoleBinding` objects grant access to Entra users/groups.
2. **Azure RBAC for Kubernetes Authorization:** Azure role assignments such as
   `Azure Kubernetes Service RBAC Reader`, `Writer`, `Admin`, and `Cluster
   Admin` grant Kubernetes permissions at cluster or namespace scope.

Azure management-plane roles such as Contributor do not automatically grant
permission to list pods. Similarly, `Azure Kubernetes Service Cluster User
Role` permits retrieval of user credentials but is not by itself unrestricted
permission to every Kubernetes object.

This setup will use managed Entra integration together with **Azure RBAC for
Kubernetes Authorization**. For the learning environment, the named operator
can receive the required role directly. The organization-grade pattern is to
assign roles to Entra groups rather than individual users and reserve
cluster-admin access for tightly controlled emergency use.

The AKS resource is configured in this direction:

```hcl
resource "azurerm_kubernetes_cluster" "this" {
  # Existing settings omitted.

  azure_active_directory_role_based_access_control {
    azure_rbac_enabled = true
    tenant_id          = data.azurerm_client_config.current.tenant_id
  }
}
```

This block is accompanied by explicit operator and pipeline role assignments.
The Helm provider uses `kubelogin`, and local AKS accounts are disabled after
the second apply so certificates cannot bypass the Entra and Azure RBAC model.

## ACR access from the management VM

The dev environment creates:

- An ACR private endpoint in `central-dev-vnet`.
- A `privatelink.azurecr.io` private DNS zone.
- A VNet link for the dev VNet.

The observed validation is correct:

```text
skssolar.azurecr.io -> skssolar.privatelink.azurecr.io -> 10.0.3.5
curl -I https://skssolar.azurecr.io/v2/ -> HTTP 401
```

The private address proves private DNS and routing. The unauthenticated `401`
proves the registry endpoint and TLS are reachable and is the expected Docker
Registry v2 challenge. Successful `az acr repository list` then proves the
operator also has data-plane authorization.

The Azure Portal repository blade fails from the laptop because browser data
plane traffic originates outside the private network. Portal authentication
does not tunnel ACR traffic through Bastion and does not bypass ACR networking.

`docker images` and `docker ps` inspect the VM's local Docker daemon; they do not
list ACR content. A `/var/run/docker.sock` permission error is a local Linux
permission issue rather than an ACR connectivity failure. Membership in the
`docker` group is effectively root-level access and should be granted only when
required.

Preferred read-only inspection does not require Docker:

```bash
az acr repository list --name skssolar --output table
az acr repository show-tags \
  --name skssolar \
  --repository solar-system \
  --output table
```

## Routine operations

Useful read-only commands include:

```bash
kubectl cluster-info
kubectl get nodes
kubectl get pods -A
kubectl get deployments,services,ingresses -n dev
kubectl get events -n dev --sort-by=.lastTimestamp
kubectl describe pod <pod-name> -n dev
kubectl logs <pod-name> -n dev --tail=200
kubectl auth can-i --list -n dev
```

For External Secrets:

```bash
kubectl get pods -n external-secrets
kubectl get serviceaccount,secretstore,externalsecret -n dev
kubectl describe secretstore azure-keyvault -n dev
kubectl describe externalsecret postgres-secret -n dev
kubectl get secret postgres-secret -n dev
```

Avoid printing secret values to the terminal or placing them in shell history.
Verify secret names, keys, ownership, sync status, and consuming pod health
instead.

## What larger organizations commonly do

The same concept is normally implemented with more separation and governance:

- A dedicated management subscription or hub VNet.
- Hub-and-spoke routing, private DNS resolvers, firewalls, and VPN or ExpressRoute.
- Private AKS API endpoints or approved API Server VNet Integration patterns.
- Bastion or privileged access workstations for emergency/interactive access.
- Just-in-time role activation through Entra PIM.
- Entra groups mapped to least-privilege namespace roles.
- Separate read-only, operator, deployment, and cluster-administrator personas.
- Session, Azure Activity, Kubernetes audit, and OS logs sent to a central SIEM.
- No standing user credentials or shared kubeconfig files.
- Automated deployments through workload identities, not human jump-host
  sessions.
- Regularly rebuilt or patched management hosts with restricted software and
  egress.

Some organizations avoid persistent jump hosts entirely and use ephemeral
privileged workstations or controlled pipeline tasks. Where a jump host is
retained, it should not become an undocumented deployment server.

## Security recommendations for this setup

1. Treat the management VM as a privileged administrative asset.
2. Keep direct VM public IP access disabled.
3. Retain the NSG rule that limits SSH source to `AzureBastionSubnet`.
4. Prefer Entra SSH; protect the local SSH key as break-glass material.
5. Move toward AKS-managed Entra integration and group-based authorization.
6. Replace broad cluster credentials with short-lived identity-based access.
7. Assign namespace-level read/write access for normal work and tightly limit
   cluster-admin.
8. Enable and retain Azure, AKS control-plane/audit, Bastion, and VM logs.
9. Patch the VM and recreate it periodically rather than allowing configuration
   drift.
10. Do not store application secrets, kubeconfig exports, or service-principal
    secrets in the repository or persistent shell history.
11. Use pipelines for changes; use the host primarily for diagnosis and
    controlled emergency operations.
12. Review NAT and NSG paths whenever a new private endpoint or service is added.

## Troubleshooting sequence

When a command fails, diagnose the layers in order.

### 1. Bastion and SSH

- Confirm the Bastion and VM are running.
- Confirm the VM has no public IP.
- Confirm the user has `Virtual Machine Administrator Login` or
  `Virtual Machine User Login`.
- Confirm the Entra SSH extension succeeded.
- Confirm TCP/22 is allowed from the Bastion subnet to the management subnet.

### 2. Azure identity

```bash
az account show --output table
az account get-access-token --query expiresOn --output tsv
```

Confirm the intended tenant and subscription. Reauthenticate if the token has
expired.

### 3. Kubeconfig and AKS network path

```bash
kubectl config current-context
kubectl config view --minify
kubectl cluster-info
```

If kubeconfig points to `127.0.0.1`, it may have been created by a temporary
proxy and is no longer valid. Run `az aks get-credentials` again. If the request
times out, verify the management subnet NAT association and that the dev NAT IP
remains in the AKS authorized ranges.

### 4. Kubernetes authorization

```bash
kubectl auth whoami
kubectl auth can-i get pods -n dev
```

Network reachability does not imply authorization. Inspect the relevant Azure
or Kubernetes role assignments based on the cluster's selected authorization
model.

### 5. Private service DNS and endpoint

```bash
getent ahostsv4 skssolar.azurecr.io
curl -I https://skssolar.azurecr.io/v2/
```

Expect a private IP and, before login, an HTTP `401`. A public address indicates
a private DNS link or record problem. A timeout with a private address indicates
routing, NSG, endpoint, or service-health investigation is needed.

## Managed Entra and Azure RBAC migration record

The migration contains the following work across two controlled applies:

- Enable AKS-managed Entra integration.
- Enable Azure RBAC for Kubernetes Authorization.
- Select the Entra administrator and operator identities; use groups when this
  setup is expanded beyond a single operator.
- Grant the management users/groups the minimum required role.
- Grant deployment service connections their required namespace or cluster role.
- Apply managed Entra, Azure RBAC, and all operator/pipeline role assignments
  before changing provider authentication.
- Change the Terraform Helm/Kubernetes provider to `kubelogin` and disable AKS
  local accounts in the second apply.
- Test `az aks get-credentials`, `kubelogin`, and `kubectl auth can-i` with a
  non-owner test user.
- Validate External Secrets and workload identity independently; workload
  identity federation is not the same as human AKS login.
- Document and test a break-glass procedure.
- Apply the change in a maintenance window and retain a rollback plan.

After the second apply, verify that `disableLocalAccounts` is `true`, kubeconfig
contains an Entra `exec` credential, and normal access works only through the
intended Azure RBAC assignments.
