# `kubelogin` guide for AKS

This guide explains what `kubectl`, kubeconfig and `kubelogin` do, why
`kubelogin` is required for Microsoft Entra-integrated Azure Kubernetes Service
(AKS), and how it is used by both a human operator and a CI/CD pipeline.

## The short version

`kubelogin` is an authentication helper. It obtains a short-lived Microsoft
Entra access token and returns it to Kubernetes clients such as `kubectl`, Helm
and Terraform's Helm provider.

It does not:

- Connect to pods by itself.
- Deploy Kubernetes resources.
- Grant any permissions.
- Replace `kubectl` or Helm.
- Replace Azure RBAC role assignments.

The three main responsibilities are:

| Component | Responsibility |
| --- | --- |
| `kubectl` or Helm | Creates and sends a Kubernetes API request |
| `kubelogin` | Obtains proof of the caller's Entra identity |
| Azure RBAC for Kubernetes | Decides whether that identity may perform the request |

## What is `kubectl`?

`kubectl` is the standard command-line client for Kubernetes. It communicates
with the Kubernetes API server and can:

- Read cluster state: `kubectl get` and `kubectl describe`.
- Apply desired state: `kubectl apply`.
- Read container logs: `kubectl logs`.
- Open an interactive process: `kubectl exec`.
- Inspect permissions: `kubectl auth can-i`.
- Manage rollouts: `kubectl rollout`.

For AKS, `kubectl` normally talks to the AKS control-plane endpoint over HTTPS.
It does not usually connect directly to worker-node VMs or pods.

Every API request needs:

1. The API server address.
2. The cluster certificate authority, used to verify the server's TLS identity.
3. A credential that proves the client identity.

`kubectl` obtains those settings from kubeconfig.

## What is kubeconfig?

Kubeconfig is usually stored at `~/.kube/config`. It describes:

- **Clusters:** API endpoints and trusted certificate authorities.
- **Users:** instructions for obtaining client credentials.
- **Contexts:** a cluster/user/namespace combination.
- **Current context:** the context used when no explicit context is supplied.

Useful inspection commands are:

```bash
kubectl config get-contexts
kubectl config current-context
kubectl config view --minify
```

Do not publish a complete kubeconfig without inspecting it. Depending on the
authentication model, it may contain certificates, keys or other sensitive
configuration.

`az aks get-credentials` retrieves the AKS endpoint, cluster CA and
authentication configuration, and merges them into kubeconfig:

```bash
az aks get-credentials \
  --resource-group central-dev-rg \
  --name dev-cluster \
  --overwrite-existing
```

This command prepares a connection configuration. It does not independently
grant the user permission to access Kubernetes resources.

## Why `kubectl` delegates login

Kubernetes supports many identity providers. `kubectl` deliberately does not
embed Microsoft Entra, AWS IAM, Google IAM and every enterprise authentication
protocol.

Instead, kubeconfig can contain an **exec credential plugin**. When credentials
are required, `kubectl` runs the configured executable and expects a standard
Kubernetes `ExecCredential` response.

An Entra-enabled AKS kubeconfig is conceptually similar to:

```yaml
users:
  - name: clusterUser_central-dev-rg_dev-cluster
    user:
      exec:
        apiVersion: client.authentication.k8s.io/v1beta1
        command: kubelogin
        args:
          - get-token
          - --login
          - azurecli
          - --server-id
          - 6dae42f8-4368-4678-94ff-3960e28e3630
```

When `kubectl` needs a credential, it executes `kubelogin`. `kubelogin` returns
JSON resembling:

```json
{
  "apiVersion": "client.authentication.k8s.io/v1beta1",
  "kind": "ExecCredential",
  "status": {
    "expirationTimestamp": "2026-10-26T12:00:00Z",
    "token": "<short-lived-token>"
  }
}
```

`kubectl` then places that token in the HTTPS request to AKS.

## Complete authentication and authorization flow

For an interactive operator:

