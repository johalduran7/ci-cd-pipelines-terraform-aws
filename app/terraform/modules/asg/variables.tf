variable "vpc_id" {
  type    = string
  default = "vpc-53cd6b2e"

}

variable "aws_region" {
  description = "The AWS region to create resources in"
  default     = "us-east-1"
}

variable app_tg_arn {
  default       = ""
}

variable "alb_dns_name" {
  default       = ""

}

variable public_subnets {
  default        = ""
}

variable private_subnets {
  default        = ""
}

variable asg_name {
  type        = string
  default     = "app"
}
