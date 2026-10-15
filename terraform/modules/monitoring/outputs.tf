output "alerts_topic_arn" {
  description = "SNS topic receiving alarms in the main region"
  value       = aws_sns_topic.alerts.arn
}

output "alerts_topic_arn_us_east_1" {
  description = "SNS topic receiving CloudFront alarms"
  value       = aws_sns_topic.alerts_us_east_1.arn
}
