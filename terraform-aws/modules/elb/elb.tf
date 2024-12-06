# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0


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
  name = "sg_ssh"
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
  description = "allow 80"
  tags = {
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

resource "aws_security_group" "sg_web_nginx" {
  name        = "sg_web_nginx"
  description = "allow 8080"
  tags = {
    Terraform = "yes"
    aws_saa   = "yes"
  }
}

resource "aws_security_group_rule" "sg_web_nginx" {
  type      = "ingress"
  to_port   = "8080"
  from_port = "8080"
  protocol  = "tcp"
  #cidr_blocks       = ["0.0.0.0/0"]
  source_security_group_id = aws_security_group.sg_alb.id # only receives traffic from ALB
  security_group_id        = aws_security_group.sg_web_nginx.id
}


variable "apache_ec2s" {
  type        = set(string)
  default     = ["apache1", "apache2"]
  description = "only apache servers"
}
variable "nginx_ec2s" {
  type        = set(string)
  default     = ["nginx1", "nginx2"]
  description = "only nginx servers"
}
variable "apache_nginx_ec2s" {
  type        = set(string)
  default     = ["apache_nginx1"]
  description = "both nginx (8080) and apache (80)"
}


resource "aws_instance" "apaches" {
  for_each = var.apache_ec2s
  ami      = data.aws_ami.ubuntu.id
  #ami                    = data.aws_ami.ubuntu.id
  key_name      = aws_key_pair.deployer.key_name
  instance_type = "t2.micro"
  #vpc_security_group_ids = [aws_security_group.sg_ssh.id]
  vpc_security_group_ids = [aws_security_group.sg_ssh.id, aws_security_group.sg_web_apache.id]

  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update
              sudo apt-get install -y apache2
              sed -i -e 's/80/80/' /etc/apache2/ports.conf
              HOSTNAME=$(hostname)
              echo "<html><body><h1>Welcome to APACHE!</h1><p>Hostname: $HOSTNAME</p><p>InstanceName: aws_ssa_${each.value}</p></body></html>" | sudo tee /var/www/html/index.html
              systemctl restart apache2
              EOF
  tags = {
    Name      = "aws_ssa_${each.value}"
    Terraform = "yes"
    aws_saa   = "yes"
  }
}


resource "aws_instance" "nginxs" {
  for_each = var.nginx_ec2s
  ami      = data.aws_ami.ubuntu.id
  #ami                    = data.aws_ami.ubuntu.id
  key_name      = aws_key_pair.deployer.key_name
  instance_type = "t2.micro"
  #vpc_security_group_ids = [aws_security_group.sg_ssh.id]
  vpc_security_group_ids = [aws_security_group.sg_ssh.id, aws_security_group.sg_web_nginx.id]

  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update
              sudo apt-get install -y nginx
              sudo sed -i 's/listen 80/listen 8080/' /etc/nginx/sites-available/default
              sudo sed -i '/listen \[::\]:80 default_server;/d' /etc/nginx/sites-available/default
              HOSTNAME=$(hostname)
              echo "<html><body><h1>Welcome to NGINX!</h1><p>Hostname: $HOSTNAME</p><p>InstanceName: aws_ssa_${each.value}</p></body></html>" | sudo tee /var/www/html/index.html
              sudo systemctl restart nginx
              EOF
  tags = {
    Name      = "aws_ssa_${each.value}"
    Terraform = "yes"
    aws_saa   = "yes"
  }
}

resource "aws_instance" "nginx_apache_ec2s" {
  for_each = var.apache_nginx_ec2s
  ami      = data.aws_ami.ubuntu.id
  #ami                    = data.aws_ami.ubuntu.id
  key_name      = aws_key_pair.deployer.key_name
  instance_type = "t2.micro"
  #vpc_security_group_ids = [aws_security_group.sg_ssh.id]
  vpc_security_group_ids = [aws_security_group.sg_ssh.id, aws_security_group.sg_web_apache.id, aws_security_group.sg_web_nginx.id]

  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update
              sudo apt-get install -y apache2
              sed -i -e 's/80/80/' /etc/apache2/ports.conf
              HOSTNAME=$(hostname)
              systemctl restart apache2
              
              sudo apt-get install -y nginx
              sudo sed -i 's/listen 80/listen 8080/' /etc/nginx/sites-available/default
              sudo sed -i '/listen \[::\]:80 default_server;/d' /etc/nginx/sites-available/default
              HOSTNAME=$(hostname)
              sudo systemctl restart nginx

              echo "<html><body><h1>Welcome to NGINX and APACHE sever!</h1><p>Hostname: $HOSTNAME</p><p>InstanceName: aws_ssa_${each.value}</p></body></html>" | sudo tee /var/www/html/index.html

              EOF
  tags = {
    Name      = "aws_ssa_${each.value}"
    Terraform = "yes"
    aws_saa   = "yes"
  }
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

  enable_deletion_protection = false
  idle_timeout               = 60 # Time (in seconds) before idle connections are closed

  tags = {
    Name      = "my-app-alb"
    Terraform = "yes"
    aws_saa   = "yes"
  }
  depends_on = [aws_instance.nginx_apache_ec2s, aws_instance.apaches, aws_instance.nginxs]
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



# 3. Target Group
resource "aws_lb_target_group" "app_nginx_tg" {
  name     = "app-nginx-target-group"
  port     = 8080
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
    Name = "app-nginx-tg"
  }
}

# 4. Listener for ALB (HTTP on port 80)
resource "aws_lb_listener" "alb_nginx_listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "8080"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_nginx_tg.arn
  }

}



