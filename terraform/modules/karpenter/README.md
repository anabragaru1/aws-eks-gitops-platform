# karpenter

AWS side of Karpenter: an IRSA role for the controller with the upstream policy scoped
to one cluster, the node instance role plus its EKS access entry, the SQS interruption
queue with its EventBridge rules, and the `karpenter.sh/discovery` tag on the cluster
security group. The controller, `EC2NodeClass` and `NodePool` are installed by Argo CD.
