variable "name" {
  description = "Name prefix for CloudFront resources"
  type        = string
}

variable "bucket_name" {
  description = "S3 bucket name for the site assets"
  type        = string
}

variable "domain_name" {
  description = "Public hostname of the site"
  type        = string
}

variable "zone_id" {
  description = "Route53 hosted zone for the alias record"
  type        = string
}

variable "certificate_arn" {
  description = "ACM certificate ARN in us-east-1"
  type        = string
}

variable "api_origin" {
  description = "Hostname the frontend calls, used for the CSP connect-src"
  type        = string
}

variable "price_class" {
  description = "CloudFront price class"
  type        = string
  default     = "PriceClass_100"
}

variable "tags" {
  description = "Extra tags for all resources"
  type        = map(string)
  default     = {}
}
