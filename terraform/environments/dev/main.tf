locals {
  environment = "dev"

  tags = {
    Project     = var.project
    Environment = local.environment
    ManagedBy   = "terraform"
  }
}

data "aws_caller_identity" "current" {}

module "platform" {
  source = "../../modules/platform"
  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  project          = var.project
  environment      = local.environment
  region           = var.region
  hosted_zone_name = var.hosted_zone_name
  base_domain      = var.base_domain
  alert_email      = var.alert_email

  vpc_cidr             = "10.10.0.0/16"
  availability_zones   = ["${var.region}a", "${var.region}b", "${var.region}c"]
  public_subnet_cidrs  = ["10.10.0.0/20", "10.10.16.0/20", "10.10.32.0/20"]
  private_subnet_cidrs = ["10.10.64.0/19", "10.10.96.0/19", "10.10.128.0/19"]
  single_nat_gateway   = true

  cluster_version = "1.34"
  # Platform add-ons only; Karpenter provisions application capacity.
  node_groups = {
    system = {
      instance_types = ["t3.medium"]
      capacity_type  = "SPOT"
      min_size       = 2
      max_size       = 3
      desired_size   = 2
    }
  }

  ci_apply_role_arn          = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project}-gha-terraform-apply"
  ci_plan_role_arn           = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project}-gha-terraform-plan"
  extra_admin_principal_arns = var.extra_admin_principal_arns

  rds_instance_class      = "db.t4g.micro"
  rds_multi_az            = false
  rds_deletion_protection = false
  rds_skip_final_snapshot = true

  argocd_chart_version       = "10.10.3"
  argocd_high_availability   = false
  repo_url                   = var.repo_url
  github_app_id              = var.github_app_id
  github_app_installation_id = var.github_app_installation_id
  github_app_private_key     = var.github_app_private_key

  tags = local.tags
}
