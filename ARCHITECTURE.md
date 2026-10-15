# Architecture

A small production-style platform on AWS: a React frontend served from S3 and CloudFront,
a Go API running on EKS behind an Application Load Balancer, PostgreSQL on RDS, and
everything provisioned and deployed by GitHub Actions with Argo CD handling the cluster side.

```
                 GitHub Actions (OIDC, no stored AWS keys)
                 ┌──────────────────────┬─────────────────────┬──────────────────────┐
                 │ terraform plan/apply │ api build + push    │ frontend build       │
                 └──────────┬───────────┴──────────┬──────────┴──────────┬───────────┘
                            │                      │ commits image tag   │ s3 sync + invalidation
                            ▼                      ▼                     ▼
  ┌──────────────────────────────────────── AWS account ─────────────────────────────────────┐
  │  Route53 ── ACM                                                                         │
  │                                                                                         │
  │  app.<domain> ──▶ CloudFront ──▶ S3 (private, OAC)                                      │
  │                                                                                         │
  │  api.<domain> ──▶ ALB (public subnets) ──▶ EKS (private subnets) ──▶ RDS (private)      │
  │  argocd.<domain> ─┘                         │                                           │
  │                                             ├─ Argo CD ◀── Git (app-of-apps)            │
  │                                             ├─ aws-load-balancer-controller (IRSA)      │
  │                                             ├─ karpenter (IRSA) ──▶ EC2 NodePool        │
  │                                             ├─ external-dns (IRSA, zone scoped)         │
  │                                             ├─ external-secrets (IRSA) ◀── Secrets Mgr  │
  │                                             └─ api (Deployment, HPA, PDB, NetworkPolicy)│
  │                                                                                         │
  │  CloudWatch alarms ──▶ SNS ──▶ email        ECR (immutable, scanned)   SSM parameters   │
  └─────────────────────────────────────────────────────────────────────────────────────────┘
```

## Repository layout

| Path | Purpose |
|---|---|
| `terraform/bootstrap` | State bucket, GitHub OIDC provider, the three CI roles |
| `terraform/modules/*` | Building blocks: `vpc`, `eks`, `karpenter`, `irsa`, `rds`, `ecr`, `acm`, `static-site`, `monitoring`, `argocd` |
| `terraform/modules/platform` | Composes the building blocks into one environment and bootstraps Argo CD |
| `terraform/environments/{dev,prod}` | Thin roots: provider config, backend, sizing per environment |
| `kubernetes/argocd/root` | App-of-apps chart declaring every Argo CD Application |
| `kubernetes/platform/*` | Values for the add-on charts, the Karpenter `NodePool`/`EC2NodeClass` and the `ClusterSecretStore` |
| `kubernetes/apps/api` | Helm chart for the API, `values-<env>.yaml` holds the deployed image tag |
| `apps/api`, `apps/frontend` | Application code |
| `.github/workflows` | Infrastructure and application pipelines |
| `scripts` | Validation helpers shared by CI and local runs |

## Infrastructure

**Network.** One VPC per environment with public and private subnets in three AZs. Only
the ALB and NAT gateways sit in public subnets; EKS nodes and RDS are private. Dev uses a
single NAT gateway, prod one per AZ. Subnets carry the `kubernetes.io/role/*` tags the
load balancer controller uses for discovery. VPC flow logs go to an encrypted log group.

**EKS.** Managed node groups on AL2023 in the private subnets. Authentication uses access
entries (`authentication_mode = API`) instead of the `aws-auth` ConfigMap, so cluster
access is an IAM resource: the apply role gets `AmazonEKSClusterAdminPolicy`, the plan
role gets `AmazonEKSAdminViewPolicy` (the Helm provider needs to read release secrets
during `plan`). Secrets are envelope-encrypted with KMS, control plane logs are on, and
the core add-ons (VPC CNI with network policy enforcement, CoreDNS, kube-proxy, EBS CSI,
metrics-server, CloudWatch Observability) are managed as EKS add-ons with versions
resolved at plan time. Node CPU, memory and failed-node alarms come from Container
Insights.

