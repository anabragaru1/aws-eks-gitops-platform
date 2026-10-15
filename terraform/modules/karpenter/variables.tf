variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_arn" {
  description = "EKS cluster ARN"
  type        = string
}

variable "cluster_security_group_id" {
  description = "Cluster security group that Karpenter nodes join"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the cluster OIDC provider"
  type        = string
}

variable "oidc_provider_url" {
  description = "Issuer host of the cluster OIDC provider"
  type        = string
}

variable "namespace" {
  description = "Namespace Karpenter runs in"
  type        = string
  default     = "karpenter"
}

variable "service_account" {
  description = "Karpenter controller service account"
  type        = string
  default     = "karpenter"
}

variable "tags" {
  description = "Extra tags for all resources"
  type        = map(string)
  default     = {}
}
