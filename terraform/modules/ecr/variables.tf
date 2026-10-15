variable "name" {
  description = "Repository name"
  type        = string
}

variable "keep_last_images" {
  description = "Number of tagged images to keep"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Extra tags for all resources"
  type        = map(string)
  default     = {}
}
