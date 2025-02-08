#Create ALB.


data "aws_subnets" "subnets" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
}

### creating security group for ALB
resource "aws_security_group" "sg_alb" {
  name        = "${var.env}-sg_alb"
  description = "Allow inbound HTTP listening on port 8080 traffic to ALB"
  vpc_id      = var.vpc_id # Replace with your VPC ID. Only one VPC unless using lambda or VPC peering

  # Allow inbound traffic on port 8080 (HTTPS)
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
    Name      = "${var.env}-app-alb-sg"
    Terraform = "yes"
  }
}


resource "aws_lb" "alb" {
  name               = "${var.env}-app-alb"
  internal           = false # This makes the ALB internet-facing
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sg_alb.id]
  subnets            = var.public_subnets # Replace with your Subnet IDs, this is where the both, targets and alb itself are hosted
  #subnets=toset(local.az_subnet_map)
  enable_deletion_protection = false
  idle_timeout               = 60 # Time (in seconds) before idle connections are closed

  tags = {
    Name      = "${var.env}-app-alb"
    Terraform = "yes"

  }

}

# 3. Target Group
resource "aws_lb_target_group" "app_tg" {
  name     = "${var.env}-app-target-group"
  port     = 3000
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
    Name = "${var.env}-app-tg"
  }
}

# 4. Listener for ALB (HTTP on port 80)
resource "aws_lb_listener" "alb_listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "8080"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

