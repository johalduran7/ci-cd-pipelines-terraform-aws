# AWS Region
variable "aws_region" {
  description = "The AWS region to create resources in"
  default     = "us-east-1"
}

variable "env" {
  type    = string
  default = "dev"
}

# Remember to export the TF_VAR_ssh_public_key variable in your environement
variable "ssh_public_key" {
  description = "Public SSH key for EC2 instances"
  type        = string
}

variable "infrastructure_version" {
  type    = string
  default = "dev-infra-v1.0.0"
}

variable "app_version" {
  type    = string
  default = "dev-app-v1.0.0"
}

variable "path_user_data" {
  default = "./modules/asg/user_data.sh"
}