```text
Operator runs az login
        |
        v
Azure CLI establishes an Entra session for the user
        |
        v
Operator runs kubectl get pods
        |
        v
kubectl reads kubeconfig and invokes kubelogin
        |
        v
kubelogin obtains an AKS-audience token using the Azure CLI session
        |
        v
kubectl sends HTTPS request + bearer token to the AKS API
        |
        v
AKS-managed Entra validates tenant, audience, signature and identity
        |
        v
Azure RBAC evaluates the identity's AKS role assignments
        |
        +-- allowed -> operation proceeds
        `-- denied  -> API returns Forbidden (HTTP 403)
```

For this repository's Azure DevOps pipeline:

```text
AzureCLI task signs in through the Azure service connection
        |
        v
Azure CLI session represents the pipeline service principal
        |
        v
Terraform starts the Helm provider
        |
        v
Helm provider invokes kubelogin through its exec configuration
        |
        v
kubelogin obtains an AKS token for that service principal
        |
        v
Helm sends the token to AKS
        |
        v
Azure RBAC evaluates the service principal's AKS role assignment
```

The human and pipeline use the same mechanism but remain different identities.
They receive separate Azure role assignments and produce separately attributable
audit activity.

## Why the old pipeline did not visibly use `kubelogin`

Before the migration, the pipeline used two credentials:

```text
Azure DevOps service principal -> Azure Resource Manager API
AKS client certificate/key    -> Kubernetes API
```

The Terraform AzureRM provider used the service principal to manage Azure
resources. The Helm provider separately used a client certificate and private
key obtained from the AKS resource:

```hcl
client_certificate = base64decode(module.aks.kube_config_client_certificate)
client_key         = base64decode(module.aks.kube_config_client_key)
```

This separation was easy to miss because both operations happened inside one
pipeline. The Kubernetes API saw the certificate identity rather than the
pipeline service principal.

After migration:

```text
Service principal -> Azure Resource Manager token -> Azure API
Same principal    -> AKS Entra token             -> Kubernetes API
```

`kubelogin` is the adapter that obtains the second API's token. It adds no new
identity and grants no permission.

## Why use token authentication instead of AKS client certificates?

The Entra token model provides:

- Short-lived credentials instead of reusable client keys.
- A distinct, auditable identity for every human and pipeline.
- Central account, group and service-principal lifecycle.
- Rapid revocation through role removal or identity disablement.
- Least-privilege Azure RBAC assignments at cluster or namespace scope.
- Compatibility with Entra security controls for human users.
- No normal path around Entra after AKS local accounts are disabled.

The final enforcement setting is:

```hcl
local_account_disabled = true
```

Entra integration can coexist with AKS local certificate accounts. Disabling
local accounts prevents those certificates from bypassing the intended Entra
and Azure RBAC model.

## Installation

### Management VM

The management-host cloud-init installs `kubectl` and `kubelogin`:

```bash
az aks install-cli \
  --install-location /usr/local/bin/kubectl \
  --kubelogin-install-location /usr/local/bin/kubelogin
```

Verify them with:

```bash
kubectl version --client
kubelogin --version
```

### Managed DevOps Pool agent

The preferred long-term approach is to install and pin `kubelogin` in the
custom Azure Compute Gallery agent image.

The infrastructure pipeline also contains a defensive step:

```yaml
- bash: |
    set -euo pipefail

    if command -v kubelogin >/dev/null 2>&1; then
      kubelogin --version
      exit 0
    fi

    tool_dir="$(Agent.TempDirectory)/aks-tools"
    mkdir -p "${tool_dir}"
    az aks install-cli \
      --install-location "${tool_dir}/kubectl" \
      --kubelogin-install-location "${tool_dir}/kubelogin"
    echo "##vso[task.prependpath]${tool_dir}"
  displayName: Prepare kubelogin
