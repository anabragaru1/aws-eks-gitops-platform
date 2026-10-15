output "bucket_name" {
  description = "S3 bucket holding the site"
  value       = aws_s3_bucket.this.id
}

output "distribution_id" {
  description = "CloudFront distribution ID, used for cache invalidation"
  value       = aws_cloudfront_distribution.this.id
}

output "distribution_domain_name" {
  description = "CloudFront domain name"
  value       = aws_cloudfront_distribution.this.domain_name
}

output "url" {
  description = "Public site URL"
  value       = "https://${var.domain_name}"
}
