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

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "db_allocated_storage" {
  type    = number
  default = 20
}

variable "db_multi_az" {
  type    = bool
  default = false
}

variable "db_name" {
  type    = string
  default = "projectx"
}

variable "db_username" {
  type    = string
  default = "projectx"
}
