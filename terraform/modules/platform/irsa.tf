module "irsa_alb_controller" {
  source = "../irsa"

  name              = "${local.name}-aws-load-balancer-controller"
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  namespace         = "kube-system"
  service_account   = "aws-load-balancer-controller"
  policy_json       = file("${path.module}/policies/aws-load-balancer-controller.json")
  tags              = var.tags
}

data "aws_iam_policy_document" "external_dns" {
  #checkov:skip=CKV_AWS_356:Route53 List* actions do not support resource-level permissions
  statement {
    actions   = ["route53:ChangeResourceRecordSets"]
    resources = [data.aws_route53_zone.this.arn]
  }

  statement {
    actions = [
      "route53:ListHostedZones",
      "route53:ListResourceRecordSets",
      "route53:ListTagsForResource",
    ]
    resources = ["*"]
  }
}

module "irsa_external_dns" {
  source = "../irsa"

  name              = "${local.name}-external-dns"
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  namespace         = "external-dns"
  service_account   = "external-dns"
  policy_json       = data.aws_iam_policy_document.external_dns.json
  tags              = var.tags
}

# Scoped to the RDS managed secret and the project's own secrets.
data "aws_iam_policy_document" "external_secrets" {
  statement {
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    resources = [
      module.rds.master_user_secret_arn,
      "arn:aws:secretsmanager:${var.region}:${local.account_id}:secret:${var.project}/${var.environment}/*",
    ]
  }

  statement {
    actions   = ["kms:Decrypt"]
    resources = [module.rds.kms_key_arn]
  }
}

module "irsa_external_secrets" {
  source = "../irsa"

  name              = "${local.name}-external-secrets"
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  namespace         = "external-secrets"
  service_account   = "external-secrets"
  policy_json       = data.aws_iam_policy_document.external_secrets.json
  tags              = var.tags
}
