provider "aws" {
  region = "us-east-1"
}

# Create VPC
module "vpc" {
  source     = "./modules/vpc"
  aws_region = var.aws_region
}

module "alb" {
  source         = "./modules/alb"
  vpc_id         = module.vpc.vpc_id
  public_subnets = module.vpc.public_subnets
}


module "asg" {
  source          = "./modules/asg"
  vpc_id          = module.vpc.vpc_id
  aws_region      = var.aws_region
  app_tg_arn      = module.alb.app_tg_arn
  alb_dns_name    = module.alb.alb_dns_name
  public_subnets  = module.vpc.public_subnets
  private_subnets = module.vpc.private_subnets
  env             = var.env
  ssh_public_key  = var.ssh_public_key # provided in the environment variable TF_VAR_ssh_public_key
  path_user_data  = var.path_user_data
}

data "aws_subnets" "available_subnets" {

}

module "ecr" {
  source = "./modules/ecr"
}


resource "aws_ssm_parameter" "infrastructure_version" {
  name  = "/app/${var.env}/infrastructure_version"
  type  = "String" # For standard parameters
  value = var.infrastructure_version

  tags = {
    Env       = "${var.env}"
    Terraform = "yes"
  }
}

resource "aws_ssm_parameter" "app_version" {
  name  = "/app/${var.env}/app_version"
  type  = "String" # For standard parameters
  value = var.app_version

  lifecycle {
    ignore_changes = [name] # it prevents the value from being updated after the first run of Terraform.
  }


  tags = {
    Env       = "${var.env}"
    Terraform = "yes"
  }
}