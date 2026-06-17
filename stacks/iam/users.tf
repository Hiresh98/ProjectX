########################################
# Optional: create users and add to groups
########################################
locals {
  # username -> tier, only when create_users is enabled
  user_tier = var.create_users ? merge(
    { for u in var.dev_users : u => "dev" },
    { for u in var.qa_users : u => "qa" },
    { for u in var.prod_users : u => "prod" },
  ) : {}
}

resource "aws_iam_user" "this" {
  for_each      = local.user_tier
  name          = each.key
  force_destroy = true

  tags = {
    Tier = each.value
  }
}

resource "aws_iam_user_group_membership" "this" {
  for_each = local.user_tier
  user     = aws_iam_user.this[each.key].name
  groups   = [aws_iam_group.tier[each.value].name]
}
