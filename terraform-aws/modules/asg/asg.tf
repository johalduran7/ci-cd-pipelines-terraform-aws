# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

#to use:
# module asg {
#   source= "./modules/asg"
#   vpc_id="" #optional
# }

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

# generating key: $ ssh-keygen -t rsa -b 4096 -f key_saa -N ""
resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = file("${path.module}/key_saa.pub")
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
  // connectivity to ubuntu mirrors is required to run `apt-get update` and `apt-get install apache2`
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {

    Terraform = "yes"
    aws_saa   = "yes"
  }
}

resource "aws_security_group" "sg_web_apache" {
  name        = "sg_web_apache"
  vpc_id      = var.vpc_id
  description = "allow 80"
  tags = {
    Name      = "sg_web_apache"
    Terraform = "yes"
    aws_saa   = "yes"
  }
}

resource "aws_security_group_rule" "sg_web_apache" {
  type              = "ingress"
  to_port           = "80"
  from_port         = "80"
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"] # receives traffic from anywhere 
  security_group_id = aws_security_group.sg_web_apache.id
}


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




###### ASG CREATION

resource "aws_launch_template" "ubuntu_template" {
  name_prefix   = "app-launch-template"
  image_id      = data.aws_ami.ubuntu.id # Update with your AMI ID
  instance_type = "t2.micro"

  key_name = aws_key_pair.deployer.key_name # SSH Key for accessing the instance

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.sg_ssh.id, aws_security_group.sg_web_apache.id]
  }
  # only for the launch template this should be encoded
  user_data = base64encode(<<-EOF
              #!/bin/bash
              sudo apt-get update
              sudo apt-get install -y apache2
              sed -i -e 's/80/80/' /etc/apache2/ports.conf
              HOSTNAME=$(hostname)
              echo "<html><body><h1>Welcome to APACHE!</h1><p>Hostname: $HOSTNAME</p><p>InstanceName: aws_ssa_asg</p></body></html>" | sudo tee /var/www/html/index.html
              systemctl restart apache2
              EOF
  )
  lifecycle {
    create_before_destroy = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name      = "aws_ssa_ec2_asg"
      Terraform = "yes"
      aws_saa   = "yes"
    }
  }
}

resource "aws_autoscaling_group" "app_asg" {
  name                = "asg_ssa"
  desired_capacity    = 2
  max_size            = 2
  min_size            = 1
  vpc_zone_identifier = toset(data.aws_subnets.subnets_example.ids)
  #vpc_zone_identifier=toset(local.az_subnet_map)

  # Attach the Launch Template
  launch_template {
    id      = aws_launch_template.ubuntu_template.id
    version = "$Latest"
  }

  # Attach to the Target Group
  target_group_arns = [aws_lb_target_group.app_apache_tg.arn]

  tag {
    key                 = "Name"
    value               = "app-instance-asg"
    propagate_at_launch = true

  }

  health_check_type         = "EC2"
  health_check_grace_period = 5
}
