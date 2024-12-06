
# generating key: $ ssh-keygen -t rsa -b 4096 -f key_saa -N ""
resource "aws_key_pair" "deployer_key" {
  key_name   = "deployer-key"
  public_key = file("${path.module}/key_saa.pub")
}

# Create IAM Role for Elastic Beanstalk
resource "aws_iam_role" "eb_service_role" {
  name               = "aws-elasticbeanstalk-service-role"
  assume_role_policy = data.aws_iam_policy_document.eb_service_assume_role_policy.json
}

data "aws_iam_policy_document" "eb_service_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["elasticbeanstalk.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "eb_service_role_policy_managerupdates" {
  role       = aws_iam_role.eb_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkManagedUpdatesCustomerRolePolicy"
}

resource "aws_iam_role_policy_attachment" "eb_service_role_policy_enhancedhealth" {
  role       = aws_iam_role.eb_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSElasticBeanstalkEnhancedHealth"
}

# creating role and profile for ec2
resource "aws_iam_role" "ec2_role_eb" {
  name               = "aws-elasticbeanstalk-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.eb_ec2_assume_role_policy.json
}

data "aws_iam_policy_document" "eb_ec2_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}


resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2-instance-eb-profile"
  role = aws_iam_role.ec2_role_eb.name
}

resource "aws_iam_role_policy_attachment" "eb_ec2_role_policy_web" {
  role       = aws_iam_role.ec2_role_eb.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWebTier"
}

resource "aws_iam_role_policy_attachment" "eb_ec2_role_policy_worker" {
  role       = aws_iam_role.ec2_role_eb.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWorkerTier"
}

resource "aws_iam_role_policy_attachment" "eb_ec2_role_policy_docker" {
  role       = aws_iam_role.ec2_role_eb.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkMulticontainerDocker"
}


# Create Elastic Beanstalk Application
# resource "aws_elastic_beanstalk_application" "my_application" {
#   name        = "MyApplication"
#   description = "Sample Elastic Beanstalk application"

#   tags = {
#     Terraform  = "yes"
#     aws_dvac02 = "yes"
#   }
# }

resource "aws_launch_template" "eb_launch_template" {
  name_prefix   = "eb-launch-template-"
  instance_type = "t3.micro" # Adjust as needed
  key_name      = "deployer-key"
  image_id      = data.aws_ami.eb_ami.id

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 8
      volume_type = "gp3"
    }
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_instance_profile.name
  }
}

data "aws_ami" "eb_ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-ebs"]
  }
}


resource "aws_elastic_beanstalk_application" "my_app" {
  name = "MyApplication"
  tags = {
    Terraform  = "yes"
    aws_dvac02 = "yes"
  }
}

# CONFIG FOR THIS: https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/command-options-general.html#command-options-general-elasticbeanstalkenvironment
resource "aws_elastic_beanstalk_environment" "prod_environment" {
  name        = "MyApplication-Prod-tf"
  application = aws_elastic_beanstalk_application.my_app.name
  # find the solution_stack_name available: $ aws elasticbeanstalk list-available-solution-stacks | grep -i '64bit Amazon Linux 2 v5.9.9 running Node.js'
  solution_stack_name = "64bit Amazon Linux 2 v5.9.9 running Node.js 18" # Platform type and version
  tier                = "WebServer"                                      # Single Instance preset corresponds to WebServer tier

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "ServiceRole"
    value     = aws_iam_role.eb_service_role.arn
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = aws_iam_instance_profile.ec2_instance_profile.name
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "RootVolumeType"
    value     = "gp3"
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "EC2KeyName"
    value     = aws_key_pair.deployer_key.key_name
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "EnvironmentType"
    #value     = "SingleInstance" # Default "LoadBalanced"
    value = "LoadBalanced"
  }
  #Load balancer type, enable when the EnvironmentType=LoadBalanced. Also, if not defined/enabled, "classic" is defaul
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "LoadBalancerType"
    value     = "application" # Default "LoadBalanced"
  }

  #when loadbalanced, you can decide if the balancer is shared between environments or dedicated ("false")
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "LoadBalancerIsShared"
    value     = "true" # Default "LoadBalanced"
  }

  # settings to implement HA
  setting {
    namespace = "aws:ec2:vpc"
    name      = "VPCId"
    value     = "vpc-53cd6b2e" # Default vpc us-east-1
  }
  setting {
    namespace = "aws:ec2:vpc"
    name      = "Subnets"
    value     = "subnet-f5c09ab8,subnet-9631a6c9,subnet-39bd375f" # Default vpc us-east-1
  }

  # Deployment policies
  setting {
    namespace = "aws:elasticbeanstalk:command"
    name      = "DeploymentPolicy"
    value     = "Immutable"
  }
}