```

It reuses `kubelogin` when already installed. Otherwise, it installs the tools
under the job's temporary directory and prepends that directory to `PATH` for
later steps. The directory disappears with the ephemeral agent.

This requirement is not caused by MDP. A self-hosted agent using Entra-based
Kubernetes authentication also needs `kubelogin` or another compatible exec
credential provider. MDP only changes how the executable is delivered.

## Interactive use on the management VM

After the AKS-managed Entra and Azure RBAC migration is applied:

```bash
az login
az account set --subscription <subscription-id>

az aks get-credentials \
  --resource-group central-dev-rg \
  --name dev-cluster \
  --overwrite-existing

kubelogin convert-kubeconfig -l azurecli

kubectl auth whoami
kubectl auth can-i get pods -n dev
kubectl get pods -n dev
```

`convert-kubeconfig -l azurecli` configures the kubeconfig exec entry to reuse
the Azure CLI login. Recent AKS/Azure CLI combinations may already return an
exec-format kubeconfig, but running the conversion makes the desired login mode
explicit.

If authentication succeeds but authorization is absent, the request normally
returns `Forbidden`. That means networking and authentication worked; inspect
the Azure RBAC assignment rather than reinstalling `kubelogin`.

## Use by Terraform and Helm

After the second migration apply, the Helm provider uses an exec block:

```hcl
provider "helm" {
  kubernetes = {
    host                   = module.aks.kube_config_host
    cluster_ca_certificate = base64decode(module.aks.kube_config_cluster_ca_certificate)

    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "kubelogin"
      args = [
        "get-token",
        "--login",
        "azurecli",
        "--server-id",
        "6dae42f8-4368-4678-94ff-3960e28e3630",
      ]
    }
  }
}
```

The Azure DevOps Terraform apply must run within an Azure CLI-authenticated
task. The service connection creates the Azure CLI session; the provider's
`kubelogin` process reuses it.

The fixed server ID is the AKS Microsoft Entra server application audience. It
is not the pipeline service principal ID and is not a secret.

## Login modes

`kubelogin` supports multiple login modes. The correct choice depends on where
the client runs.

| Mode | Typical use | Notes |
| --- | --- | --- |
| `azurecli` | Operator workstation or AzureCLI pipeline task | Reuses the active `az login` session |
| Device code | Interactive environments without a browser callback | May conflict with some Conditional Access policies |
| Interactive/web browser | Human workstation | Requires interactive browser capability |
| Service principal | Non-interactive automation | Requires securely supplied service-principal credentials |
| Managed identity | Azure VM/workload with an assigned identity | Avoids stored client secrets |
| Workload identity | Federated automation | Preferred where supported because no client secret is stored |

This setup uses `azurecli` because:

- The management VM operator signs in using Azure CLI.
- Azure DevOps `AzureCLI` tasks already authenticate the service connection.
- The same exec configuration can reuse the appropriate identity in either
  environment.

The login mode changes how a token is obtained. It does not change the Azure
RBAC roles required by that identity.

## Roles used by this setup

The operator and Azure DevOps service principal receive:

- `Azure Kubernetes Service Cluster User Role`, allowing retrieval of the user
  kubeconfig.
- `Azure Kubernetes Service RBAC Cluster Admin`, allowing Kubernetes API
  administration during this learning-stage migration.

The first role does not grant permission to deploy pods. The second role is the
Kubernetes data-plane authorization.

Cluster Admin is deliberately broad. An organization would normally replace
it for routine pipelines with `Azure Kubernetes Service RBAC Writer` or a
custom role scoped to the required namespace, retaining tightly controlled
cluster-administrator access for platform operations and emergencies.

## Authentication is not networking

`kubelogin` cannot repair a network path. The client must first be able to reach
the AKS API endpoint.

In this setup:

- The management VM exits through the dev NAT Gateway.
- The MDP agent exits through the CI/CD NAT Gateway.
- Both NAT public IPs are present in AKS API authorized IP ranges.

The request reaches AKS only when both networking and identity are valid:

```text
Network path -> Entra authentication -> Azure RBAC authorization
```

Failure examples:

| Symptom | Likely layer |
| --- | --- |
| Timeout or connection refused | Network, DNS, endpoint or firewall |
| Entra login/token error | Azure CLI session, tenant, audience or `kubelogin` |
| `Unauthorized` (401) | Missing, invalid or expired token |
| `Forbidden` (403) | Valid identity but insufficient Azure RBAC permission |

## Verification

Inspect the live AKS identity configuration:

```bash
az aks show \
  --resource-group central-dev-rg \
  --name dev-cluster \
  --query '{
    aadProfile:aadProfile,
    disableLocalAccounts:disableLocalAccounts
  }' \
  --output json
