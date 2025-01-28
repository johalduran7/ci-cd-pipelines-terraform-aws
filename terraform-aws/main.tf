# Specify the provider (AWS in this case)
variable "region" {
  type    = string
  default = "us-east-1"

}

provider "aws" {
  region = var.region # Replace with your preferred region
}

# module "policy_groups" {
#   source = "./modules/policy_groups"
#   #param  = value
# }

###############################################
# module "roles" {
#   source = "./modules/roles"
#   #param  = value
# }

variable "aws_iam_instance_profile" {
  type = string
  #default = "example-instance-profile"
  default = ""

}



# # Output the Role ARN
# output "role_arn" {
#   value = module.roles.role_arn
# }

# # Output the Role ARN
# output "aws_iam_instance_profile_name" {
#   value = module.roles.aws_iam_instance_profile_name
# }

###################################################
# very simple and quick EC2: ENI, EBS

# ssh -i ./modules/ec2/key_saa ubuntu@ec2-54-144-13-128.compute-1.amazonaws.com
# module "ec2" {
#   source   = "./modules/ec2_simple"
#   ec2_type = "amazon"
#   #ec2_type="ubuntu"

# }


###################################################


###################################################
#ec2_ ssh_key, ENI, SG, Profile, Apache, create AMI, create ec2 based on AMI. EFS, 

# ssh -i ./modules/ec2/key_saa ubuntu@ec2-54-144-13-128.compute-1.amazonaws.com
# module "ec2" {
#   source               = "./modules/ec2"
#   iam_instance_profile = var.aws_iam_instance_profile != null ? var.aws_iam_instance_profile : null
#   ec2_type             = "ubuntu"
#   #ec2_type="amazon"

# }

# output efs_name {
#   value       = module.ec2.efs_name
#   depends_on  = [module.ec2]
# }



###################################################


# module "budget" {
#   source = "./modules/budget"

# }

# output budget {
#   value       = module.budget.overall_costs
#   description = "Budget details"

# }

# output budget_name {
#   value       = module.budget.budget_name
#   description = "description"
# }

###################################################
## ELB: ALB, NLB, TG, LISTENERS, RULES, ATTACHMENT 

# module "elb" {
#   source = "./modules/elb"
# }





###################################################
# ASG: ASG

# module "asg" {
#   source = "./modules/asg"
#   #vpc_id = module.vpc.vpc_id # optional

# }

# module "cw_asg" {
#   source                     = "./modules/cw/cw_asg"
#   aws_autoscaling_group_name = "asg_ssa"
# }





###############################################
# RDS

# module "rds" {
#   source = "./modules/rds"
# }

# output "db_endpoint" {
#   value = module.rds.db_endpoint
# }

# output "db_security_group" {
#   value = module.rds.db_security_group
# }

###############################################
# Aurora 

# module "aurora" {
#   source = "./modules/aurora"
# }

# # Outputs for convenience
# output "db_cluster_endpoint" {
#   value = module.aurora.db_cluster_endpoint
# }

# output "db_reader_endpoint" {
#   value = module.aurora.db_reader_endpoint
# }

# output "db_cluster_security_group" {
#   value = module.aurora.db_cluster_security_group
# }


# ###############################################
# # Beanstalk -- DIDN'T WORK BUT IT'S NOT THAT IMPORTANT FOR SAA
## when running this, be careful to remove the S3 bucket because Beanstalk denies it in the Permissions of the bucket, you have to change it from Deny to Allow and also change the principal to *

# module "beanstalk" {
#   source = "./modules/beanstalk"
# }

# output "bucket_name" {
#   value = module.beanstalk.bucket_name
# }


# ###############################################

# # SQS Queue with S3, SQS FIFO

# module "sqs_queue" {
#   source = "./modules/sqs_queue"
# }

# output "command_polling" {
#   value       = module.sqs_queue.command_polling
#   description = "to poll messages from ec2"

# }


# ###############################################

# CloudFront with S3

# module "cloudfront" {
#   source = "./modules/cloudfront"
# }



# ###############################################
# # ECS (fargate and ec2 tasks)

# module "ecs" {
#   source = "./modules/ecs"
# }


# ################################################
# # CloudWatch: metrics, alarms, asg metrics, ec2 metrics, Unified Agent, Logs Daemon

# module "cw" {
#   source = "./modules/cw"
#   region = var.region
# }

# output "public_ip_ec2_apache" {
#   value = module.cw.public_ip_ec2_apache
# }

# output "alb_dns_name" {
#   value       = module.cw.alb_dns_name
#   description = "The DNS name of the ALB"
# }


# ################################################
# #  KMS . Be Careful with this one, month 1usd, it prorrate it per hour but minimum is 7 days. Check if I have available KMS keys before you run it

# module "kms" {
#   source = "./modules/kms"
# }



# ################################################
# #  SSM (Session Manager): Parameter Store - usin KMS for one of the paramters

# module "ssm" {
#   source = "./modules/ssm"
# }

# using CLI to access:
# aws ssm get-parameters --names /my-app/dev/db-url /my-app/dev/db-password --outpu=json
# aws ssm get-parameters --names /my-app/dev/db-url /my-app/dev/db-password --outpu=json --with-decryption
# aws ssm get-parameters-by-path --path /my-app/ --recursive --output=json

# #  Lambda using SSM parameter store above

# module "lambda" {
#   source = "./modules/lambda"
# }

# using CLI to access:
# aws ssm get-parameters --names /my-app/dev/db-url /my-app/dev/db-password --outpu=json
# aws ssm get-parameters --names /my-app/dev/db-url /my-app/dev/db-password --outpu=json --with-decryption
# aws ssm get-parameters-by-path --path /my-app/ --recursive --output=json



