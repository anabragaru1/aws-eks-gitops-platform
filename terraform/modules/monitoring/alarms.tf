locals {
  actions = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "${var.name}-rds-cpu-high"
  alarm_description   = "RDS CPU above 80% for 15 minutes"
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.actions
  ok_actions          = local.actions
  tags                = var.tags

  dimensions = {
    DBInstanceIdentifier = var.rds_instance_id
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_storage" {
  alarm_name          = "${var.name}-rds-storage-low"
  alarm_description   = "RDS free storage below threshold"
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  statistic           = "Minimum"
  period              = 300
  evaluation_periods  = 2
  threshold           = var.rds_free_storage_threshold_bytes
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.actions
  ok_actions          = local.actions
  tags                = var.tags

  dimensions = {
    DBInstanceIdentifier = var.rds_instance_id
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_connections" {
  alarm_name          = "${var.name}-rds-connections-high"
  alarm_description   = "RDS connection count above threshold"
  namespace           = "AWS/RDS"
  metric_name         = "DatabaseConnections"
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 2
  threshold           = var.rds_max_connections_threshold
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.actions
  ok_actions          = local.actions
  tags                = var.tags

  dimensions = {
    DBInstanceIdentifier = var.rds_instance_id
  }
}

resource "aws_cloudwatch_metric_alarm" "eks_node_cpu" {
  alarm_name          = "${var.name}-eks-node-cpu-high"
  alarm_description   = "Average node CPU above 80% for 15 minutes"
  namespace           = "ContainerInsights"
  metric_name         = "node_cpu_utilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.actions
  ok_actions          = local.actions
  tags                = var.tags

  dimensions = {
    ClusterName = var.cluster_name
  }
}

resource "aws_cloudwatch_metric_alarm" "eks_node_memory" {
  alarm_name          = "${var.name}-eks-node-memory-high"
  alarm_description   = "Average node memory above 85% for 15 minutes"
  namespace           = "ContainerInsights"
  metric_name         = "node_memory_utilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = 85
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.actions
  ok_actions          = local.actions
  tags                = var.tags

  dimensions = {
    ClusterName = var.cluster_name
  }
}

resource "aws_cloudwatch_metric_alarm" "eks_failed_nodes" {
  alarm_name          = "${var.name}-eks-failed-nodes"
  alarm_description   = "One or more nodes are not ready"
  namespace           = "ContainerInsights"
  metric_name         = "cluster_failed_node_count"
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 2
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.actions
  ok_actions          = local.actions
  tags                = var.tags

  dimensions = {
    ClusterName = var.cluster_name
  }
}

resource "aws_cloudwatch_metric_alarm" "cloudfront_5xx" {
  provider = aws.us_east_1

  alarm_name          = "${var.name}-cloudfront-5xx-rate"
  alarm_description   = "CloudFront 5xx error rate above 5%"
  namespace           = "AWS/CloudFront"
  metric_name         = "5xxErrorRate"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 5
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts_us_east_1.arn]
  ok_actions          = [aws_sns_topic.alerts_us_east_1.arn]
  tags                = var.tags

  dimensions = {
    DistributionId = var.cloudfront_distribution_id
    Region         = "Global"
  }
}