resource "aws_lb_listener_rule" "rule_path1_nginx" {
  listener_arn = aws_lb_listener.alb_nginx_listener.arn
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_nginx_tg.arn
  }
  condition {
    path_pattern {
      values = ["/nginx/*"]
    }
  }
}





### ATTACHING ec2s to TGs . Uncomment this paRT  after the fiirst run,  attaching TGs doesn't wait for ec2s to be created. 

### DEATACCHING THEM - toogle
# variable "detach_targets" {
#   description = "Control whether to detach targets"
#   type        = bool
#   default     = false
# }

# locals {
#   apache_ids     = concat([for instance in aws_instance.apaches : instance.id], [for instance in aws_instance.nginx_apache_ec2s : instance.id])
#   apache_ids_map = { for id in local.apache_ids : id => id }
# }



# locals {
#   nginx_ids     = concat([for instance in aws_instance.nginxs : instance.id], [for instance in aws_instance.nginx_apache_ec2s : instance.id])
#   nginx_ids_map = { for id in local.nginx_ids : id => id }
# }



# resource "aws_lb_target_group_attachment" "apache_attachment" {
#   for_each = var.detach_targets ? {} : local.apache_ids_map
#   target_group_arn = aws_lb_target_group.app_apache_tg.arn
#   target_id        = each.value
#   port             = 80 # Port where the instance is listening (e.g., Apache running on port 80)

# }


# resource "aws_lb_target_group_attachment" "nginx_attachment" {
#   for_each = var.detach_targets ? {} : local.nginx_ids_map #toset(aws_instance.nginx_apache_ec2s[*].id)#toset(data.aws_instances.nginx_instances.ids)
#   target_group_arn = aws_lb_target_group.app_nginx_tg.arn
#   target_id        = each.value
#   port             = 8080 # Port where the instance is listening (e.g., Nginx running on port 8080)

# }

# output "aws_instances_nginx" {
#   #value       = aws_instance.nginx_apache_ec2s["apache_nginx1"].id
#   #value       = [for instance in aws_instance.apaches: instance.id ] #["apache_nginx1"].id
#   value = local.nginx_ids_map
# }

# output "aws_instances_apache" {
#   #value       = aws_instance.nginx_apache_ec2s["apache_nginx1"].id
#   #value       = [for instance in aws_instance.apaches: instance.id ] #["apache_nginx1"].id
#   value = local.apache_ids_map
# }


# ## attaching for nlb only
# resource "aws_lb_target_group_attachment" "alb_attachment_80" {
#   count            = var.detach_targets ? 0 : 1
#   target_group_arn = aws_lb_target_group.nlb_to_alb_target_group_http_80.arn
#   target_id        = aws_lb.alb.arn
#   port             = 80 # Port where the instance is listening (e.g., Nginx running on port 8080)

# }
# resource "aws_lb_target_group_attachment" "alb_attachment_8080" {
#   count            = var.detach_targets ? 0 : 1
#   target_group_arn = aws_lb_target_group.nlb_to_alb_target_group_http_8080.arn
#   target_id        = aws_lb.alb.arn
#   port             = 8080 # Port where the instance is listening (e.g., Nginx running on port 8080)

# }



#####################################3
## Step 1 create NLB
### creating security group for ALB
resource "aws_security_group" "sg_nlb" {
  name        = "sg_nlb"
  description = "Allow inbound HTTP listening on port 80 and 8080 traffic to NLB"
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

### Step 3, create nlb
resource "aws_lb" "my_nlb" {
  name                       = "my-nlb"
  internal                   = false
  load_balancer_type         = "network"
  security_groups            = [aws_security_group.sg_nlb.id]
  subnets                    = toset(data.aws_subnets.subnets_example.ids)
  enable_deletion_protection = false
  idle_timeout               = 60 # Time (in seconds) before idle connections are closed

  tags = {
    Name      = "my-app-nlb"
    Terraform = "yes"
    aws_saa   = "yes"
  }
  depends_on = [aws_lb.alb]
}




### Step 3: Create NLB Target Group for ALB ###
resource "aws_lb_target_group" "nlb_to_alb_target_group_http_80" {
  name                 = "nlb-to-alb-target-group-80"
  port                 = 80
  protocol             = "TCP"
  vpc_id               = var.vpc_id
  target_type          = "alb"
  deregistration_delay = 0 # Adjust this value (default is 300 seconds)

}
resource "aws_lb_target_group" "nlb_to_alb_target_group_http_8080" {
  name                 = "nlb-to-alb-target-group-8080"
  port                 = 8080
  protocol             = "TCP"
  vpc_id               = var.vpc_id
  target_type          = "alb"
  deregistration_delay = 0 # Adjust this value (default is 300 seconds)
}

### Step 4: Create a Listeners for NLB ###
resource "aws_lb_listener" "nlb_listener_80" {
  load_balancer_arn = aws_lb.my_nlb.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nlb_to_alb_target_group_http_80.arn
  }
}

resource "aws_lb_listener" "nlb_listener_8080" {
  load_balancer_arn = aws_lb.my_nlb.arn
  port              = 8080
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nlb_to_alb_target_group_http_8080.arn
  }
}