**Karpenter.** The managed node group is a small system pool that only hosts the
platform controllers (Argo CD, Karpenter itself, the load balancer controller,
ExternalDNS, ESO, CoreDNS). Application capacity comes from Karpenter: the API chart
sets `nodeSelector: karpenter.sh/nodepool=apps`, so its pods are pending until Karpenter
launches right-sized nodes from the `apps` `NodePool`. Terraform provides the AWS side
(`terraform/modules/karpenter`: controller IRSA role with the upstream policy scoped to
this cluster, node role with an EKS access entry, SQS interruption queue fed by
EventBridge, `karpenter.sh/discovery` tags on the private subnets and the cluster
security group). Argo CD installs the controller from the official OCI chart and, in a
second Application, the `EC2NodeClass` (AL2023, IMDSv2 only, encrypted gp3 root volume)
and the `NodePool`. Dev allows Spot and On-Demand with a small CPU limit; prod is
On-Demand only. Consolidation is on, nodes expire after 30 days so the AMI rolls.

**RDS.** PostgreSQL in the private subnets, reachable only from the cluster security
group, storage and Performance Insights encrypted with a dedicated KMS key, `rds.force_ssl`
on, enhanced monitoring, and IAM authentication enabled for a future move away from
passwords. The master password is generated by RDS inside Secrets Manager
(`manage_master_user_password`), so Terraform never sees or stores it.

**Frontend.** Private S3 bucket behind CloudFront with Origin Access Control, TLS 1.2+,
HTTP/3, a security headers policy (HSTS, CSP, frame-ancestors, nosniff) and SPA fallback.
The certificate is issued in `us-east-1` through a second provider alias.

**Certificates and DNS.** The platform assumes an existing public hosted zone. ACM
certificates are DNS-validated, with one regional certificate for the ALB (`api.` and
`argocd.`) and one in `us-east-1` for CloudFront (`app.`). ExternalDNS creates the ALB
records, Terraform creates the CloudFront alias.

**Monitoring.** CloudWatch alarms for RDS (CPU, free storage, connections), EKS nodes
(CPU, memory, failed nodes) and the CloudFront 5xx rate, routed to KMS-encrypted SNS
topics with an email subscription. CloudFront metrics only exist in `us-east-1`, so that
alarm and its topic live there.

**Outputs as a contract.** Terraform writes the ECR URL, frontend bucket, CloudFront
distribution ID and public URLs to SSM Parameter Store under `/gitops-platform/<env>/`.
The application workflows read those parameters instead of Terraform state, which keeps
the app pipelines decoupled from the infrastructure pipeline and its permissions.

## Security choices

**OIDC from GitHub Actions.** No AWS access keys are stored in GitHub. The bootstrap
stack creates an OIDC identity provider and three roles with trust policies pinned to
this repository: `gha-terraform-plan` (pull requests only, `ReadOnlyAccess` plus state
access), `gha-terraform-apply` (the `main` branch and the `dev`/`prod` GitHub
Environments; service-scoped policy with IAM writes limited to the project prefix) and
`gha-app-deploy` (ECR push, frontend bucket, CloudFront invalidation, SSM read).
Workflows request `id-token: write` and assume the role with
`aws-actions/configure-aws-credentials`.

**IRSA.** Each add-on that talks to AWS has its own IAM role trusted only by its
`namespace/service-account` pair: Karpenter (upstream controller policy, every EC2 and
instance-profile action conditioned on the cluster tag), the load balancer controller
(upstream policy), ExternalDNS (`ChangeResourceRecordSets` on the one hosted zone) and
External Secrets Operator (`GetSecretValue` on the RDS secret and the project's secret
prefix, plus `kms:Decrypt` on the RDS key). The API itself has no AWS permissions; it
only receives the database credentials.

