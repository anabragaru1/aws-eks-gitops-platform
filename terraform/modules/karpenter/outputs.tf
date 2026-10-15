output "controller_role_arn" {
  description = "IRSA role for the Karpenter controller"
  value       = module.controller_irsa.role_arn
}

output "node_role_name" {
  description = "IAM role name referenced by the EC2NodeClass"
  value       = aws_iam_role.node.name
}

output "node_role_arn" {
  description = "IAM role ARN of Karpenter nodes"
  value       = aws_iam_role.node.arn
}

output "interruption_queue_name" {
  description = "SQS queue Karpenter watches for interruption events"
  value       = aws_sqs_queue.interruption.name
}
