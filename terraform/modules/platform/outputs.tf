output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority" {
  description = "Base64 encoded cluster CA"
  value       = module.eks.cluster_certificate_authority
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "api_url" {
  description = "Public API URL"
  value       = "https://${local.api_host}"
}

output "frontend_url" {
  description = "Public frontend URL"
  value       = module.frontend.url
}

output "argocd_url" {
  description = "Argo CD UI URL"
  value       = module.argocd.url
}

output "ecr_repository_url" {
  description = "ECR repository for the API image"
  value       = module.ecr_api.repository_url
}

output "frontend_bucket" {
  description = "S3 bucket holding the frontend"
  value       = module.frontend.bucket_name
}

output "frontend_distribution_id" {
  description = "CloudFront distribution ID"
  value       = module.frontend.distribution_id
}

output "rds_address" {
  description = "RDS endpoint hostname"
  value       = module.rds.address
}