**Secrets flow.** RDS writes the master credentials to Secrets Manager. The
`ClusterSecretStore` authenticates with the ESO service account's IRSA role. The API chart
declares an `ExternalSecret` that materialises `username`/`password` into a Kubernetes
Secret, which the Deployment reads as environment variables. Rotation by RDS propagates
on the next refresh interval; a rollout restart picks it up.

**Workload hardening.** Non-root, read-only root filesystem, all capabilities dropped,
seccomp `RuntimeDefault`, no service account token mounted, resource requests and
limits, a `NetworkPolicy` that only allows ingress on the HTTP port and egress to DNS and
PostgreSQL, an HPA, a PDB and zone topology spreading. Images are distroless, built from
a pinned Go base, scanned with Trivy before they are pushed, and ECR tags are immutable.

**Supply chain.** Every GitHub Action is pinned to a commit SHA, Terraform providers are
version-constrained with a lock file, Helm chart versions are pinned in Git, and
Dependabot watches actions, Terraform, Go modules, npm and the Docker base image.

## CI/CD design

Everything runs in GitHub Actions. There is no step that requires a laptop.

### Bootstrap (once per account)

`bootstrap.yml` is dispatched manually with a typed confirmation. The first run uses a
short-lived IAM user key stored as `AWS_BOOTSTRAP_*` secrets, because the OIDC provider
cannot create itself. It applies `terraform/bootstrap` with local state, then migrates
that state into the bucket it just created. The job summary tells you to delete the
bootstrap secrets; from then on the same workflow, and every other one, uses OIDC. If
even a one-time key is unwanted, apply `terraform/bootstrap` once from AWS CloudShell
with the same inputs; the credentials then never leave AWS and the workflow is only used
for later changes.

### Infrastructure

- `terraform-plan.yml` runs on pull requests touching `terraform/**`: `fmt`, `validate`
  for every root and module, `tflint`, `checkov`, then a plan for both `dev` and `prod`
  with the read-only role. The plan is posted as a single, updated comment per
  environment.
- `terraform-apply.yml` runs on merge to `main`: plan and apply `dev`, then `prod`. The
  `prod` job targets the `prod` GitHub Environment, which carries a required-reviewer
  rule. Approval happens in the GitHub UI, the apply itself is still fully automated.
  Concurrency groups serialise runs per environment.
- `terraform-destroy.yml` is manual, needs `destroy-<env>` typed in, removes Argo CD first
  so the controllers release the ALB and DNS records, then destroys the rest.

Terraform installs Argo CD with the Helm provider and immediately applies a tiny local
chart with two `AppProject`s and the root `Application`. Terraform outputs (VPC ID, role
ARNs, certificate ARN, database endpoint and secret ARN, ECR URL) are passed as
`valuesObject` on that root Application, so the Git repository never contains
account-specific values.

### Cluster add-ons and application (GitOps)

The root chart in `kubernetes/argocd/root` renders one `Application` per component:

| Application | Source | Sync wave |
|---|---|---|
| `karpenter` | official OCI chart + values from Git | -4 |
| `aws-load-balancer-controller` | upstream chart + values from Git | -3 |
| `external-secrets` | upstream chart + values from Git | -3 |
| `external-dns` | upstream chart + values from Git | -2 |
| `karpenter-nodepools` | `kubernetes/platform/karpenter/nodepools` | -1 |
| `external-secrets-stores` | `kubernetes/platform/external-secrets/stores` | -1 |
| `api` | `kubernetes/apps/api` | 0 |

Add-ons use Argo CD multi-source Applications: the chart comes from the upstream Helm
repository, the static values from this repository, and the dynamic values from
Terraform. Sync waves plus the `Application` health check in `argocd-cm` make the root
app wait for the CRDs before applying `NodePool`, `ClusterSecretStore` and
`ExternalSecret` resources. All Applications are automated with prune and self-heal.

