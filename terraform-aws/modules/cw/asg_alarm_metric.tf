




variable "vpc_id" {
  type    = string
  default = "vpc-53cd6b2e"

}


data "aws_subnets" "subnets_example" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
}




# 2. Create ALB.
### creating security group for ALB
resource "aws_security_group" "sg_alb" {
  name        = "sg_alb"
  description = "Allow inbound HTTP listening on port 80 and 8080 traffic to ALB"
  vpc_id      = var.vpc_id # Replace with your VPC ID. Only one VPC unless using lambda or VPC peering

  # Allow inbound traffic on port 80 (HTTP)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow from the internet
  }

  # Allow inbound traffic on port 443 (HTTPS)
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow from the internet
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # "-1" allows all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name      = "my-app-alb-sg"
    Terraform = "yes"
    aws_saa   = "yes"
  }
}


resource "aws_lb" "alb" {
  name               = "my-app-alb"
  internal           = false # This makes the ALB internet-facing
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sg_alb.id]
  subnets            = toset(data.aws_subnets.subnets_example.ids) # Replace with your Subnet IDs, this is where the both, targets and alb itself are hosted
  #subnets=toset(local.az_subnet_map)
  enable_deletion_protection = false
  idle_timeout               = 60 # Time (in seconds) before idle connections are closed

  tags = {
    Name      = "my-app-alb"
    Terraform = "yes"
    aws_saa   = "yes"
  }

}

# 3. Target Group
resource "aws_lb_target_group" "app_apache_tg" {
  name     = "app-apache-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id # Replace with your VPC ID

  health_check {
    path                = "/"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
  }

  # Apply deregistration delay (in seconds)
  deregistration_delay = 0 # Adjust this value (default is 300 seconds)



  tags = {
    Name = "app-apache-tg"
  }
}

# 4. Listener for ALB (HTTP on port 80)
resource "aws_lb_listener" "alb_apache_listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_apache_tg.arn
  }
}


output "alb_dns_name" {
  value       = aws_lb.alb.dns_name
  description = "The DNS name of the ALB"
}

output "alb_id" {
  value       = aws_lb.alb.id
  description = "The ID of the ALB"
}


# CloudWatch Log Group for CloudWatch Logs Daemon, CloudWatch Agent and    Unified
resource "aws_cloudwatch_log_group" "asg_log_group" {
  name              = "/${data.aws_region.current.name}/asg"
  retention_in_days = 1 # Retain logs for 7 days

}

# CloudWatch Log Stream for CloudWatch Logs Daemon
resource "aws_cloudwatch_log_stream" "asg_log_stream" {
  name           = "asg_apache"
  log_group_name = aws_cloudwatch_log_group.ec2_log_group.name
}

###### ASG CREATION




resource "aws_launch_template" "amazon_linux_template" {
  name_prefix   = "app-launch-template"
  image_id      = data.aws_ami.amazon_linux.id # Update with your AMI ID
  instance_type = "t2.micro"

  key_name = aws_key_pair.deployer.key_name # SSH Key for accessing the instance

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.sg_ssh.id, aws_security_group.sg_web.id]
  }
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_instance_profile.name
  }
  # only for the launch template this should be encoded
  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y amazon-cloudwatch-agent

    yum install -y amazon-cloudwatch-agent httpd
    # Start Apache Server
    systemctl start httpd
    systemctl enable httpd

    echo "Hello World from Apache running on $(curl http://169.254.169.254/latest/meta-data/instance-id)" > /var/www/html/index.html

    # Configure Apache to log in JSON format


    echo 'LogFormat "{   \"LogType\": \"access\",   \"time\": \"%%{%Y-%m-%dT%H:%M:%S%z}t\",   \"remote_ip\": \"%a\",   \"host\": \"%v\",   \"method\": \"%m\",   \"url\": \"%U\",   \"query\": \"%q\",   \"protocol\": \"%H\",   \"status\": \"%>s\",   \"bytes_sent\": \"%B\",   \"referer\": \"%%{Referer}i\",   \"user_agent\": \"%%{User-Agent}i\",   \"response_time_microseconds\": \"%D\",   \"forwarded_for\": \"%%{X-Forwarded-For}i\",   \"http_version\": \"%H\",   \"request\": \"%r\" }" json' > /etc/httpd/conf.d/custom_log_format.conf
    echo 'CustomLog /var/log/httpd/access_log json' >> /etc/httpd/conf.d/custom_log_format.conf


    systemctl restart httpd


    # Ensure Apache's access log file exists
    if [ ! -f /var/log/httpd/access_log ]; then
      touch /var/log/httpd/access_log
    fi


    # Set the region in the CloudWatch Agent configuration file
    sed -i 's/region = .*/region = ${data.aws_region.current.name}/' /etc/awslogs/awscli.conf

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
                    "log_group_name": "${aws_cloudwatch_log_group.asg_log_group.name}",
                    "log_stream_name": "${aws_cloudwatch_log_stream.asg_log_stream.name}",
                    "timestamp_format": "%b %d %H:%M:%S.%f"
                },
                {
                    "file_path": "/var/log/sample_logs",
                    "log_group_name": "${aws_cloudwatch_log_group.asg_log_group.name}",
                    "log_stream_name": "${aws_cloudwatch_log_stream.asg_log_stream.name}",
                    "timestamp_format": "%b %d %H:%M:%S.%f"
                },
                {
                    "file_path": "/var/log/httpd/access_log",
                    "log_group_name": "${aws_cloudwatch_log_group.asg_log_group.name}",
                    "log_stream_name": "${aws_cloudwatch_log_stream.asg_log_stream.name}",
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
  lifecycle {
    create_before_destroy = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name         = "ec2_cw-${random_integer.suffix.result}-apache"
      Terraform    = "yes"
      aws_dva_c02  = "yes"
      Component    = var.Component
      CW_collector = "AWS CloudWatch Agent"
      Apache       = "yes"
    }
  }

}

resource "aws_autoscaling_group" "app_asg" {
  name                = "asg_ssa"
  desired_capacity    = 2
  max_size            = 3
  min_size            = 2
  vpc_zone_identifier = toset(data.aws_subnets.subnets_example.ids)

  # Attach the Launch Template
  launch_template {
    id      = aws_launch_template.amazon_linux_template.id
    version = "$Latest"
  }

  # Attach to the Target Group
  target_group_arns = [aws_lb_target_group.app_apache_tg.arn]

  tag {
    key                 = "Name"
    value               = "ec2-cw-apache-asg"
    propagate_at_launch = true

  }

  health_check_type         = "EC2"
  health_check_grace_period = 5
}
