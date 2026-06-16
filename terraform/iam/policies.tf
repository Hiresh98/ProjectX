########################################
# Permission policies attached to ROLES
########################################

# --- Developer permissions: build/push images, deploy to & observe dev ---
resource "aws_iam_policy" "dev_permissions" {
  name        = "${var.project}-dev-permissions"
  description = "Developer tier: ECR push/pull, EKS access, read logs/metrics."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "EcrAuth"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "EcrPushPull"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages"
        ]
        Resource = local.ecr_repos_arn
      },
      {
        Sid      = "EksAccess"
        Effect   = "Allow"
        Action   = ["eks:DescribeCluster", "eks:ListClusters", "eks:AccessKubernetesApi"]
        Resource = "*"
      },
      {
        Sid    = "ObservabilityRead"
        Effect = "Allow"
        Action = [
          "logs:GetLogEvents",
          "logs:FilterLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "cloudwatch:GetMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics",
          "cloudwatch:DescribeAlarms"
        ]
        Resource = "*"
      },
      {
        Sid    = "DescribeInfra"
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "elasticloadbalancing:Describe*",
          "autoscaling:Describe*",
          "rds:Describe*"
        ]
        Resource = "*"
      },
      {
        Sid      = "S3ProjectRead"
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetObject"]
        Resource = [local.s3_project, "${local.s3_project}/*"]
      }
    ]
  })
}

# --- QA permissions: read-only + pull images (no push, no mutate) ---
resource "aws_iam_policy" "qa_permissions" {
  name        = "${var.project}-qa-permissions"
  description = "QA tier: pull images, describe EKS, read logs/metrics (read-only)."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "EcrAuth"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "EcrPullOnly"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages"
        ]
        Resource = local.ecr_repos_arn
      },
      {
        Sid      = "EksDescribe"
        Effect   = "Allow"
        Action   = ["eks:DescribeCluster", "eks:ListClusters", "eks:AccessKubernetesApi"]
        Resource = "*"
      },
      {
        Sid    = "ReadOnlyObservability"
        Effect = "Allow"
        Action = [
          "logs:GetLogEvents",
          "logs:FilterLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "cloudwatch:Get*",
          "cloudwatch:List*",
          "cloudwatch:Describe*",
          "ec2:Describe*",
          "elasticloadbalancing:Describe*",
          "rds:Describe*"
        ]
        Resource = "*"
      }
    ]
  })
}

########################################
# MFA self-service baseline (attached to GROUPS)
########################################
# Lets users manage their own credentials/MFA, and (when require_mfa=true)
# denies everything else until they have authenticated with MFA.
resource "aws_iam_policy" "mfa_baseline" {
  name        = "${var.project}-mfa-baseline"
  description = "Self-service credential management + MFA enforcement."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Sid      = "AllowViewAccountInfo"
        Effect   = "Allow"
        Action   = ["iam:GetAccountPasswordPolicy", "iam:ListVirtualMFADevices", "iam:GetUser"]
        Resource = "*"
      },
      {
        Sid    = "AllowManageOwnPasswordAndKeys"
        Effect = "Allow"
        Action = [
          "iam:ChangePassword",
          "iam:GetLoginProfile",
          "iam:CreateAccessKey",
          "iam:DeleteAccessKey",
          "iam:ListAccessKeys",
          "iam:UpdateAccessKey"
        ]
        Resource = "arn:${local.partition}:iam::${local.account_id}:user/$${aws:username}"
      },
      {
        Sid    = "AllowManageOwnMFA"
        Effect = "Allow"
        Action = [
          "iam:CreateVirtualMFADevice",
          "iam:DeleteVirtualMFADevice",
          "iam:EnableMFADevice",
          "iam:ResyncMFADevice",
          "iam:ListMFADevices"
        ]
        Resource = [
          "arn:${local.partition}:iam::${local.account_id}:mfa/$${aws:username}",
          "arn:${local.partition}:iam::${local.account_id}:user/$${aws:username}"
        ]
      }
      ],
      var.require_mfa ? [{
        Sid       = "DenyAllExceptListedUnlessMFA"
        Effect    = "Deny"
        NotAction = [
          "iam:CreateVirtualMFADevice",
          "iam:EnableMFADevice",
          "iam:GetUser",
          "iam:ListMFADevices",
          "iam:ListVirtualMFADevices",
          "iam:ResyncMFADevice",
          "iam:ChangePassword",
          "iam:GetAccountPasswordPolicy",
          "sts:GetSessionToken"
        ]
        Resource = "*"
        Condition = {
          BoolIfExists = { "aws:MultiFactorAuthPresent" = "false" }
        }
      }] : []
    )
  })
}
