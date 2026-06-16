terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
  }
}

variable "name" { type = string }
variable "github_repo" { type = string } # owner/name
variable "ecr_arn" { type = string }
variable "region" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}

data "aws_caller_identity" "current" {}

# Creates the GitHub Actions OIDC provider. If your account already has one,
# import it first:  terraform import 'module.github_oidc[0].aws_iam_openid_connect_provider.github' <arn>
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
  tags            = var.tags
}

locals {
  oidc_arn = aws_iam_openid_connect_provider.github.arn
}

resource "aws_iam_role" "ci" {
  name = "${var.name}-github-ci"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = local.oidc_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:*"
        }
      }
    }]
  })

  tags = var.tags
}

# Push images to ECR + read auth token.
resource "aws_iam_role_policy" "ecr" {
  name = "ecr-push"
  role = aws_iam_role.ci.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer"
        ]
        Resource = var.ecr_arn
      }
    ]
  })
}

# Allow the CI role to run helm/kubectl against EKS (cluster RBAC handled separately).
resource "aws_iam_role_policy" "eks_describe" {
  name = "eks-describe"
  role = aws_iam_role.ci.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["eks:DescribeCluster", "eks:ListClusters"]
      Resource = "*"
    }]
  })
}

output "ci_role_arn" {
  value = aws_iam_role.ci.arn
}
