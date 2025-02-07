
# generating key: $ ssh-keygen -t rsa -b 4096 -f key_saa -N ""
# in order for this to be run via gitops, I have to add an environment variable
resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = var.ssh_public_key
}


resource "aws_security_group" "sg_ssh" {
  name   = "sg_ssh"
  vpc_id = var.vpc_id
  ingress {
    from_port   = "22"
    to_port     = "22"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {

    Terraform = "yes"

  }
}

resource "aws_security_group" "sg_web" {
  name        = "sg_web_app"
  vpc_id      = var.vpc_id
  description = "allow 3000"
  tags = {
    Name      = "sg_web"
    Terraform = "yes"
  }
}

resource "aws_security_group_rule" "sg_web_nodejs" {
  type              = "ingress"
  to_port           = "3000"
  from_port         = "3000"
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"] # receives traffic from anywhere 
  security_group_id = aws_security_group.sg_web.id
}

resource "aws_security_group_rule" "sg_web_apache" {
  type              = "ingress"
  to_port           = "80"
  from_port         = "80"
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"] # receives traffic from anywhere 
  security_group_id = aws_security_group.sg_web.id
}



data "aws_subnets" "subnets" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
}



# Fetch the latest Amazon Linux 2 AMI available in the region
# data "aws_ami" "amazon_linux" {
#   most_recent = true
#   owners      = ["amazon"] # Amazon's official AMI owner ID

#   filter {
#     name   = "name"
#     #values = ["al2023-ami-2023.6.20250128.0-kernel-6.1-x86_64"] # Amazon Linux 2 AMI
#     values = ["Amazon Linux 2023 AMI"]
#   }

#   filter {
#     name   = "virtualization-type"
#     values = ["hvm"]
#   }
# }


###### ASG CREATION

