module "karpenter" {
  source = "../karpenter"

  cluster_name              = module.eks.cluster_name
  cluster_arn               = module.eks.cluster_arn
  cluster_security_group_id = module.eks.cluster_security_group_id
  oidc_provider_arn         = module.eks.oidc_provider_arn
  oidc_provider_url         = module.eks.oidc_provider_url
  tags                      = var.tags
}
