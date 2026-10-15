# eks

EKS cluster with KMS secret encryption, control plane logging, managed node groups for
the platform add-ons in private subnets (application nodes come from Karpenter), IAM access entries (no aws-auth ConfigMap), an IRSA OIDC provider and
the core addons (VPC CNI with network policy, CoreDNS, kube-proxy, EBS CSI,
metrics-server, CloudWatch Observability).
