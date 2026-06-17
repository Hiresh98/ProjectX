data "terraform_remote_state" "vpc" {
  backend = "local"
  config  = { path = "../vpc/terraform.tfstate" }
}

locals {
  name          = data.terraform_remote_state.vpc.outputs.name
  vpc_id        = data.terraform_remote_state.vpc.outputs.vpc_id
  public_subnet = data.terraform_remote_state.vpc.outputs.public_subnets[0]
}

# Free-tier SSH bastion in a public subnet so local tools (DBeaver, psql) can
# tunnel to the PRIVATE RDS. Keypair is generated; private key written locally.
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "tls_private_key" "bastion" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "bastion" {
  key_name   = "${local.name}-bastion"
  public_key = tls_private_key.bastion.public_key_openssh
}

resource "local_sensitive_file" "bastion_key" {
  content         = tls_private_key.bastion.private_key_pem
  filename        = "${path.module}/bastion-key.pem"
  file_permission = "0600"
}

resource "aws_security_group" "bastion" {
  name        = "${local.name}-bastion"
  description = "SSH access to the bastion host"
  vpc_id      = local.vpc_id

  ingress {
    description = "SSH from allowed CIDR"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.bastion_allowed_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name}-bastion" }
}

resource "aws_instance" "bastion" {
  ami                         = data.aws_ssm_parameter.al2023.value
  instance_type               = var.bastion_instance_type
  subnet_id                   = local.public_subnet
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  key_name                    = aws_key_pair.bastion.key_name
  associate_public_ip_address = true

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
  }

  tags = { Name = "${local.name}-bastion" }
}