### Application delivery

- `api-ci.yml`: on pull requests it vets, lints, tests, builds the image and scans it. On
  `main` it additionally pushes the image to ECR tagged with the commit SHA, writes that
  tag into `kubernetes/apps/api/values-dev.yaml` and pushes the commit. Argo CD sees the
  change and rolls dev. Pushes made with `GITHUB_TOKEN` do not trigger workflows, so
  there is no loop.
- `api-promote.yml`: manual dispatch that copies the dev tag (or a given one) into
  `values-prod.yaml` through a pull request. Merging the pull request is the prod
  deployment. Database migrations run as an Argo CD `PreSync` hook before each rollout.
- `frontend-deploy.yml`: lints, tests and builds on pull requests; on `main` it builds
  with the API URL from SSM, syncs to S3 (immutable cache headers for hashed assets,
  `no-cache` for `index.html`) and invalidates CloudFront, dev first then prod.
- `k8s-validate.yml`: lints every chart, validates rendered manifests with kubeconform
  against Kubernetes and CRD schemas, then installs real Argo CD on a kind cluster, applies
  the bootstrap chart against the pull request revision and fails if any Application
  cannot be rendered.

### Backend behaviour

`GET /` on the API runs `SELECT 1` against RDS and answers:

```json
{"pod_name": "api-79b88448f4-x8z2k", "db_status": "connected", "timestamp": "2026-10-12T09:44:00Z"}
```

`pod_name` comes from the Downward API, `db_status` turns into `disconnected` with a
503 when the query fails. The Deployment keeps at least two replicas (HPA minimum, PDB,
zone spread) and the ALB targets pod IPs directly (`target-type: ip`), so consecutive
requests rotate across pods:

```sh
for i in $(seq 1 6); do curl -s https://api.<domain>/ | jq -r .pod_name; done
```

`/healthz` (liveness, ALB health check) and `/readyz` (readiness, pings the database)
stay separate so a database outage takes pods out of rotation without restarting them.

## Trade-offs

- **Public EKS endpoint.** GitHub-hosted runners must reach the API server for the Helm
  provider and Argo CD bootstrap. The endpoint is public with private access enabled and
  an allow-list variable; the next step would be self-hosted runners in the VPC and a
  private-only endpoint.
- **Monorepo.** Infrastructure, manifests and code live together so one pull request can
  carry a change end to end. At larger scale the `kubernetes/` tree would move to its own
  repository with its own review rules.
- **Prod approval gate.** A required reviewer on the `prod` environment is a deliberate
  pause in an otherwise automated pipeline. It can be removed by deleting the rule; the
  workflow does not change.
- **Master database user for the API.** Simplest secure path through Secrets Manager and
  ESO. A follow-up would create an application role in a migration and use IAM database
  authentication, which is already enabled on the instance.
- **Argo CD admin login.** The UI is exposed behind the ALB with the generated admin
  password. SSO through Dex or an OIDC provider is the production next step.
- **CloudFront logging, WAF and geo restrictions** are left out to keep the module focused;
  the checkov skips record each one.
- **Bootstrap credential.** One static key, used once and deleted, is the only
  non-OIDC credential ever involved.
- **System node group plus Karpenter.** Karpenter cannot schedule itself, so a small
  managed node group stays for the controllers. The alternative, EKS Auto Mode, removes
  that group but hides the node configuration this repository is meant to show.
- **AMI alias `al2023@latest`.** Convenient while iterating; production should pin a dated
  alias in `values-prod.yaml` and let the 30-day node expiry roll it forward.

## Step-by-step: from an empty account to a running application

1. **Prerequisites.** An AWS account, a public Route53 hosted zone for the domain, and a
   GitHub App (read-only `Contents`) installed on this repository for Argo CD if the
   repository is private.
