variable "project" {
  description = "Project name used as prefix for all resources"
  type        = string
  default     = "gitops-platform"
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "hosted_zone_name" {
  description = "Existing Route53 public hosted zone"
  type        = string
}

variable "base_domain" {
  description = "Domain suffix for this environment"
  type        = string
}

variable "alert_email" {
  description = "Email address receiving CloudWatch alarms"
  type        = string
}

variable "repo_url" {
  description = "Git repository Argo CD syncs from"
  type        = string
}

variable "github_app_id" {
  description = "GitHub App ID for Argo CD repository access"
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

variable "extra_admin_principal_arns" {
  description = "Additional IAM principals with cluster-admin access"
  type        = list(string)
  default     = []
}
