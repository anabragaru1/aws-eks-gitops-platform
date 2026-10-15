output "cluster_name" {
  description = "Cluster name"
  value       = aws_eks_cluster.this.name
}

output "cluster_arn" {
  description = "Cluster ARN"
  value       = aws_eks_cluster.this.arn
}

output "cluster_endpoint" {
  description = "API server endpoint"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority" {
  description = "Base64 encoded cluster CA"
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_security_group_id" {
  description = "Security group shared by control plane and nodes"
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "oidc_provider_arn" {
  description = "IAM OIDC provider ARN for IRSA"
  value       = aws_iam_openid_connect_provider.this.arn
}

output "oidc_provider_url" {
  description = "OIDC issuer host for IRSA trust policies"
  value       = local.oidc_provider_url
}

output "node_role_arn" {
  description = "IAM role used by worker nodes"
  value       = aws_iam_role.node.arn
}

output "addons_ready" {
  description = "Dependency handle that resolves once core addons are installed"
  value = [
    aws_eks_addon.coredns.id,
    aws_eks_addon.ebs_csi.id,
    aws_eks_addon.metrics_server.id,
  ]
}
