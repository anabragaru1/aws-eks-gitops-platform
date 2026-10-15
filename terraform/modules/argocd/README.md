# argocd

Installs Argo CD with the upstream chart and then a tiny local chart with the two
AppProjects and the root app-of-apps Application. Terraform outputs (VPC ID, role ARNs,
certificate ARN, database endpoint, ...) are passed to the root chart as Helm values so
nothing has to be hard-coded in Git.
