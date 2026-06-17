output "groups" {
  description = "Created IAM group names."
  value       = { for t, g in aws_iam_group.tier : t => g.name }
}

output "role_arns" {
  description = "Tier role ARNs (members assume these with MFA)."
  value       = { for t, r in aws_iam_role.tier : t => r.arn }
}

output "managed_policy_arns" {
  description = "Custom permission/baseline policy ARNs."
  value = {
    dev_permissions = aws_iam_policy.dev_permissions.arn
    qa_permissions  = aws_iam_policy.qa_permissions.arn
    mfa_baseline    = aws_iam_policy.mfa_baseline.arn
  }
}

output "created_users" {
  description = "Users created by this module (if create_users=true)."
  value       = [for u in aws_iam_user.this : u.name]
}

output "switch_role_urls" {
  description = "AWS console 'Switch Role' URLs for each tier."
  value = {
    for t, r in aws_iam_role.tier :
    t => "https://signin.aws.amazon.com/switchrole?account=${local.account_id}&roleName=${r.name}&displayName=${var.project}-${t}"
  }
}
