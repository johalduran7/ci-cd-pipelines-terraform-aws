# AWS Region
variable "aws_region" {
  description = "The AWS region to create resources in"
  default     = "us-east-1"
}

variable "env" {
  type    = string
  default = "Dev"
}

variable "ssh_public_key" {
  description = "Public SSH key for EC2 instances"
  type        = string
}
