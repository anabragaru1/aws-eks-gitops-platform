variable "name" {
  description = "Name prefix for VPC resources"
  type        = string
}

variable "cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "availability_zones" {
  description = "Availability zones to spread subnets across"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "One public subnet CIDR per availability zone"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "One private subnet CIDR per availability zone"
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "Use one NAT gateway for all private subnets instead of one per AZ"
  type        = bool
  default     = false
}

variable "cluster_name" {
  description = "EKS cluster name, used for subnet discovery tags"
  type        = string
}

variable "flow_log_retention_days" {
  description = "Retention for VPC flow logs in CloudWatch"
  type        = number
  default     = 365
}

variable "log_kms_key_arn" {
  description = "KMS key for the flow log group"
  type        = string
}

variable "tags" {
  description = "Extra tags for all resources"
  type        = map(string)
  default     = {}
}
