module "vpc_cni_irsa" {
  source = "../irsa"

  name                = "${var.cluster_name}-vpc-cni"
  oidc_provider_arn   = aws_iam_openid_connect_provider.this.arn
  oidc_provider_url   = local.oidc_provider_url
  namespace           = "kube-system"
  service_account     = "aws-node"
  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"]
  tags                = var.tags
}

module "ebs_csi_irsa" {
  source = "../irsa"

  name                = "${var.cluster_name}-ebs-csi"
  oidc_provider_arn   = aws_iam_openid_connect_provider.this.arn
  oidc_provider_url   = local.oidc_provider_url
  namespace           = "kube-system"
  service_account     = "ebs-csi-controller-sa"
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"]
  tags                = var.tags
}

data "aws_eks_addon_version" "this" {
  for_each = toset([
    "vpc-cni",
    "coredns",
    "kube-proxy",
    "eks-pod-identity-agent",
    "aws-ebs-csi-driver",
    "metrics-server",
    "amazon-cloudwatch-observability",
  ])

  addon_name         = each.value
  kubernetes_version = aws_eks_cluster.this.version
  most_recent        = true
}

# Installed before nodes so pods get the network policy agent from the start.
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "vpc-cni"
  addon_version               = data.aws_eks_addon_version.this["vpc-cni"].version
  service_account_role_arn    = module.vpc_cni_irsa.role_arn
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = var.tags

  configuration_values = jsonencode({
    enableNetworkPolicy = "true"
  })
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "kube-proxy"
  addon_version               = data.aws_eks_addon_version.this["kube-proxy"].version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = var.tags
}

resource "aws_eks_addon" "pod_identity" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "eks-pod-identity-agent"
  addon_version               = data.aws_eks_addon_version.this["eks-pod-identity-agent"].version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = var.tags
}

# The rest need nodes to schedule on.
resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "coredns"
  addon_version               = data.aws_eks_addon_version.this["coredns"].version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = var.tags

  depends_on = [aws_eks_node_group.this]
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "aws-ebs-csi-driver"
  addon_version               = data.aws_eks_addon_version.this["aws-ebs-csi-driver"].version
  service_account_role_arn    = module.ebs_csi_irsa.role_arn
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = var.tags

  depends_on = [aws_eks_node_group.this]
}

resource "aws_eks_addon" "metrics_server" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "metrics-server"
  addon_version               = data.aws_eks_addon_version.this["metrics-server"].version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = var.tags

  depends_on = [aws_eks_node_group.this]
}

# Container Insights metrics used by the CloudWatch alarms.
resource "aws_eks_addon" "cloudwatch_observability" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "amazon-cloudwatch-observability"
  addon_version               = data.aws_eks_addon_version.this["amazon-cloudwatch-observability"].version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = var.tags

  depends_on = [aws_eks_node_group.this]
}
