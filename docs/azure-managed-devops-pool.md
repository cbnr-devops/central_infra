# Azure Managed DevOps Pool

This document describes the Azure Managed DevOps Pool (MDP) used by this
repository, why it was designed this way, how pipeline data survives ephemeral
agents, and how larger organizations commonly operate managed build capacity.

## Purpose

The pool supplies short-lived, Azure-managed Linux agents for the infrastructure
and application pipelines. It replaces a permanently running self-hosted build
VM while retaining access to private Azure services.

The implementation provides:

- Azure-managed agent lifecycle and VM provisioning.
- A custom, generalized Ubuntu 22.04 image.
- Private access to the shared Azure Container Registry (ACR).
- Predictable outbound traffic through a NAT Gateway.
- Up to two concurrent agents, subject to Azure DevOps parallel-job capacity.
- A clean agent filesystem for every job.

## Repository implementation

The main implementation is in:

- `terraform/azure/envs/cicd/main.tf`
- `terraform/azure/envs/cicd/variables.tf`
- `terraform/azure/envs/cicd/terraform.tfvars`
- `terraform/azure/envs/shared/main.tf` for the ACR private endpoint and access
- `azure-pipelines.yml`
- `azure-pipelines-mdp-smoke.yml`

### Deployed settings

| Setting | Value |
| --- | --- |
| Azure resource | `central-infra-mdp` |
| Region | `australiaeast` |
| Azure DevOps organization | `https://dev.azure.com/skssolar` |
| Azure DevOps project | `sample-project` |
| Agent model | Stateless |
| Maximum concurrency | 2 |
| VM size | `Standard_D2ads_v5` |
| Image alias | `central-custom-linux` |
| Gallery | `centralcicdgallery` |
| Image definition | `central-devops-agent-ubuntu2204` |
| Image selector | Version-qualified ID ending in `/versions/latest` |
| CI/CD VNet | `central-cicd-vnet`, `10.10.0.0/16` |
| Agent subnet | `managed-devops-pool-subnet`, `10.10.1.0/27` |
| Private endpoint subnet | `private-endpoints-subnet`, `10.10.2.0/27` |
| Outbound path | `central-cicd-natgw` with a static public IP |

### Resource relationship

```text
Azure DevOps project
        |
        | requests an agent for a job
        v
central-infra-mdp
        |
        +-- Dev Center project: central-cicd-project
        |
        +-- custom image: central-custom-linux
        |      `-- Azure Compute Gallery image version
        |
        `-- ephemeral VM NIC
               `-- managed-devops-pool-subnet
                      +-- delegated to Microsoft.DevOpsInfrastructure/pools
                      +-- NAT Gateway -> stable outbound public IP
                      `-- VNet DNS -> ACR private endpoint (10.10.2.0/27)
```

The pool is associated with one Azure DevOps project. Pipeline YAML selects it
with both the pool name and image alias:

```yaml
pool:
  name: central-infra-mdp
  demands:
    - ImageOverride -equals central-custom-linux
```

`ImageOverride` is important when a pool exposes more than one image. It makes
the job's required image explicit.

## Networking

The agent subnet has these controls:

- It is exclusively delegated to `Microsoft.DevOpsInfrastructure/pools`.
- Default Azure outbound access is disabled.
- A NAT Gateway supplies deliberate, stable internet egress.
- The subnet does not contain ACR private endpoints; those use the separate
  `private-endpoints-subnet`.

The shared environment creates an ACR private endpoint in the CI/CD private
endpoint subnet and links the `privatelink.azurecr.io` private DNS zone to the
CI/CD VNet. Consequently, an agent resolves `skssolar.azurecr.io` to a private
address rather than using the public ACR data endpoint.

The stable NAT IP is also useful for services that still require an IP allowlist,
including the current AKS API server configuration.

## Identity and role assignments

There are two different identities involved. They must not be confused.

### DevOpsInfrastructure service principal

