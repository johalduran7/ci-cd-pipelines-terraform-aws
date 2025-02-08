provider "aws" {
  region = var.aws_region
}

# Create VPC
module "vpc" {
  env                   = var.env
  vpc_name              = var.vpc_name
  source                = "./modules/vpc"
  aws_region            = var.aws_region
  cidr_block            = var.cidr_block
  public_subnet_a_cidr  = var.public_subnet_a_cidr
  public_subnet_a_name  = var.public_subnet_a_name
  public_subnet_b_cidr  = var.public_subnet_b_cidr
  public_subnet_b_name  = var.public_subnet_b_name
  private_subnet_a_cidr = var.private_subnet_a_cidr
  private_subnet_a_name = var.private_subnet_a_name
  private_subnet_b_cidr = var.private_subnet_b_cidr
  private_subnet_b_name = var.private_subnet_b_name

}

module "alb" {
  source         = "./modules/alb"
  env            = var.env
  vpc_id         = module.vpc.vpc_id
  public_subnets = module.vpc.public_subnets
}


module "asg" {
  source          = "./modules/asg"
  vpc_id          = module.vpc.vpc_id
  aws_region      = var.aws_region
  app_tg_arn      = module.alb.app_tg_arn
  apache_tg_arn   = module.alb.apache_tg_arn
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
  env    = var.env
}

