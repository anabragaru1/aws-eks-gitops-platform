# Upstream controller policy (karpenter-provider-aws cloudformation.yaml), scoped to this cluster.
module "controller_irsa" {
  source = "../irsa"

  name              = "${var.cluster_name}-karpenter"
  oidc_provider_arn = var.oidc_provider_arn
  oidc_provider_url = var.oidc_provider_url
  namespace         = var.namespace
  service_account   = var.service_account
  tags              = var.tags

  policy_json = templatefile("${path.module}/policies/controller.json.tftpl", {
    partition     = local.partition
    region        = local.region
    account_id    = local.account_id
    cluster_name  = var.cluster_name
    cluster_arn   = var.cluster_arn
    node_role_arn = aws_iam_role.node.arn
    queue_arn     = aws_sqs_queue.interruption.arn
  })
}
