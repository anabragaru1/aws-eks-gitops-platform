output "namespace" {
  description = "Namespace Argo CD runs in"
  value       = helm_release.argocd.namespace
}

output "url" {
  description = "Argo CD UI URL"
  value       = "https://${var.hostname}"
}
