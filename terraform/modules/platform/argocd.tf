module "argocd" {
  source = "../argocd"

  chart_version              = var.argocd_chart_version
  hostname                   = local.argocd_host
  certificate_arn            = module.acm_alb.certificate_arn
  ingress_group              = local.ingress_name
  high_availability          = var.argocd_high_availability
  repo_url                   = var.repo_url
  target_revision            = var.target_revision
  github_app_id              = var.github_app_id
  github_app_installation_id = var.github_app_installation_id
  github_app_private_key     = var.github_app_private_key

  platform_values = {
    source = {
      repoURL        = var.repo_url
      targetRevision = var.target_revision
    }
    environment = var.environment
    aws = {
      region       = var.region
      accountId    = local.account_id
      vpcId        = module.vpc.vpc_id
      clusterName  = module.eks.cluster_name
      hostedZoneId = data.aws_route53_zone.this.zone_id
      domain       = var.base_domain
      ingressGroup = local.ingress_name
    }
    roles = {
      albController   = module.irsa_alb_controller.role_arn
      externalDns     = module.irsa_external_dns.role_arn
      externalSecrets = module.irsa_external_secrets.role_arn
      karpenter       = module.karpenter.controller_role_arn
    }
    karpenter = {
      nodeRoleName      = module.karpenter.node_role_name
      interruptionQueue = module.karpenter.interruption_queue_name
    }
    api = {
      host           = local.api_host
      certificateArn = module.acm_alb.certificate_arn
      frontendOrigin = module.frontend.url
      image = {
        repository = module.ecr_api.repository_url
      }
      db = {
        host      = module.rds.address
        port      = module.rds.port
        name      = module.rds.database_name
        secretArn = module.rds.master_user_secret_arn
      }
    }
  }

  depends_on = [module.eks]
}
