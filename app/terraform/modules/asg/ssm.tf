# resource "aws_ssm_parameter" "desired_asg" {
#   name  = "/app/dev/desired_asg"
#   type  = "String" # For standard parameters
#   value = var.desired_asg

#   lifecycle {
#     ignore_changes = [value] # it prevents the value from being updated after the first run of Terraform.
#   }

#   tags = {
#     Environment = "dev"
#     Terraform   = "yes"
#   }
# }

# resource "aws_ssm_parameter" "min_asg" {
#   name  = "/app/dev/min_asg"
#   type  = "String" # For standard parameters
#   value = var.min_asg

#   lifecycle {
#     ignore_changes = [value] # it prevents the value from being updated after the first run of Terraform.
#   }

#   tags = {
#     Environment = "dev"
#     Terraform   = "yes"
#   }
# }

# resource "aws_ssm_parameter" "max_asg" {
#   name  = "/app/dev/max_asg"
#   type  = "String" # For standard parameters
#   value = var.max_asg

#   lifecycle {
#     ignore_changes = [value] # it prevents the value from being updated after the first run of Terraform.
#   }

#   tags = {
#     Environment = "dev"
#     Terraform   = "yes"
#   }
# }