# ################################################
# # VPC - Networking: VPC, igw,route_table,subnets,nat_ec2, nat_gateway

# module "vpc" {
#   source     = "./modules/vpc"
#   aws_region = var.region
# }

# # output test_key {
# #   value       = module.vpc.test_key
# # }

# # module "ec2_simple" {
# #   source   = "./modules/ec2_simple"
# #   ec2_type = "ubuntu"
# #   subnet_ids = [ "subnet-48672b46", "subnet-7636a757" ] # if not passed, it'll use a random subnet in AZ a
# #   #vpc_id    = aws_vpc.demo_vpc.id # ifnot defined, it'll  be created in the deafault vpc
# # }

# output "vpc_id" {
#   value = module.vpc.vpc_id
# }
# output "public_subnet_a_id" {
#   value = module.vpc.public_subnet_a_id
# }

# output "private_route_table_id" {
#   value = module.vpc.private_route_table
# }
# # output private_key {
# #   value       = module.vpc.private_key

# # }

# # module "nat_ec2" {
# #   source     = "./modules/nat_ec2"
# #   subnet_id =  "${module.vpc.public_subnet_a_name}"
# #   vpc_id=  "${module.vpc.vpc_id}"
# # }

# module "nat_gw" {
#   source="./modules/nat_gw"
#   subnet_id= module.vpc.public_subnet_a_id
#   private_route_table=module.vpc.private_route_table
# }

# ################################################
## SNS 
# module "simple_s3" {
#   source = "./modules/simple_s3"
# }

# output "bucket_id" {
#   value = module.simple_s3.bucket_id

# }

# output "bucket_arn" {
#   value = module.simple_s3.bucket_arn

# }


# module "sns" {
#   source     = "./modules/sns"
#   bucket_id  = module.simple_s3.bucket_id
#   bucket_arn = module.simple_s3.bucket_arn
# }

# ################################################
## CloudFormation

# module "cloudformation" {
#   source = "./modules/cloudformation"

# }

# ################################################
## KinesiS - Kinesis Data Stream - Kinesis Data Firehose.

# module "kinesis" {
#   source = "./modules/kinesis"

# }

# # Output for putting a record
# output "put_record_command" {
#   value = module.kinesis.put_record_command
# }

# # Output for describing the stream
# output "describe_stream_command" {
#   value = module.kinesis.describe_stream_command
# }

# # Output for consuming data
# output "get_shard_iterator_command" {
#   value = module.kinesis.get_shard_iterator_command
# }

# output "get_records_command" {
#   value = module.kinesis.get_records_command
# }


# ################################################
# random tests
# module "ec2_simple" {
#   source   = "./modules/ec2_simple"
#   ec2_type = "ubuntu" # optional. default ubuntu
#   #subnet_ids = [aws_subnet.public_subnet_a.id, aws_subnet.private_subnet_a.id]  #optional. default subnet on AZ a of the region
#   #subnet_ids = [ "subnet-48672b46", "subnet-7636a757" ]
#   #vpc_id         = aws_vpc.demo_vpc.id # optional. default vpc
#   #install_apache = true  # optional. default false. When true, it also installs a security gruop on port 80
#   instance_profile_name=module.roles.aws_iam_instance_profile_name # optional 
# }

# module "s3" {
#   source = "./modules/s3"
# }

# ################################################
# Lab mixing several services and concepts
# CloudFront distribution with behaviors for Cache Key and Origin Request Policies to 
#   forward traffic to a static WebSite on S3 when:
#   Forwards traffic to S3 TTL 1 day when https://d2n1hu9c2rlbgi.cloudfront.net/index.html
#   Forwards traffic to S3 TTL 60s when https://d2n1hu9c2rlbgi.cloudfront.net/page*.html
#   Forwards trafic to apache EC2 ASG when https://d2n1hu9c2rlbgi.cloudfront.net or any other path, however, index is only on /



# CREATING ASG AND ALB. IT RUNS AN APACHE SERVER ON PORT 80
# module "asg" {
#   source = "./modules/asg"
#   #vpc_id="" #optional if not defined, it takes the default
# }

# #This module creates a CloudFront distribution with S3 as origin.
# module "cloudfront" {
#   source       = "./modules/cloudfront"
#   alb_dns_name = module.asg.alb_dns_name # OPTIONAL
#   alb_id       = module.asg.alb_id       # OPTIONAL but has to be set up if alb dns is set up
# }




# ################################################
# LAMBDA SECTION

# Dollar Rate personal automation, DO NOT disable
module "lambda_sns_dollar" {
  source = "./modules/lambda/lambda_sns_dollar"
}

# module "lambda_alb" {
#   source = "./modules/lambda/lambda_alb"
# }

# module "lambda_dlq" {
#   source = "./modules/lambda/lambda_dlq"
# }

# module "lambda_eventbridge" {
#   source = "./modules/lambda/lambda_eventbridge"
# }

# output eventbridge_rules {
#   value       = module.lambda_eventbridge.eventbridge_rules
# }


# module "lambda_s3" {
#   source = "./modules/lambda/lambda_s3"
# }

# be careful with leaving this one running for a long time because lambda can keep polling from sqs increasing cost
# module "lambda_sqs_mapper" {
#   source = "./modules/lambda/lambda_sqs_mapper"
# }

# lambda_vpc module may take up to 6 minutes to destroy.
# module "lambda_vpc" {
#   source = "./modules/lambda/lambda_vpc"
# }
# output private_route_table_ids {
#   value       = module.lambda_vpc.private_route_table_ids
# }


# module "lambda_layer" {
#   source = "./modules/lambda/lambda_layer"
# }