variable "project" {
  description = "Project name used as prefix for all resources"
  type        = string
  default     = "gitops-platform"
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "github_repository" {
  description = "GitHub repository allowed to assume the CI roles, in owner/name form"
  type        = string
}

variable "environments" {
  description = "Deployment environments that get a GitHub Environment trust"
  type        = list(string)
  default     = ["dev", "prod"]
}
