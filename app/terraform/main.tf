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
}

data "aws_subnets" "available_subnets" {

}

module "ecr" {
  source = "./modules/ecr"
}


