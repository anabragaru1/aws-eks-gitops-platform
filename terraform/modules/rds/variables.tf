variable "name" {
  description = "Instance identifier"
  type        = string
}

variable "engine_version" {
  description = "PostgreSQL major.minor version"
  type        = string
  default     = "16.6"
}

variable "instance_class" {
  description = "Instance class"
  type        = string
}

variable "allocated_storage" {
  description = "Initial storage in GiB"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Storage autoscaling ceiling in GiB"
  type        = number
  default     = 100
}

variable "multi_az" {
  description = "Enable a standby replica in another AZ"
  type        = bool
  default     = false
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for the subnet group"
  type        = list(string)
}

variable "allowed_security_group_ids" {
  description = "Security groups allowed to connect on the database port"
  type        = list(string)
}

variable "database_name" {
  description = "Initial database name"
  type        = string
}

variable "master_username" {
  description = "Master username, password is managed in Secrets Manager"
  type        = string
  default     = "app_admin"
}

variable "backup_retention_days" {
  description = "Automated backup retention"
  type        = number
  default     = 7
}

variable "deletion_protection" {
  description = "Protect the instance from deletion"
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Skip the final snapshot on destroy"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Extra tags for all resources"
  type        = map(string)
  default     = {}
}