2. **Repository configuration.**
   - Variables: `AWS_ACCOUNT_ID`, `AWS_REGION`, `ARGOCD_GITHUB_APP_ID`,
     `ARGOCD_GITHUB_APP_INSTALLATION_ID`. Jobs that touch AWS are skipped while
     `AWS_ACCOUNT_ID` is unset, so lint and test checks stay green before the account is wired.
   - Secrets: `ARGOCD_GITHUB_APP_PRIVATE_KEY`, and for the first run only
     `AWS_BOOTSTRAP_ACCESS_KEY_ID` / `AWS_BOOTSTRAP_SECRET_ACCESS_KEY`.
   - Environments: `bootstrap`, `dev`, `prod` (add a required reviewer on `prod`).
   - Edit `terraform/environments/*/terraform.tfvars` with the hosted zone, domains and
     alert email.
3. **Bootstrap.** Run the *Bootstrap* workflow with `bootstrap` as confirmation. Delete the
   two bootstrap secrets afterwards.
4. **Provision.** Merge the repository to `main` (or run *Terraform apply* manually). The
   `dev` job creates the network, cluster, database, registry, CDN, alarms and Argo CD;
   approve the `prod` job when the environment is wanted. Confirm the SNS subscription
   email.
5. **Deploy the API.** Any merge touching `apps/api` builds, scans and pushes the image and
   commits the new tag for dev. Argo CD rolls it out, running migrations first. Run *API
   promote to prod* and merge the pull request to promote.
6. **Deploy the frontend.** Any merge touching `apps/frontend` publishes to dev and prod.
7. **Verify.** `https://api.<domain>/` returns the JSON above with a rotating
   `pod_name`, `https://app.<domain>` serves the frontend over HTTPS, and
   `https://argocd.<domain>` shows every Application `Synced`/`Healthy`.
8. **Tear down.** Follow the section below.

## Teardown, step by step

Everything is removed by the *Terraform destroy* workflow; nothing needs a local CLI.

1. **Promote nothing further.** Pause merges to `main` so no apply runs concurrently
   (the `terraform-<env>` concurrency group would queue it anyway).
2. **Run *Terraform destroy*** for the environment with `destroy-<env>` as confirmation.
   For `prod` the GitHub Environment reviewer has to approve the job. The workflow:
   - deletes the `api` and `karpenter-nodepools` Applications first, so the load balancer
     controller removes the ALB target groups and Karpenter drains and terminates its
     nodes while both controllers are still running;
   - destroys the Argo CD Helm releases, which removes the remaining Applications, the
     shared ALB and the DNS records (ExternalDNS runs with `policy: sync`), then waits two
     minutes for the AWS side to settle;
   - runs a full `terraform destroy`, which drops the cluster, node group, RDS instance
     (`dev`: no final snapshot; `prod`: `deletion_protection` is on, so flip
     `rds_deletion_protection` to `false` in a pull request first, the final snapshot
     `gitops-platform-prod-final` is kept), the frontend bucket and distribution, the
     ECR repository and images, alarms, SNS topics, KMS keys (30-day deletion window)
     and the VPC.
3. **Check for leftovers.** The hosted zone is not managed here; confirm no `api.` or
   `argocd.` records remain. Confirm no EC2 instances carry the
   `kubernetes.io/cluster/<name>` tag. Both are empty when the controllers finished before
   step 2 removed them; otherwise delete them from the console or CLI.
4. **Repeat for the other environment** if both were created.
5. **Bootstrap stack (optional).** The state bucket, KMS key, OIDC provider and CI roles
   live in `terraform/bootstrap` with `prevent_destroy` on the bucket. Keep them if the
   account will be reused. To remove them: empty the bucket, drop the `prevent_destroy`
   lifecycle, and run `terraform destroy` in `terraform/bootstrap` with the apply role
   or an administrator; this is the one step that is intentionally not automated.
6. **GitHub side.** Delete the `AWS_*` repository variables and the `ARGOCD_*` secrets,
   and remove the three GitHub Environments.
