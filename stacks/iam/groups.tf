########################################
# Groups (one per tier)
########################################
resource "aws_iam_group" "tier" {
  for_each = toset(local.tiers)
  name     = "${var.project}-${each.key}"
}

# Every group gets the MFA self-service baseline.
resource "aws_iam_group_policy_attachment" "mfa_baseline" {
  for_each   = toset(local.tiers)
  group      = aws_iam_group.tier[each.key].name
  policy_arn = aws_iam_policy.mfa_baseline.arn
}

# Each group may assume ONLY its matching tier role.
resource "aws_iam_group_policy" "assume_role" {
  for_each = toset(local.tiers)
  name     = "${var.project}-${each.key}-assume-role"
  group    = aws_iam_group.tier[each.key].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "AssumeTierRole"
      Effect   = "Allow"
      Action   = "sts:AssumeRole"
      Resource = local.role_arns[each.key]
    }]
  })
}
