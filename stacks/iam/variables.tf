variable "project" {
  description = "Project name prefix for groups/roles/policies."
  type        = string
  default     = "projectx"
}

variable "region" {
  description = "Primary AWS region. Permissions are constrained to this region."
  type        = string
  default     = "ap-south-1"
}

variable "require_mfa" {
  description = "Require MFA to assume the dev/qa/prod roles and to perform privileged actions."
  type        = bool
  default     = true
}

variable "max_session_seconds" {
  description = "Max assumed-role session duration per tier."
  type        = map(number)
  default = {
    dev  = 14400 # 4h
    qa   = 14400 # 4h
    prod = 3600  # 1h (tighter for production)
  }
}

# Set create_users = true and fill the lists to provision IAM users and add
# them to the matching group. Leave empty to just create the groups/roles and
# add existing users to groups yourself in the console.
variable "create_users" {
  description = "Whether to create the IAM users listed below."
  type        = bool
  default     = false
}

variable "dev_users" {
  description = "Usernames to create and place in the dev group."
  type        = list(string)
  default     = []
}

variable "qa_users" {
  description = "Usernames to create and place in the qa group."
  type        = list(string)
  default     = []
}

variable "prod_users" {
  description = "Usernames to create and place in the prod group."
  type        = list(string)
  default     = []
}
