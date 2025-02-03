
#to use:
# module asg {
#   source= "./modules/asg"
#   vpc_id="" #optional
# }



variable "vpc_id" {
  type    = string
  default = "vpc-53cd6b2e"

}


data "aws_subnets" "subnets" {
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
    Name      = "lambda-alb-sg"
    Terraform = "yes"
    aws_saa   = "yes"
  }
}


resource "aws_lb" "alb_lambda" {
  name               = "alb-lambda"
  internal           = false # This makes the ALB internet-facing
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sg_alb.id]
  subnets            = toset(data.aws_subnets.subnets.ids) # Replace with your Subnet IDs, this is where the both, targets and alb itself are hosted
  #subnets=toset(local.az_subnet_map)
  enable_deletion_protection = false
  idle_timeout               = 60 # Time (in seconds) before idle connections are closed

  tags = {
    Name        = "alb_lambda"
    Terraform   = "yes"
    aws_dva_c02 = "yes"
  }

}

# 3. Target Group
resource "aws_lb_target_group" "lambda_tg" {
  name        = "lambda-target-group"
  target_type = "lambda"


  tags = {
    Name = "lambda-tg"
  }
}

resource "aws_lb_target_group_attachment" "lambda_attachment" {
  target_group_arn = aws_lb_target_group.lambda_tg.arn
  target_id        = aws_lambda_function.lambda_alb.arn
}


# 4. Listener for ALB (HTTP on port 80)
resource "aws_lb_listener" "alb_lambda_listener" {
  load_balancer_arn = aws_lb.alb_lambda.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lambda_tg.arn
  }
}


output "alb_dns_name" {
  value       = aws_lb.alb_lambda.dns_name
  description = "The DNS name of the ALB"
}

output "alb_id" {
  value       = aws_lb.alb_lambda.id
  description = "The ID of the ALB"
}


