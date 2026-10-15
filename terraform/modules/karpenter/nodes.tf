data "aws_iam_policy_document" "node_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# Instance role for every node Karpenter launches; the instance profile is created by Karpenter.
resource "aws_iam_role" "node" {
  name               = "${var.cluster_name}-karpenter-node"
  assume_role_policy = data.aws_iam_policy_document.node_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "node" {
  for_each = toset([
    "arn:${local.partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:${local.partition}:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:${local.partition}:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly",
    "arn:${local.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:${local.partition}:iam::aws:policy/CloudWatchAgentServerPolicy",
  ])

  role       = aws_iam_role.node.name
  policy_arn = each.value
}

# Lets the nodes join the cluster without an aws-auth ConfigMap.
resource "aws_eks_access_entry" "node" {
  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.node.arn
  type          = "EC2_LINUX"
  tags          = var.tags
}
