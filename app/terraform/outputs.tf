# module asg {
#   source= "./modules/asg"
#   vpc_id=module.vpc.vpc_id #optional
#   aws_region = var.aws_region
#   app_tg_arn = module.alb.app_tg_arn
#   alb_dns_name = module.alb.alb_dns_name
# }


# output app_tg_arn {
#   value       = module.alb.app_tg_arn
# }


output "public_subnet_a_id" {
  value = module.vpc.public_subnet_a_id
}

output "subnets" {
  value = data.aws_subnets.available_subnets
}

output "public_subnets" {
  value = module.vpc.public_subnets
}

