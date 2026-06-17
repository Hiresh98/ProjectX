data "terraform_remote_state" "vpc" {
  backend = "local"
  config  = { path = "../vpc/terraform.tfstate" }
}

data "terraform_remote_state" "rds_sg" {
  backend = "local"
  config  = { path = "../rds-sg/terraform.tfstate" }
}

locals {
  name            = data.terraform_remote_state.vpc.outputs.name
  private_subnets = data.terraform_remote_state.vpc.outputs.private_subnets
  sg_id           = data.terraform_remote_state.rds_sg.outputs.security_group_id
}

resource "random_password" "db" {
  length  = 20
  special = false
}

# RDS PostgreSQL 16. db.t3.micro + 20 GB is free-tier eligible (12 months).
module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.7"

  identifier = "${local.name}-pg"

  engine               = "postgres"
  engine_version       = "16"
  family               = "postgres16"
  major_engine_version = "16"
  instance_class       = var.db_instance_class

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_allocated_storage * 2
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result
  port     = 5432

  manage_master_user_password = false

  multi_az               = var.db_multi_az
  vpc_security_group_ids = [local.sg_id]

  create_db_subnet_group = true
  subnet_ids             = local.private_subnets

  maintenance_window      = "Mon:00:00-Mon:03:00"
  backup_window           = "03:00-06:00"
  backup_retention_period = 1

  deletion_protection          = false
  skip_final_snapshot          = true
  performance_insights_enabled = false
}
