output "role_arn" {
  description = "IAM role ARN to annotate on the service account"
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "IAM role name"
  value       = aws_iam_role.this.name
}
