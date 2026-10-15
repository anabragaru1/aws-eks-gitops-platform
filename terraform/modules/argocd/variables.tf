variable "namespace" {
  description = "Namespace for Argo CD"
  type        = string
  default     = "argocd"
}

variable "chart_version" {
  description = "argo-cd Helm chart version"
  type        = string
}

variable "hostname" {
  description = "Public hostname for the Argo CD UI"
  type        = string
}

variable "certificate_arn" {
  description = "ACM certificate for the Argo CD ingress"
  type        = string
}

variable "ingress_group" {
  description = "ALB ingress group shared with the applications"
  type        = string
}

variable "high_availability" {
  description = "Run redundant controller, server and repo-server replicas"
  type        = bool
  default     = false
}

variable "repo_url" {
  description = "Git repository that Argo CD syncs from"
  type        = string
}

variable "target_revision" {
  description = "Branch or tag to track"
  type        = string
  default     = "main"
}

variable "root_path" {
  description = "Path of the root app-of-apps chart in the repository"
  type        = string
  default     = "kubernetes/argocd/root"
}

variable "github_app_id" {
  description = "GitHub App ID used for repository access, empty for public repositories"
  type        = string
  default     = ""
}

variable "github_app_installation_id" {
  description = "GitHub App installation ID"
  type        = string
  default     = ""
}

variable "github_app_private_key" {
  description = "GitHub App private key in PEM format"
  type        = string
  default     = ""
  sensitive   = true
}

variable "platform_values" {
  description = "Values handed to the root chart, carrying Terraform outputs into Argo CD"
  type        = any
}

