variable "domain_name" {
  description = "Primary domain for the certificate"
  type        = string
}

variable "subject_alternative_names" {
  description = "Additional domains on the certificate"
  type        = list(string)
  default     = []
}

variable "zone_id" {
  description = "Route53 hosted zone for DNS validation"
  type        = string
}

variable "tags" {
  description = "Extra tags for all resources"
  type        = map(string)
  default     = {}
}
