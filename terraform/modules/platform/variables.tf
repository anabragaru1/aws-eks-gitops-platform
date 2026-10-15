variable "project" {
  description = "Project name used as prefix for all resources"
  type        = string
}

variable "environment" {
  description = "Environment name, e.g. dev or prod"
  type        = string
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
  description = "Domain suffix for this environment, e.g. dev.example.com"
  type        = string
}

variable "alert_email" {
  description = "Email address receiving CloudWatch alarms"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "availability_zones" {
  description = "Availability zones to use"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs, one per AZ"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs, one per AZ"
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "Use a single NAT gateway to save cost"
  type        = bool
  default     = false
}

variable "cluster_version" {
  description = "EKS Kubernetes version"
  type        = string
}

variable "eks_public_access_cidrs" {
  description = "CIDRs allowed to reach the EKS public endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "node_groups" {
  description = "Managed node groups keyed by name"
  type = map(object({
    instance_types = list(string)
    capacity_type  = optional(string, "ON_DEMAND")
    min_size       = number
    max_size       = number
    desired_size   = number
    disk_size      = optional(number, 50)
    labels         = optional(map(string), {})
  }))
}

variable "ci_apply_role_arn" {
  description = "CI role that applies Terraform, gets cluster-admin"
  type        = string
}

variable "ci_plan_role_arn" {
  description = "CI role that plans Terraform, gets read-only cluster access"
  type        = string
}

variable "extra_admin_principal_arns" {
  description = "Additional IAM principals with cluster-admin access, e.g. an operator role"
  type        = list(string)
  default     = []
}

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
}

variable "rds_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "16.6"
}

variable "rds_multi_az" {
  description = "Multi-AZ deployment for RDS"
  type        = bool
  default     = false
}

variable "rds_deletion_protection" {
  description = "Protect the RDS instance from deletion"
  type        = bool
  default     = true
}

variable "rds_skip_final_snapshot" {
  description = "Skip the final RDS snapshot on destroy"
  type        = bool
  default     = false
}

variable "argocd_chart_version" {
  description = "argo-cd Helm chart version"
  type        = string
}

variable "argocd_high_availability" {
  description = "Run Argo CD in HA mode"
  type        = bool
  default     = false
}

variable "repo_url" {
  description = "Git repository Argo CD syncs from"
  type        = string
}

variable "target_revision" {
  description = "Branch Argo CD tracks"
  type        = string
  default     = "main"
}

variable "github_app_id" {
  description = "GitHub App ID for Argo CD repository access, empty for public repositories"
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

variable "tags" {
  description = "Extra tags for all resources"
  type        = map(string)
  default     = {}
}
