########################################
# Optional SSH bastion for local DB access (DBeaver, psql, etc.)
#
# The RDS instance is private (no public IP, SG allows 5432 only from inside the
# VPC). This tiny t3.micro host in a public subnet lets you open an SSH tunnel
# from your laptop straight to the database. It is gated by `enable_bastion` and
# is independent of the compute layer, so you can run it on top of the free
# layer (VPC/RDS) without paying for EKS/NAT.
#
# A keypair is generated automatically and the private key is written to
# bastion-key.pem (gitignored) for use as the DBeaver SSH tunnel identity.
########################################

# Amazon Linux 2023 AMI (kept current via SSM public parameter).
data "aws_ssm_parameter" "al2023" {
  count = var.enable_bastion ? 1 : 0
  name  = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "tls_private_key" "bastion" {
  count     = var.enable_bastion ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "bastion" {
  count      = var.enable_bastion ? 1 : 0
  key_name   = "${local.name}-bastion"
  public_key = tls_private_key.bastion[0].public_key_openssh
  tags       = local.tags
}

# Private key saved locally so DBeaver can use it as the SSH identity file.
resource "local_sensitive_file" "bastion_key" {
  count           = var.enable_bastion ? 1 : 0
  content         = tls_private_key.bastion[0].private_key_pem
  filename        = "${path.module}/bastion-key.pem"
  file_permission = "0600"
}

resource "aws_security_group" "bastion" {
  count       = var.enable_bastion ? 1 : 0
  name        = "${local.name}-bastion"
  description = "SSH access to the bastion host"
  vpc_id      = module.vpc.vpc_id

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

  tags = local.tags
}

resource "aws_instance" "bastion" {
  count = var.enable_bastion ? 1 : 0

  ami                         = data.aws_ssm_parameter.al2023[0].value
  instance_type               = var.bastion_instance_type
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.bastion[0].id]
  key_name                    = aws_key_pair.bastion[0].key_name
  associate_public_ip_address = true

  # Free-tier root volume; well under the 30 GB EBS free-tier allowance.
  root_block_device {
    volume_size = 8
    volume_type = "gp3"
  }

  tags = merge(local.tags, { Name = "${local.name}-bastion" })
}