```

After the completed migration, expect managed Entra and Azure RBAC to be
enabled and local accounts to be disabled.

Inspect kubeconfig without exposing tokens:

```bash
kubectl config view --minify --raw=false
```

Confirm identity and authorization:

```bash
kubectl auth whoami
kubectl auth can-i get pods -n dev
kubectl auth can-i create deployments -n dev
```

Do not use `kubectl auth can-i '*' '*'` as the desired result for ordinary
application pipelines. It is suitable only when validating a deliberately
assigned administrative role during migration.

## Troubleshooting

### `kubelogin: command not found`

The kubeconfig expects the exec plugin, but it is not on `PATH`:

```bash
command -v kubelogin
kubelogin --version
```

Install it or ensure the pipeline's preparation step runs before Terraform,
Helm or `kubectl`.

### Azure CLI is not logged in

The `azurecli` login mode requires an active Azure CLI session:

```bash
az account show
```

Run `az login` interactively, or ensure the Terraform/Helm command runs inside
the authenticated Azure DevOps `AzureCLI` task.

### Wrong tenant or subscription

```bash
az account show --query '{tenant:tenantId,subscription:id,user:user.name}'
```

Select the correct subscription and re-run `az aks get-credentials` if the
kubeconfig was obtained for a different cluster or tenant.

### The exec entry is missing

```bash
kubectl config view --minify --raw
```

After confirming the output is safe to inspect, look for `user.exec.command:
kubelogin`. Retrieve credentials again and convert the kubeconfig:

```bash
az aks get-credentials \
  --resource-group central-dev-rg \
  --name dev-cluster \
  --overwrite-existing
kubelogin convert-kubeconfig -l azurecli
```

### Token works but Kubernetes returns `Forbidden`

Authentication succeeded. Check the caller and its roles:

```bash
kubectl auth whoami
kubectl auth can-i get pods -n dev
```

Inspect Azure role assignments at the AKS resource or namespace scope. Do not
solve an authorization problem by retrieving admin certificates.

### Pipeline works with Azure but Helm fails

Azure Resource Manager and Kubernetes use different tokens. Confirm:

- `kubelogin` exists on the agent.
- Terraform/Helm runs inside the authenticated Azure CLI task.
- The service connection object ID, not its application/client ID, received the
  AKS role assignment.
- Azure RBAC propagation has completed.
- The agent NAT IP is still allowed by the AKS API server.

## Security guidance

- Do not store Entra tokens in pipeline variables or artifacts.
- Do not print raw kubeconfig, exec-plugin output or environment credentials.
- Prefer workload identity federation over service-principal client secrets for
  Azure DevOps service connections where available.
- Grant pipeline access at the smallest practical namespace and role scope.
- Keep human and automation identities separate.
- Pin and patch `kubelogin` in controlled agent images.
- Disable AKS local accounts only after Entra and Azure RBAC are tested.
- Retain a documented, audited break-glass process rather than routine admin
  certificates.
- Treat `401`, `403` and network failures as different diagnostic categories.

## Mental model

The simplest way to remember the design is:

```text
kubectl/Helm asks the question
kubelogin obtains the identity proof
AKS-managed Entra verifies the identity
Azure RBAC makes the authorization decision
AKS performs the requested Kubernetes operation
```

