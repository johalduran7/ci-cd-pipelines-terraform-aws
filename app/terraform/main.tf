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
  ssh_public_key  = var.ssh_public_key
}

data "aws_subnets" "available_subnets" {
}


#since I had to add the ssh-key as an environment variable. to run this, you have to run: 
#terraform apply  -auto-approve -var 'ssh_public_key=$TF_VAR_ssh_public_key'