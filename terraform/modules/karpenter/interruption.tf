# Spot interruptions, rebalance recommendations and health events reach Karpenter through SQS.
resource "aws_sqs_queue" "interruption" {
  name                      = var.cluster_name
  message_retention_seconds = 300
  sqs_managed_sse_enabled   = true
  tags                      = var.tags
}

data "aws_iam_policy_document" "queue" {
  statement {
    sid       = "EventBridgeSend"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.interruption.arn]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com", "sqs.amazonaws.com"]
    }
  }

  statement {
    sid       = "DenyHTTP"
    effect    = "Deny"
    actions   = ["sqs:*"]
    resources = [aws_sqs_queue.interruption.arn]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_sqs_queue_policy" "interruption" {
  queue_url = aws_sqs_queue.interruption.id
  policy    = data.aws_iam_policy_document.queue.json
}

locals {
  interruption_events = {
    scheduled-change     = { source = "aws.health", detail_type = "AWS Health Event" }
    spot-interruption    = { source = "aws.ec2", detail_type = "EC2 Spot Instance Interruption Warning" }
    rebalance            = { source = "aws.ec2", detail_type = "EC2 Instance Rebalance Recommendation" }
    instance-state       = { source = "aws.ec2", detail_type = "EC2 Instance State-change Notification" }
    capacity-reservation = { source = "aws.ec2", detail_type = "EC2 Capacity Reservation Instance Interruption Warning" }
  }
}

resource "aws_cloudwatch_event_rule" "interruption" {
  for_each = local.interruption_events

  name = "${var.cluster_name}-karpenter-${each.key}"
  tags = var.tags

  event_pattern = jsonencode({
    source        = [each.value.source]
    "detail-type" = [each.value.detail_type]
  })
}

resource "aws_cloudwatch_event_target" "interruption" {
  for_each = local.interruption_events

  rule      = aws_cloudwatch_event_rule.interruption[each.key].name
  target_id = "karpenter-interruption-queue"
  arn       = aws_sqs_queue.interruption.arn
}
