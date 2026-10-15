data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
  region     = data.aws_region.current.region
}

# Karpenter finds the cluster security group through this tag.
resource "aws_ec2_tag" "cluster_security_group" {
  resource_id = var.cluster_security_group_id
  key         = "karpenter.sh/discovery"
  value       = var.cluster_name
}
