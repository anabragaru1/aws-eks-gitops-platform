resource "aws_kms_key" "sns" {
  description             = "${var.name} alerts topic encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags                    = var.tags
}

data "aws_iam_policy_document" "sns_key" {
  #checkov:skip=CKV_AWS_109:Standard KMS key policy, resource must be "*"
  #checkov:skip=CKV_AWS_111:Standard KMS key policy, resource must be "*"
  #checkov:skip=CKV_AWS_356:Standard KMS key policy, resource must be "*"
  statement {
    sid       = "AccountAdmin"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  statement {
    sid       = "CloudWatchPublish"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey*"]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }
  }
}

data "aws_caller_identity" "current" {}

resource "aws_kms_key_policy" "sns" {
  key_id = aws_kms_key.sns.id
  policy = data.aws_iam_policy_document.sns_key.json
}

resource "aws_sns_topic" "alerts" {
  name              = "${var.name}-alerts"
  kms_master_key_id = aws_kms_key.sns.id
  tags              = var.tags
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# CloudFront metrics only exist in us-east-1, so alarms there need a local topic.
resource "aws_kms_key" "sns_us_east_1" {
  provider = aws.us_east_1

  description             = "${var.name} alerts topic encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags                    = var.tags
}

resource "aws_kms_key_policy" "sns_us_east_1" {
  provider = aws.us_east_1

  key_id = aws_kms_key.sns_us_east_1.id
  policy = data.aws_iam_policy_document.sns_key.json
}

resource "aws_sns_topic" "alerts_us_east_1" {
  provider = aws.us_east_1

  name              = "${var.name}-alerts"
  kms_master_key_id = aws_kms_key.sns_us_east_1.id
  tags              = var.tags
}

resource "aws_sns_topic_subscription" "email_us_east_1" {
  provider = aws.us_east_1

  topic_arn = aws_sns_topic.alerts_us_east_1.arn
  protocol  = "email"
  endpoint  = var.alert_email
}