resource "aws_elastic_beanstalk_environment" "dev_environment" {
  name        = "MyApplication-Dev-tf"
  application = aws_elastic_beanstalk_application.my_app.name
  # find the solution_stack_name available: $ aws elasticbeanstalk list-available-solution-stacks | grep -i '64bit Amazon Linux 2 v5.9.9 running Node.js'
  solution_stack_name = "64bit Amazon Linux 2 v5.9.9 running Node.js 18" # Platform type and version
  tier                = "WebServer"                                      # Single Instance preset corresponds to WebServer tier

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "ServiceRole"
    value     = aws_iam_role.eb_service_role.arn
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = aws_iam_instance_profile.ec2_instance_profile.name
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "RootVolumeType"
    value     = "gp3"
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "EC2KeyName"
    value     = aws_key_pair.deployer_key.key_name
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "EnvironmentType"
    #value     = "SingleInstance" # Default "LoadBalanced"
    value = "LoadBalanced"
  }
  #Load balancer type, enable when the EnvironmentType=LoadBalanced. Also, if not defined/enabled, "classic" is defaul
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "LoadBalancerType"
    value     = "application" # Default "LoadBalanced"
  }

  #when loadbalanced, you can decide if the balancer is shared between environments or dedicated ("false")
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "LoadBalancerIsShared"
    value     = "true" # Default "LoadBalanced"
  }

  # settings to implement HA
  setting {
    namespace = "aws:ec2:vpc"
    name      = "VPCId"
    value     = "vpc-53cd6b2e" # Default vpc us-east-1
  }
  setting {
    namespace = "aws:ec2:vpc"
    name      = "Subnets"
    value     = "subnet-f5c09ab8,subnet-9631a6c9,subnet-39bd375f" # Default vpc us-east-1
  }

  # Deployment policies
  setting {
    namespace = "aws:elasticbeanstalk:command"
    name      = "DeploymentPolicy"
    value     = "Immutable"
  }
}



# # Upload Sample Application Code
resource "aws_s3_bucket" "beanstalk_code_bucket" {
  bucket        = "elastic-beanstalk-sample-app-${random_integer.suffix.result}" # Must be globally unique
  force_destroy = true
}


resource "random_integer" "suffix" {
  min = 1000000
  max = 1999999
}
output "bucket_name" {
  value = "elastic-beanstalk-sample-app-${random_integer.suffix.result}"
}

# You have to zip the content of the folder, not the folder
#../modules/beanstalk/nodejs_v2$ zip -r ../nodejs_v2.zip *


resource "aws_s3_object" "beanstalk_sample_code" {
  bucket = aws_s3_bucket.beanstalk_code_bucket.id
  key    = "nodejs_v2.zip"
  source = "/home/john/learn_terraform/learn-terraform-aws/modules/beanstalk/nodejs_v2.zip" # Replace with your actual sample code path
  etag   = filemd5("/home/john/learn_terraform/learn-terraform-aws/modules/beanstalk/nodejs_v2.zip")
}

resource "aws_elastic_beanstalk_application_version" "app_version" {
  application = aws_elastic_beanstalk_application.my_app.name
  bucket      = aws_s3_bucket.beanstalk_code_bucket.id
  key         = aws_s3_object.beanstalk_sample_code.key
  name        = "v2"

}

resource "aws_s3_object" "beanstalk_sample_code_v0" {
  bucket = aws_s3_bucket.beanstalk_code_bucket.id
  key    = "nodejs.zip"
  source = "/home/john/learn_terraform/learn-terraform-aws/modules/beanstalk/nodejs.zip" # Replace with your actual sample code path
  etag   = filemd5("/home/john/learn_terraform/learn-terraform-aws/modules/beanstalk/nodejs.zip")
}

resource "aws_elastic_beanstalk_application_version" "app_version_v0" {
  application = aws_elastic_beanstalk_application.my_app.name
  bucket      = aws_s3_bucket.beanstalk_code_bucket.id
  key         = aws_s3_object.beanstalk_sample_code_v0.key
  name        = "v0"

}

# Now I Have to find a way to deploy it
