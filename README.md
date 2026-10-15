# aws-eks-gitops-platform

Infrastructure, GitOps configuration and application code for a small web platform on
AWS: a React frontend on S3/CloudFront, a Go API on EKS behind an ALB with Karpenter
providing the nodes, PostgreSQL on RDS, Argo CD for cluster delivery and GitHub Actions
with OIDC for every pipeline.

See [ARCHITECTURE.md](ARCHITECTURE.md) for the design, security model, CI/CD flow,
trade-offs and the step-by-step runbook.

## Layout

```
.github/workflows   bootstrap, terraform plan/apply/destroy, api, frontend, k8s validation
terraform/          bootstrap stack, reusable modules, platform composition, dev/prod roots
kubernetes/         Argo CD app-of-apps, add-on values, Karpenter node pools, API Helm chart
apps/               api (Go) and frontend (React)
scripts/            validation helpers used by CI and locally
```

## Local checks

```sh
make check        # fmt, validate, tflint, actionlint, checkov, helm, kubeconform, go, npm
make help         # individual targets
```

Requires terraform, tflint, checkov, actionlint, helm, kubeconform, go, node and docker.
The pipelines run the same checks; nothing here is needed to deploy.
