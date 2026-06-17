data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition

  ecr_repos_arn = "arn:${local.partition}:ecr:${var.region}:${local.account_id}:repository/${var.project}/*"
  s3_project    = "arn:${local.partition}:s3:::${var.project}-*"

  tiers = ["dev", "qa", "prod"]

  role_arns = {
    for t in local.tiers : t => "arn:${local.partition}:iam::${local.account_id}:role/${var.project}-${t}"
  }
}
