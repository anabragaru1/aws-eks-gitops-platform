output "state_bucket" {
  description = "S3 bucket holding Terraform state"
  value       = aws_s3_bucket.state.id
}

output "state_kms_key_arn" {
  description = "KMS key used for state encryption"
  value       = aws_kms_key.state.arn
}

output "oidc_provider_arn" {
  description = "GitHub OIDC provider ARN"
  value       = aws_iam_openid_connect_provider.github.arn
}

output "terraform_plan_role_arn" {
  description = "Role assumed by pull request plan workflows"
  value       = aws_iam_role.terraform_plan.arn
}

output "terraform_apply_role_arn" {
  description = "Role assumed by apply workflows"
  value       = aws_iam_role.terraform_apply.arn
}

output "app_deploy_role_arn" {
  description = "Role assumed by application deployment workflows"
  value       = aws_iam_role.app_deploy.arn
}
