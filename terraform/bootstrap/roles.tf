# Shared: read/write access to the state bucket.
data "aws_iam_policy_document" "state_access" {
  statement {
    sid       = "ListStateBucket"
    actions   = ["s3:ListBucket", "s3:GetBucketVersioning"]
    resources = [aws_s3_bucket.state.arn]
  }

  statement {
    sid       = "ReadWriteState"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.state.arn}/*"]
  }

  statement {
    sid       = "UseStateKey"
    actions   = ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey"]
    resources = [aws_kms_key.state.arn]
  }
}

resource "aws_iam_policy" "state_access" {
  name   = "${var.project}-tfstate-access"
  policy = data.aws_iam_policy_document.state_access.json
}

# Plan role: read-only on AWS plus state access, used from pull requests.
resource "aws_iam_role" "terraform_plan" {
  name                 = "${var.project}-gha-terraform-plan"
  assume_role_policy   = data.aws_iam_policy_document.assume_plan.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "plan_readonly" {
  role       = aws_iam_role.terraform_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "plan_state" {
  role       = aws_iam_role.terraform_plan.name
  policy_arn = aws_iam_policy.state_access.arn
}

# Apply role: scoped to the services this platform provisions, used from main / environments.
# A provisioning role is wide by nature; IAM writes are limited to the project prefix below.
data "aws_iam_policy_document" "terraform_apply" {
  #checkov:skip=CKV_AWS_107:Provisioning role needs these services
  #checkov:skip=CKV_AWS_108:Provisioning role needs these services
  #checkov:skip=CKV_AWS_109:IAM writes are restricted to the project prefix
  #checkov:skip=CKV_AWS_111:Provisioning role needs these services
  #checkov:skip=CKV_AWS_356:Provisioning role needs these services
  statement {
    sid = "PlatformServices"
    actions = [
      "ec2:*",
      "eks:*",
      "rds:*",
      "s3:*",
      "cloudfront:*",
      "acm:*",
      "route53:*",
      "kms:*",
      "logs:*",
      "cloudwatch:*",
      "sns:*",
      "ecr:*",
      "ssm:*",
      "secretsmanager:*",
      "elasticloadbalancing:*",
      "autoscaling:*",
      "sts:GetCallerIdentity",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "ReadIam"
    actions   = ["iam:Get*", "iam:List*"]
    resources = ["*"]
  }

  statement {
    sid = "ManageProjectIam"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:UpdateRole",
      "iam:UpdateRoleDescription",
      "iam:UpdateAssumeRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:PassRole",
      "iam:CreatePolicy",
      "iam:DeletePolicy",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion",
      "iam:TagPolicy",
      "iam:UntagPolicy",
      "iam:CreateInstanceProfile",
      "iam:DeleteInstanceProfile",
      "iam:AddRoleToInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:TagInstanceProfile",
    ]
    resources = [
      "arn:aws:iam::${local.account_id}:role/${var.project}-*",
      "arn:aws:iam::${local.account_id}:policy/${var.project}-*",
      "arn:aws:iam::${local.account_id}:instance-profile/${var.project}-*",
    ]
  }

  statement {
    sid = "OidcAndServiceLinkedRoles"
    actions = [
      "iam:CreateOpenIDConnectProvider",
      "iam:DeleteOpenIDConnectProvider",
      "iam:TagOpenIDConnectProvider",
      "iam:UpdateOpenIDConnectProviderThumbprint",
      "iam:CreateServiceLinkedRole",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "terraform_apply" {
  name   = "${var.project}-gha-terraform-apply"
  policy = data.aws_iam_policy_document.terraform_apply.json
}

resource "aws_iam_role" "terraform_apply" {
  name                 = "${var.project}-gha-terraform-apply"
  assume_role_policy   = data.aws_iam_policy_document.assume_apply.json
  max_session_duration = 7200
}

resource "aws_iam_role_policy_attachment" "apply_platform" {
  role       = aws_iam_role.terraform_apply.name
  policy_arn = aws_iam_policy.terraform_apply.arn
}

resource "aws_iam_role_policy_attachment" "apply_state" {
  role       = aws_iam_role.terraform_apply.name
  policy_arn = aws_iam_policy.state_access.arn
}

# App deploy role: push images, publish the frontend, read platform parameters.
data "aws_iam_policy_document" "app_deploy" {
  statement {
    sid       = "EcrLogin"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "EcrPush"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
      "ecr:DescribeImages",
    ]
    resources = ["arn:aws:ecr:${var.region}:${local.account_id}:repository/${var.project}-*"]
  }

  statement {
    sid     = "FrontendBucket"
    actions = ["s3:ListBucket", "s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = [
      "arn:aws:s3:::${var.project}-*-frontend-*",
      "arn:aws:s3:::${var.project}-*-frontend-*/*",
    ]
  }

  statement {
    sid       = "CloudFrontInvalidate"
    actions   = ["cloudfront:CreateInvalidation", "cloudfront:GetInvalidation"]
    resources = ["arn:aws:cloudfront::${local.account_id}:distribution/*"]
  }

  statement {
    sid       = "ReadPlatformParameters"
    actions   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
    resources = ["arn:aws:ssm:${var.region}:${local.account_id}:parameter/${var.project}/*"]
  }
}

resource "aws_iam_policy" "app_deploy" {
  name   = "${var.project}-gha-app-deploy"
  policy = data.aws_iam_policy_document.app_deploy.json
}

resource "aws_iam_role" "app_deploy" {
  name                 = "${var.project}-gha-app-deploy"
  assume_role_policy   = data.aws_iam_policy_document.assume_apply.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "app_deploy" {
  role       = aws_iam_role.app_deploy.name
  policy_arn = aws_iam_policy.app_deploy.arn
}
