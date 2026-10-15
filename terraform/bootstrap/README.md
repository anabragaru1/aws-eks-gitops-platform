# bootstrap

One-time stack that creates what every other pipeline depends on:

- S3 bucket (versioned, KMS encrypted) for Terraform state, using native S3 locking
- GitHub OIDC identity provider
- `gha-terraform-plan`, `gha-terraform-apply` and `gha-app-deploy` IAM roles

It is applied by the `bootstrap` workflow. The first run uses local state and then
migrates it into the bucket it just created; later runs use OIDC like every other stack.
