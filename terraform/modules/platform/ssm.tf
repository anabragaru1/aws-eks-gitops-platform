# Contract between the infrastructure pipeline and the application pipelines.
resource "aws_ssm_parameter" "outputs" {
  for_each = {
    "eks/cluster_name"         = module.eks.cluster_name
    "ecr/api"                  = module.ecr_api.repository_url
    "frontend/bucket"          = module.frontend.bucket_name
    "frontend/distribution_id" = module.frontend.distribution_id
    "frontend/url"             = module.frontend.url
    "api/url"                  = "https://${local.api_host}"
  }

  name  = "/${var.project}/${var.environment}/${each.key}"
  type  = "String"
  value = each.value
  tags  = var.tags
}
