variable "name" {
  description = "IAM role name"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the EKS cluster OIDC provider"
  type        = string
}

variable "oidc_provider_url" {
  description = "Issuer URL of the EKS cluster OIDC provider without https://"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace of the service account"
  type        = string
}

variable "service_account" {
  description = "Kubernetes service account name"
  type        = string
}

variable "policy_json" {
  description = "Inline IAM policy document in JSON, empty to skip"
  type        = string
  default     = ""
}

variable "managed_policy_arns" {
  description = "Managed policies to attach"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Extra tags for all resources"
  type        = map(string)
  default     = {}
}
