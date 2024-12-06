# create ec2s per subnet and assign roles to them for testing purposes, not required to test the VPC itself

# module "ec2_simple" {
#   source     = "../ec2_simple"
#   ec2_type   = "ubuntu"                                                        # optional. default ubuntu
#   subnet_ids = [aws_subnet.public_subnet_a.id, aws_subnet.private_subnet_a.id] #optional. default subnet on AZ a of the region
#   #subnet_ids = [ "subnet-48672b46", "subnet-7636a757" ]
#   vpc_id                = aws_vpc.demo_vpc.id                           # optional. default vpc
#   install_apache        = true                                          # optional. default false. When true, it also installs a security gruop on port 80
#   instance_profile_name = module.ec2_role.aws_iam_instance_profile_name # optional 
# }


# module "ec2_role" {
#   source = "../roles"

# }

# output "private_key" {
#   value = module.ec2_simple.private_key

# }


# output "test_key" {
#   value       = module.ec2_simple.test_key
#   description = "description"
# }


# output "aws_iam_instance_profile_name" {
#   value = module.ec2_role.aws_iam_instance_profile_name

# }
