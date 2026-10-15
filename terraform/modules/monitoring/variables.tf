variable "name" {
  description = "Name prefix for alarms and topics"
  type        = string
}

variable "alert_email" {
  description = "Email address subscribed to alerts"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "rds_instance_id" {
  description = "RDS instance identifier"
  type        = string
}

variable "rds_free_storage_threshold_bytes" {
  description = "Alarm when free storage drops below this"
  type        = number
  default     = 2147483648
}

variable "rds_max_connections_threshold" {
  description = "Alarm when connections exceed this"
  type        = number
  default     = 80
}

variable "cloudfront_distribution_id" {
  description = "CloudFront distribution to watch"
  type        = string
}

variable "tags" {
  description = "Extra tags for all resources"
  type        = map(string)
  default     = {}
}
