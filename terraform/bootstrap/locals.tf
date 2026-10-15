data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  account_id   = data.aws_caller_identity.current.account_id
  state_bucket = "${var.project}-tfstate-${local.account_id}-${var.region}"
  oidc_host    = "token.actions.githubusercontent.com"

  # OIDC subject claims allowed to assume each role.
  plan_subjects = ["repo:${var.github_repository}:pull_request"]
  apply_subjects = concat(
    ["repo:${var.github_repository}:ref:refs/heads/main"],
    [for env in var.environments : "repo:${var.github_repository}:environment:${env}"],
  )
}