resource "aws_launch_template" "amazon_linux_template" {
  name_prefix   = "app-launch-template"
  image_id      = "ami-0c614dee691cbbf37" #  Amazon Linux 2023 AMI #data.aws_ami.amazon_linux.id # Update with your AMI ID
  instance_type = "t2.micro"

  key_name = aws_key_pair.deployer.key_name # SSH Key for accessing the instance

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.sg_ssh.id, aws_security_group.sg_web.id]
  }
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "optional" # Allows both IMDSv1 and IMDSv2, set to required if you want only IMDSv2
  }

  # only for the launch template this should be encoded
  user_data = base64encode(<<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y docker
    systemctl start docker
    systemctl enable docker

    AccountId=$(curl -s http://169.254.169.254/latest/meta-data/identity-credentials/ec2/info | jq -r .AccountId)
    aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $AccountId.dkr.ecr.us-east-1.amazonaws.com
    APP_VERSION=$(aws ssm get-parameter --name "/app/dev/app_version" --query "Parameter.Value" --output text)
    APP_VERSION=$(echo $APP_VERSION | cut -d "v" -f3)
    ECR_REPO_NAME=$(aws ssm get-parameter --name "/app/dev/ecr_repository_name" --query "Parameter.Value" --output text)
    sudo chmod 666 /var/run/docker.sock
    docker pull $AccountId.dkr.ecr.us-east-1.amazonaws.com/$ECR_REPO_NAME:$APP_VERSION
    docker run -t -d -p 3000:3000 --name $ECR_REPO_NAME $AccountId.dkr.ecr.us-east-1.amazonaws.com/$ECR_REPO_NAME:$APP_VERSION

    yum update -y
    yum install -y amazon-cloudwatch-agent
    yum install -y amazon-cloudwatch-agent httpd

    # Start Apache Server
    systemctl start httpd
    systemctl enable httpd
    echo "Hello World from Apache running on $(curl http://169.254.169.254/latest/meta-data/instance-id) " > /var/www/html/index.html

    # Configure Apache to log in JSON format
    echo 'LogFormat "{   \"LogType\": \"access\",   \"time\": \"%%{%Y-%m-%dT%H:%M:%S%z}t\",   \"remote_ip\": \"%a\",   \"host\": \"%v\",   \"method\": \"%m\",   \"url\": \"%U\",   \"query\": \"%q\",   \"protocol\": \"%H\",   \"status\": \"%>s\",   \"bytes_sent\": \"%B\",   \"referer\": \"%%{Referer}i\",   \"user_agent\": \"%%{User-Agent}i\",   \"response_time_microseconds\": \"%D\",   \"forwarded_for\": \"%%{X-Forwarded-For}i\",   \"http_version\": \"%H\",   \"request\": \"%r\" }" json' > /etc/httpd/conf.d/custom_log_format.conf
    echo 'CustomLog /var/log/httpd/access_log json' >> /etc/httpd/conf.d/custom_log_format.conf
    systemctl restart httpd


    # Ensure Apache's access log file exists
    if [ ! -f /var/log/httpd/access_log ]; then
        touch /var/log/httpd/access_log
    fi


    # Set the region in the CloudWatch Agent configuration file
    sed -i 's/region = .*/region = ${var.aws_region}/' /etc/awslogs/awscli.conf

    # Generate Logs Every Minute
    echo "* * * * * root echo '{\"LogType\": \"sample_logs\", \"message\": \"Sample log generated at $(date --iso-8601=seconds)\"} frommm AWS CloudWatch Agent' >> /var/log/sample_logs" >> /etc/cron.d/generate_logs
    chmod 0644 /etc/cron.d/generate_logs

    # Start CloudWatch Agent

    # Create CloudWatch Agent Configuration File in the correct directory
    cat <<EOT > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
    {
        "agent":{
            "run_as_user":"root"
        },
        "logs": {
            "logs_collected": {
            "files": {
                "collect_list": [
                {
                    "file_path": "/var/log/messages",
                    "log_group_name": "${aws_cloudwatch_log_group.app_log_group.name}",
                    "log_stream_name": "${aws_cloudwatch_log_stream.app_log_stream.name}",
                    "timestamp_format": "%b %d %H:%M:%S.%f"
                },
                {
                    "file_path": "/var/log/sample_logs",
                    "log_group_name": "${aws_cloudwatch_log_group.app_log_group.name}",
                    "log_stream_name": "${aws_cloudwatch_log_stream.app_log_stream.name}",
                    "timestamp_format": "%b %d %H:%M:%S.%f"
                },
                {
                    "file_path": "/var/log/httpd/access_log",
                    "log_group_name": "${aws_cloudwatch_log_group.app_log_group.name}",
                    "log_stream_name": "${aws_cloudwatch_log_stream.app_log_stream.name}",
                    "timestamp_format": "%b %d %H:%M:%S.%f"
                }                
                ]
            }
            }
        }
    }

    EOT

    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a start -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s
    EOF
  )
  #user_data = filebase64(var.path_user_data)

  lifecycle {
    create_before_destroy = true
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_instance_profile.name
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name      = "app"
      Terraform = "yes"
      asg       = var.asg_name
      Env       = var.env
    }
  }
}

resource "aws_autoscaling_group" "app_asg" {
  name                = var.asg_name
  desired_capacity    = 0 #aws_ssm_parameter.desired_asg.value
  max_size            = 1 #aws_ssm_parameter.max_asg.value
  min_size            = 0 #aws_ssm_parameter.min_asg.value
  vpc_zone_identifier = var.public_subnets

  lifecycle {
    ignore_changes = [desired_capacity, max_size, min_size] # it prevents the value from being updated after the first run of Terraform.
  }

  # Attach the Launch Template
  launch_template {
    id      = aws_launch_template.amazon_linux_template.id
    version = "$Latest"
  }

  # Attach to the Target Group
  target_group_arns = [var.app_tg_arn]

  tag {
    key                 = "Name"
    value               = var.asg_name
    propagate_at_launch = true

  }

  health_check_type         = "EC2"
  health_check_grace_period = 5
}

resource "aws_autoscaling_lifecycle_hook" "instance_launch" {
  name                   = "instance-launch-lifecycle"
  autoscaling_group_name = aws_autoscaling_group.app_asg.name
  lifecycle_transition   = "autoscaling:EC2_INSTANCE_LAUNCHING"
  heartbeat_timeout      = 35 #change to 300 in prod
  default_result         = "CONTINUE"
}