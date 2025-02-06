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

# output desired_asg {
#   value       = module.asg.desired_asg
#   sensitive = false
# }

# output min_asg {
#   value       = module.asg.min_asg
#   sensitive = false
# }

# output max_asg {
#   value       = module.asg.max_asg
#   sensitive = false
# }

output "desired_asg" {
  value     = module.asg.desired_asg
  sensitive = true
}


