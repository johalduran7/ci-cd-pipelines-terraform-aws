# AWS Region
variable "aws_region" {
  description = "The AWS region to create resources in"
  default     = "us-east-1"
}

variable "env" {
  type    = string
  default = "Dev"
}
