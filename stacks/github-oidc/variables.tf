variable "project" {
  type    = string
  default = "projectx"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "region" {
  type    = string
  default = "ap-south-1"
}

variable "github_repo" {
  description = "GitHub repo in 'owner/name' form for OIDC trust."
  type        = string
  default     = "Hiresh98/ProjectX"
}
