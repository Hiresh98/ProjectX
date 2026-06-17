output "region" {
  value = var.region
}

output "cluster_name" {
  value = try(module.eks.cluster_name, "")
}

output "cluster_endpoint" {
  value = try(module.eks.cluster_endpoint, "")
}

output "compute_enabled" {
  description = "Whether the costly EKS/NAT/IRSA layer is currently provisioned."
  value       = var.enable_compute
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "lb_controller_role_arn" {
  value = try(one(module.lb_controller_irsa[*].iam_role_arn), "")
}

output "cluster_autoscaler_role_arn" {
  value = try(one(module.cluster_autoscaler_irsa[*].iam_role_arn), "")
}

output "db_host" {
  value = module.rds.db_instance_address
}

output "db_port" {
  value = 5432
}

output "db_name" {
  value = var.db_name
}

output "db_username" {
  value = var.db_username
}

output "db_password" {
  value     = random_password.db.result
  sensitive = true
}

output "bastion_public_ip" {
  description = "Public IP of the SSH bastion (use as the SSH tunnel host in DBeaver)."
  value       = try(aws_instance.bastion[0].public_ip, "")
}

output "bastion_ssh_user" {
  description = "SSH user for the bastion (Amazon Linux)."
  value       = "ec2-user"
}

output "bastion_key_path" {
  description = "Local private-key file to use as the DBeaver SSH identity."
  value       = try(local_sensitive_file.bastion_key[0].filename, "")
}

output "github_ci_role_arn" {
  value       = var.enable_github_oidc ? module.github_oidc[0].ci_role_arn : null
  description = "Role ARN to set as AWS_ROLE_ARN secret in GitHub."
}
