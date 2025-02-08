variable "aws_region" {
  description = "The AWS region to create resources in"
  default     = "us-east-1"
}

variable "vpc_id" {
  type    = string
  default = "vpc-53cd6b2e"

}

variable "public_subnets" {
  default = ""
}

variable "env" {
  type    = string
  default = "dev"
}

