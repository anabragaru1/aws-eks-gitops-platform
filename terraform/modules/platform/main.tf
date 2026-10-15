data "aws_caller_identity" "current" {}

data "aws_route53_zone" "this" {
  name = var.hosted_zone_name
}

locals {
  name         = "${var.project}-${var.environment}"
  account_id   = data.aws_caller_identity.current.account_id
  api_host     = "api.${var.base_domain}"
  app_host     = "app.${var.base_domain}"
  argocd_host  = "argocd.${var.base_domain}"
  ingress_name = "${local.name}-public"
}

module "vpc" {
  source = "../vpc"

  name                 = local.name
  cidr                 = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  single_nat_gateway   = var.single_nat_gateway
  cluster_name         = local.name
  log_kms_key_arn      = aws_kms_key.logs.arn
  tags                 = var.tags
}

module "eks" {
  source = "../eks"

  cluster_name           = local.name
  cluster_version        = var.cluster_version
  log_kms_key_arn        = aws_kms_key.logs.arn
  subnet_ids             = module.vpc.private_subnet_ids
  endpoint_public_access = true
  public_access_cidrs    = var.eks_public_access_cidrs
  admin_principal_arns   = concat([var.ci_apply_role_arn], var.extra_admin_principal_arns)
  viewer_principal_arns  = [var.ci_plan_role_arn]
  node_groups            = var.node_groups
  tags                   = var.tags
}

module "ecr_api" {
  source = "../ecr"

  name = "${var.project}-api"
  tags = var.tags
}

# Regional certificate for everything behind the ALB.
module "acm_alb" {
  source = "../acm"

  domain_name               = local.api_host
  subject_alternative_names = [local.argocd_host]
  zone_id                   = data.aws_route53_zone.this.zone_id
  tags                      = var.tags
}

# CloudFront certificates must live in us-east-1.
module "acm_cloudfront" {
  source = "../acm"
  providers = {
    aws = aws.us_east_1
  }

  domain_name = local.app_host
  zone_id     = data.aws_route53_zone.this.zone_id
  tags        = var.tags
}

module "rds" {
  source = "../rds"

  name                       = local.name
  engine_version             = var.rds_engine_version
  instance_class             = var.rds_instance_class
  multi_az                   = var.rds_multi_az
  vpc_id                     = module.vpc.vpc_id
  subnet_ids                 = module.vpc.private_subnet_ids
  allowed_security_group_ids = [module.eks.cluster_security_group_id]
  database_name              = "app"
  deletion_protection        = var.rds_deletion_protection
  skip_final_snapshot        = var.rds_skip_final_snapshot
  tags                       = var.tags
}

module "frontend" {
  source = "../static-site"

  name            = "${local.name}-frontend"
  bucket_name     = "${local.name}-frontend-${local.account_id}"
  domain_name     = local.app_host
  zone_id         = data.aws_route53_zone.this.zone_id
  certificate_arn = module.acm_cloudfront.certificate_arn
  api_origin      = local.api_host
  tags            = var.tags
}

module "monitoring" {
  source = "../monitoring"
  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  name                       = local.name
  alert_email                = var.alert_email
  cluster_name               = module.eks.cluster_name
  rds_instance_id            = module.rds.instance_id
  cloudfront_distribution_id = module.frontend.distribution_id
  tags                       = var.tags
}
