project     = "projectx"
environment = "dev"
region      = "ap-south-1"

# Networking
vpc_cidr = "10.20.0.0/16"
az_count = 2

# EKS
cluster_version    = "1.30"
node_instance_type = "c7i-flex.large"
node_min_size      = 1
node_desired_size  = 2
node_max_size      = 3
node_capacity_type = "ON_DEMAND"

# Tighten this to "YOUR_IP/32" for a more secure API endpoint.
cluster_public_access_cidrs = ["0.0.0.0/0"]

# RDS
db_instance_class    = "db.t3.micro"
db_allocated_storage = 20
db_multi_az          = false
db_name              = "projectx"
db_username          = "projectx"

# GitHub Actions OIDC (set true and your repo to enable CI/CD)
enable_github_oidc = false
github_repo        = "your-org/ProjectX"
