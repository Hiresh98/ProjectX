variable "project" {
  description = "Project name, used for naming/tagging."
  type        = string
  default     = "projectx"
}

variable "environment" {
  description = "Environment name."
  type        = string
  default     = "dev"
}

variable "region" {
  description = "AWS region."
  type        = string
  default     = "ap-south-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "az_count" {
  description = "Number of Availability Zones (EKS requires >= 2)."
  type        = number
  default     = 2
}

variable "cluster_version" {
  description = "EKS Kubernetes version."
  type        = string
  default     = "1.30"
}

variable "node_instance_type" {
  description = "EC2 instance type for the managed node group. NOTE: Free-tier-restricted accounts must use a free-tier-eligible type (e.g. c7i-flex.large, m7i-flex.large, t3.small)."
  type        = string
  default     = "c7i-flex.large"
}

variable "node_min_size" {
  description = "Minimum nodes."
  type        = number
  default     = 1
}

variable "node_desired_size" {
  description = "Desired nodes at creation."
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum nodes (Cluster Autoscaler upper bound)."
  type        = number
  default     = 3
}

variable "node_capacity_type" {
  description = "ON_DEMAND or SPOT."
  type        = string
  default     = "ON_DEMAND"
}

variable "cluster_public_access_cidrs" {
  description = "CIDRs allowed to reach the public EKS API endpoint. Restrict to your IP for better security."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "db_instance_class" {
  description = "RDS instance class (db.t3.micro is free-tier eligible)."
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "RDS storage in GiB."
  type        = number
  default     = 20
}

variable "db_multi_az" {
  description = "Enable Multi-AZ RDS (costs ~2x; off for POC)."
  type        = bool
  default     = false
}

variable "db_name" {
  description = "Initial database name."
  type        = string
  default     = "projectx"
}

variable "db_username" {
  description = "Master DB username."
  type        = string
  default     = "projectx"
}

variable "enable_compute" {
  description = <<-EOT
    Toggle for the COSTLY, non-free layer (EKS control plane, EC2 worker nodes,
    NAT Gateway + EIP, IRSA roles). Set false to tear down everything that bills
    while keeping the free/free-tier layer (VPC, subnets, IGW, security groups,
    ECR, RDS db.t3.micro, IAM) running at ~$0. down.ps1 sets this to false for a
    cost-saving teardown; up.ps1 sets it to true.
  EOT
  type        = bool
  default     = true
}

variable "enable_bastion" {
  description = <<-EOT
    Create a small SSH bastion (t3.micro, free-tier) in a PUBLIC subnet so local
    tools like DBeaver can reach the PRIVATE RDS via an SSH tunnel. Independent of
    enable_compute, so you can keep a $0 free layer + a bastion without EKS/NAT.
  EOT
  type        = bool
  default     = false
}

variable "bastion_allowed_cidr" {
  description = "CIDR allowed to SSH (port 22) to the bastion. Set to 'YOUR_IP/32'."
  type        = string
  default     = "0.0.0.0/0"
}

variable "bastion_instance_type" {
  description = "Bastion instance type (t3.micro is free-tier eligible)."
  type        = string
  default     = "t3.micro"
}

variable "enable_github_oidc" {
  description = "Create the GitHub Actions OIDC provider + CI role."
  type        = bool
  default     = false
}

variable "github_repo" {
  description = "GitHub repo in 'owner/name' form for OIDC trust (required if enable_github_oidc=true)."
  type        = string
  default     = ""
}
