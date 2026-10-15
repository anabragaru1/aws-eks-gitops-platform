variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for the control plane ENIs and nodes"
  type        = list(string)
}

variable "endpoint_public_access" {
  description = "Expose the API endpoint publicly (needed for GitHub-hosted runners)"
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "CIDRs allowed to reach the public API endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "admin_principal_arns" {
  description = "IAM principals that get cluster-admin access entries"
  type        = list(string)
  default     = []
}

variable "viewer_principal_arns" {
  description = "IAM principals that get read-only access entries"
  type        = list(string)
  default     = []
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

variable "log_retention_days" {
  description = "Retention for control plane logs"
  type        = number
  default     = 365
}

variable "log_kms_key_arn" {
  description = "KMS key for the control plane log group"
  type        = string
}

variable "tags" {
  description = "Extra tags for all resources"
  type        = map(string)
  default     = {}
}
