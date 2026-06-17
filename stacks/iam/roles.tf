########################################
# Assumable roles per tier
########################################
# Trust: any IAM principal in THIS account that has sts:AssumeRole permission
# (granted via the matching group) and has authenticated with MFA.

data "aws_iam_policy_document" "assume_trust" {
  for_each = toset(local.tiers)

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:${local.partition}:iam::${local.account_id}:root"]
    }

    dynamic "condition" {
      for_each = var.require_mfa ? [1] : []
      content {
        test     = "Bool"
        variable = "aws:MultiFactorAuthPresent"
        values   = ["true"]
      }
    }
  }
}

resource "aws_iam_role" "tier" {
  for_each = toset(local.tiers)

  name                 = "${var.project}-${each.key}"
  description          = "ProjectX ${upper(each.key)} tier role"
  assume_role_policy   = data.aws_iam_policy_document.assume_trust[each.key].json
  max_session_duration = var.max_session_seconds[each.key]
}

# dev role -> developer permissions
resource "aws_iam_role_policy_attachment" "dev" {
  role       = aws_iam_role.tier["dev"].name
  policy_arn = aws_iam_policy.dev_permissions.arn
}

# qa role -> qa (read-only) permissions
resource "aws_iam_role_policy_attachment" "qa" {
  role       = aws_iam_role.tier["qa"].name
  policy_arn = aws_iam_policy.qa_permissions.arn
}

# prod role -> operator power (everything except IAM/Organizations) + IAM read
resource "aws_iam_role_policy_attachment" "prod_poweruser" {
  role       = aws_iam_role.tier["prod"].name
  policy_arn = "arn:${local.partition}:iam::aws:policy/PowerUserAccess"
}

resource "aws_iam_role_policy_attachment" "prod_iam_read" {
  role       = aws_iam_role.tier["prod"].name
  policy_arn = "arn:${local.partition}:iam::aws:policy/IAMReadOnlyAccess"
}