The Microsoft-managed `DevOpsInfrastructure` enterprise application operates
the pool infrastructure. Terraform grants it:

- `Reader` on `central-cicd-vnet`.
- `Network Contributor` on `central-cicd-vnet`.
- `Compute Gallery Image Reader` on the gallery.

Gallery-wide scope is intentional. Replacing an image definition no longer
replaces the role assignment, and new definitions in that gallery can be
discovered without another image-level assignment.

The pool must use a **version-qualified** image resource ID, for example:

```text
.../galleries/centralcicdgallery/images/central-devops-agent-ubuntu2204/versions/latest
```

Passing only the image-definition ID caused the earlier
`InvalidImageResourceId` failure.

The image definition is generalized, Generation 2, x64, and Standard security.
An image that is merely visible in the portal is not necessarily valid for MDP;
its version, replication state, OS generalization, architecture, security type,
and the service principal's access must all be valid.

### Pipeline service connection

Jobs authenticate to Azure through the Azure DevOps service connection. That
identity receives only the roles needed by the task. For example, the ACR
connectivity test needs `AcrPush`; AKS deployment jobs need appropriate cluster
access. The service connection is separate from the
`DevOpsInfrastructure` service principal that creates agents.

## Agent lifecycle and persistence

The pool uses `stateless_agent {}`. Azure creates or assigns an agent for a job,
runs the job, and discards the agent afterward. A later job must assume it has a
new machine and an empty workspace.

This is a security and reproducibility property:

- Credentials and source files do not remain on a long-lived VM.
- Builds do not accidentally depend on files from an earlier run.
- A compromised agent has a short useful lifetime.
- Every required tool and input must be declared.

Anything kept only on the agent disk is temporary. Durable data belongs in a
durable service:

| Data | Durable location |
| --- | --- |
| Source and pipeline definitions | Git repository |
| Container images | ACR |
| Terraform state | Azure Storage backend |
| Console logs | Azure DevOps run history |
| Files shared between jobs | Published Pipeline Artifacts |
| Test and coverage results | Azure DevOps test/coverage services |
| Packages | Azure Artifacts or another package registry |
| Runtime logs and metrics | Azure Monitor and Log Analytics |
| Secrets | Azure Key Vault or approved secret store |

A job cannot rely on another job's working directory, even in the same stage.
Use `PublishPipelineArtifact` and `DownloadPipelineArtifact` when files must
cross a job boundary. A pipeline cache may improve speed, but it is an
optimization and not the authoritative copy of an artifact.

## Concurrency, parallelism, and pipeline design

Three independent limits affect throughput:

1. `maximum_concurrency` limits how many MDP agents may exist simultaneously.
2. The pool organization's `parallelism` setting is configured to the same
   value in Terraform.
3. Azure DevOps parallel-job entitlement limits how many jobs the organization
   may actually execute at once.

This setup has `maximum_concurrency = 2` and two self-hosted parallel-job slots.
It can therefore run at most two MDP jobs concurrently. Raising only the MDP
value would not bypass an Azure DevOps parallel-job limit.

Every Azure Pipeline **job** requests an agent. Splitting a sequential workflow
into many jobs can repeatedly pay agent provisioning, checkout, authentication,
and dependency setup costs. The infrastructure pipeline was therefore reduced
to one job that formats, validates, plans, and applies sequentially. This cut a
roughly 15–19 minute run to approximately two minutes in the observed test.

For application pipelines, use separate jobs only when they provide real value:

- Tasks can safely run in parallel.
- A security boundary requires a fresh agent.
- A deployment must use an Azure DevOps Environment and approval.
- Independent retry/failure behavior is valuable.
- Different operating systems or images are required.

Keep tightly coupled build steps in one job, publish the immutable build output,
and let deployment jobs download that output. Do not rebuild the image in every
environment.

## What larger organizations commonly do

There is no universal choice between stateful and stateless agents. Common
patterns include:

