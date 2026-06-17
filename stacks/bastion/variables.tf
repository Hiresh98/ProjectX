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

variable "bastion_allowed_cidr" {
  description = "CIDR allowed to SSH (port 22). Set to 'YOUR_IP/32'."
  type        = string
  default     = "0.0.0.0/0"
}

variable "bastion_instance_type" {
  type    = string
  default = "t3.micro"
}
