data "aws_iam_policy_document" "logs_key" {
  #checkov:skip=CKV_AWS_109:Standard KMS key policy, resource must be "*"
  #checkov:skip=CKV_AWS_111:Standard KMS key policy, resource must be "*"
  #checkov:skip=CKV_AWS_356:Standard KMS key policy, resource must be "*"
  statement {
    sid       = "AccountAdmin"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id}:root"]
    }
  }

  statement {
    sid = "CloudWatchLogs"
    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*",
    ]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["logs.${var.region}.amazonaws.com"]
    }

    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${var.region}:${local.account_id}:log-group:*"]
    }
  }
}

# One key for every CloudWatch log group in the environment.
resource "aws_kms_key" "logs" {
  description             = "${local.name} CloudWatch Logs encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.logs_key.json
  tags                    = var.tags
}

resource "aws_kms_alias" "logs" {
  name          = "alias/${local.name}-logs"
  target_key_id = aws_kms_key.logs.key_id
}