- Ephemeral agents by default for isolation and repeatability.
- A small warm-agent buffer for frequently used pools where startup latency
  matters.
- Several pools segmented by trust, network, operating system, workload type,
  or compliance boundary.
- Carefully controlled stateful agents only for workloads whose caches or
  licensed tooling justify the security and maintenance trade-off.
- Autoscaling limits sized from observed queue time, not from the number of
  developers alone.
- Central golden-image pipelines that continuously patch, test, version, scan,
  and promote agent images.
- Least-privilege workload identities/service connections rather than user
  credentials on agents.
- Centralized artifact, log, package, and cache services.
- Cost and queue-time dashboards with concurrency adjusted from evidence.

At larger scale, a developer push does not imply one permanently assigned VM.
Jobs enter an organization queue; available parallel-job licenses and eligible
agents determine when they start. Path filters, batching, PR validation,
concurrency controls, and cancellation of superseded runs prevent unnecessary
work.

## Custom image management

The custom image preinstalls common tools such as Terraform, Azure CLI, Docker,
and Git. Prebaking large or stable dependencies reduces setup time, but the
image must be treated as a versioned product:

1. Build a new generalized image version.
2. Run vulnerability and functional tests.
3. Replicate it to the MDP region.
4. Point a test pool or image alias to the new version.
5. Run the smoke pipeline.
6. Promote it to normal pipelines.
7. Retain the previous version for rollback.

Using `/versions/latest` is convenient for this learning environment, but an
organization normally pins an exact version for deterministic builds and
updates it through a controlled promotion.

## Smoke test

`azure-pipelines-mdp-smoke.yml` verifies the complete agent path:

1. Confirms Linux, architecture, and custom image alias.
2. Checks Terraform, Azure CLI, Docker, and Git.
3. Confirms outbound traffic uses the expected NAT Gateway public IP.
4. Confirms ACR resolves into `10.10.2.0/27`.
5. Confirms ACR public access is disabled and public IP rules are empty.
6. Logs in, builds, pushes, removes, and pulls a disposable ACR image.

Run this after changing the image, VNet, DNS, NAT, ACR private endpoint, service
connection permissions, or pool configuration.

## Troubleshooting

### A job waits in the queue

Check:

- Azure DevOps parallel jobs currently in use.
- MDP maximum concurrency.
- Organization/project authorization for the pool.
- `ImageOverride` matches a configured alias.
- Regional VM-family quota and capacity.

### Agent creation is slow

Separate queue time, provisioning time, and task execution time in the run UI.
Possible responses are a warm buffer, a faster/smaller image, fewer job
boundaries, preinstalled tools, and a larger concurrency limit. Do not assume
the VM size is the cause without measuring each interval.

### `InvalidImageResourceId`

Confirm that the pool uses an ID ending in `/versions/latest` or an exact
`/versions/x.y.z`, the image version is replicated and generalized, and the
`DevOpsInfrastructure` principal has gallery reader access.

### ACR resolves publicly or cannot be reached

From an agent, check:

```bash
getent ahostsv4 skssolar.azurecr.io
curl -I https://skssolar.azurecr.io/v2/
```

The address should belong to `10.10.2.0/27`. An unauthenticated `401` proves
DNS, routing, TLS, and the registry endpoint are reachable. Authentication and
ACR data-plane authorization are separate checks.

### Pipeline files disappear

This is expected for a stateless pool. Publish the required files before the
job finishes and download them in the consuming job.

## Operational checklist

- Keep the agent image patched and versioned.
- Run the smoke pipeline after relevant infrastructure changes.
- Review Azure DevOps queue time and MDP utilization before increasing scale.
- Review service-connection permissions and rotate credentials, or prefer
  workload identity federation where supported.
- Keep ACR public access disabled and private DNS linked.
- Monitor NAT port utilization when concurrency grows significantly.
- Pin production image versions rather than relying indefinitely on `latest`.
- Set appropriate Azure DevOps run, artifact, test, and log retention policies.

