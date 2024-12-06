
# 3. Create the Launch Template or Reference the ASG (assuming ASG is already created elsewhere)
# Here, we just refer to the existing ASG `myasg`

###### ASG CREATION
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


data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"] # Amazon's official AMI owner ID

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*-x86_64-ebs"] # Amazon Linux 2 AMI
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
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


resource "aws_launch_template" "ec2" {
  name_prefix = "app-launch-template"
  #image_id      = data.aws_ami.ubuntu.id # Update with your AMI ID
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t3.small"

  key_name = aws_key_pair.deployer.key_name # SSH Key for accessing the instance

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance_profile.name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.sg_ssh.id, aws_security_group.sg_web_apache.id]
  }
  #only for the launch template this should be encoded
  user_data = base64encode(<<-EOF
              #!/bin/bash
              echo "ECS_CLUSTER=${var.cluster_name}" > /etc/ecs/ecs.config
              
              # if I wanted to use an ubuntu image, I have to install the ecs agent manually. However, using ami-ecs from amazon is a better option
              # sudo apt-get install -y docker.io
              # sudo systemctl enable docker
              # sudo systemctl start docker

              # # Create ECS config
              # sudo mkdir /etc/ecs/
              # sudo su
              # echo "ECS_CLUSTER=${var.cluster_name}" > /etc/ecs/ecs.config


              # # Install ECS Agent
              # sudo docker run --name ecs-agent \
              #   --detach=true \
              #   --restart=on-failure:10 \
              #   --volume=/var/run/docker.sock:/var/run/docker.sock \
              #   --volume=/var/log/ecs:/log \
              #   --volume=/var/lib/ecs/data:/data \
              #   --net=host \
              #   --env-file=/etc/ecs/ecs.config \
              #   amazon/amazon-ecs-agent:latest

              EOF
  )

  lifecycle {
    create_before_destroy = false
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
  name                 = "asg_ssa"
  desired_capacity     = 2
  min_size             = 0
  max_size             = 2
  vpc_zone_identifier  = toset(data.aws_subnets.subnets_example.ids)
  termination_policies = ["OldestInstance"]

  # Attach the Launch Template
  launch_template {
    id      = aws_launch_template.ec2.id
    version = "$Latest"
  }

  # # Attach to the Target Group
  # target_group_arns = [aws_lb_target_group.app_apache_tg.arn]

  tag {
    key                 = "Name"
    value               = "app-instance"
    propagate_at_launch = true
  }

  health_check_type         = "EC2"
  health_check_grace_period = 0

  depends_on = [aws_ecs_cluster.demo_cluster]
}
#,aws_ecs_capacity_provider.asg_capacity_provider