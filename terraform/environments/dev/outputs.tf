output "cluster_name" {
  description = "EKS cluster name"
  value       = module.platform.cluster_name
}

output "api_url" {
  description = "Public API URL"
  value       = module.platform.api_url
}

output "frontend_url" {
  description = "Public frontend URL"
  value       = module.platform.frontend_url
}

output "argocd_url" {
  description = "Argo CD UI URL"
  value       = module.platform.argocd_url
}

output "ecr_repository_url" {
  description = "ECR repository for the API image"
  value       = module.platform.ecr_repository_url
}
