
# 1. Create the ECS Cluster
variable "cluster_name" {
  type    = string
  default = "DemoCluster"
}

# this is needed for aws ecs execute-command
resource "aws_cloudwatch_log_group" "ecs_cluster_cloudwatch" { 
  name = "/ecs/exec"
  retention_in_days = 1 # Retain logs for 7 days
}


resource "aws_ecs_cluster" "demo_cluster" {
  name = var.cluster_name

  # this is needed for aws ecs execute-command. See if it's enabled aws ecs describe-clusters --clusters DemoCluster --output json

  configuration {
    execute_command_configuration {
      logging    = "OVERRIDE"

      log_configuration {
        cloud_watch_encryption_enabled = false
        cloud_watch_log_group_name     = aws_cloudwatch_log_group.ecs_cluster_cloudwatch.name
      }
    }
  }

  tags = {
    Terraform = "yes"
  }
}

# 2. Create a Security Group for the ECS Cluster
resource "aws_security_group" "ecs_sg" {
  name   = "ecs_cluster_sg"
  vpc_id = var.vpc_id # Ensure to provide the VPC ID in the variables

  ingress {
    from_port   = 80
    to_port     = 80
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
    Name      = "ECS Cluster SG"
    Terraform = "yes"
  }
}


# Attach ASG to the ECS Cluster
resource "aws_ecs_capacity_provider" "asg_capacity_provider" {
  name = "DemoCapacityProvider"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.app_asg.arn

    managed_scaling {
      status                    = "ENABLED"
      target_capacity           = 100
      minimum_scaling_step_size = 1
      maximum_scaling_step_size = 2
    }

    managed_termination_protection = "DISABLED" # when enabled ASG cannot terminate the tasks but only ECS
  }

  tags = {
    Name      = "DemoCapacityProvider"
    Terraform = "yes"
  }
  depends_on = [aws_ecs_cluster.demo_cluster]
}

resource "aws_ecs_cluster_capacity_providers" "cluster_capacity_providers" {
  cluster_name = var.cluster_name

  capacity_providers = [aws_ecs_capacity_provider.asg_capacity_provider.name]
}



# 4. Create the Fargate Task Definition
resource "aws_ecs_task_definition" "fargate_task" {
  family                   = "demo_fargate_task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  # you can define up to 10 containers per task definition
  container_definitions = jsonencode([{
    name      = "demo-container"
    image     = "nginx"
    cpu       = 256
    memory    = 512
    essential = true
    portMappings = [{
      containerPort = 80 # Port where the server is runnin on (Nginx in this case)
      hostPort      = 80 # Port to acces from outside (internet). If this port is set to 0, we have a dynamic Host port.
      protocol      = "tcp"
    }]

    # Health Check Configuration
    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:80 || exit 1"]
      interval    = 30 # Time between health checks (in seconds)
      timeout     = 5  # Time before a health check is considered failed (in seconds)
      retries     = 3  # Number of times to retry before marking as unhealthy
      startPeriod = 60 # Time to wait before health checks start (in seconds)
    }
  }])


  execution_role_arn = aws_iam_role.ecs_execution_role.arn # Ensure this role is created elsewhere
  task_role_arn      = aws_iam_role.ecs_task_role.arn      # Ensure this role is created elsewhere

  tags = {
    Name      = "Demo Fargate Task"
    Terraform = "yes"
  }
}


# 5. Optional: ECS Service to run the Fargate Task
resource "aws_ecs_service" "fargate_service" {
  name            = "demo_fargate_service"
  cluster         = aws_ecs_cluster.demo_cluster.id
  task_definition = aws_ecs_task_definition.fargate_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  enable_execute_command = true  # this is needed to run $ aws ecs execute-command

  network_configuration {
    subnets          = toset(data.aws_subnets.subnets_example.ids)
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }



  tags = {
    Name      = "DemoFargateService"
    Terraform = "yes"
  }
}


### ECS Launch type EC2

# ECS Task Definition
resource "aws_ecs_task_definition" "ec2_task" {
  family                   = "demo_ec2_task_family"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn # Role used by ECS agent to interact with AWS on behalf of your task, e.g. pull ECR images. CoRrre operations
  task_role_arn            = aws_iam_role.ecs_task_role.arn      # RoLe to allow the apps inside the container to interact with AWS Services such as   S3, Dynamo, X-Ray
  requires_compatibilities = ["EC2"]                             # Specify EC2 launch type
  network_mode             = "bridge"                            # For EC2 instances, not required for Fargate

  container_definitions = jsonencode([{
    name      = "apache-container-ec2"
    image     = "httpd:latest" # Use your container image
    cpu       = 128            # CPU units
    memory    = 256            # Memory in MB
    essential = true
    #I deliberately commented the ports of the docker so I could use the strategy binpack, If enable them, the containers will be placed in separate instances not to conflict with each other in ports
    # portMappings = [
    #   {
    #     containerPort = 80
    #     hostPort      = 80
    #     protocol      = "tcp"
    #   }
    # ]
    links = ["xray-daemon"]
  },
  # this installs the Daemon, however, my app doesn't have SDK and code to leverage xray. That's for programmers
  {
    "name": "xray-daemon",  
    "image": "public.ecr.aws/xray/aws-xray-daemon",
    "memory": 128,
    "cpu": 64,
    "essential": false,
    "portMappings": [
      {
        "containerPort": 2000,
        "hostPort": 2000,
        "protocol": "udp"
      }
    ]
  }
  
  ])



  tags = {
    Name      = "MyECSApp_ec2"
    Terraform = "yes"
  }
}

# ECS Service with Placement Strategy -EC2
resource "aws_ecs_service" "ec2_service" {
  name            = "demo_ec2_service"
  cluster         = aws_ecs_cluster.demo_cluster.id
  task_definition = aws_ecs_task_definition.ec2_task.arn
  desired_count   = 1 # Number of tasks you want to run
  launch_type     = "EC2"

  enable_execute_command = true  # this is needed to run $ aws ecs execute-command

  ordered_placement_strategy {
    type  = "binpack" # Binpack strategy
    field = "cpu"     # You can choose "cpu" or "memory" to binpack based on either resource
  }

  # placement_constraints {
  #   type       = "memberOf"
  #   expression = "attribute:ecs.instance-type == t3.small" # Optional: filter instances by type
  # }



  depends_on = [aws_ecs_task_definition.ec2_task, aws_ecs_cluster.demo_cluster]
}


# test adding a separate ec2 and adding it to the cluster. A capacity provider is just a way to automatically register containers available to be used by services
# EC2 Instance for ECS Cluster (optional - you can also use an autoscaling group)
resource "aws_instance" "ecs_instance" {
  ami                  = "ami-0b9369f8572860559"        # Replace with a valid ECS-optimized AMI for your region
  instance_type        = "t3.small"                     # Choose appropriate instance type
  key_name             = aws_key_pair.deployer.key_name # SSH Key for accessing the instance
  subnet_id            = "subnet-48672b46"
  iam_instance_profile = aws_iam_instance_profile.ecs_instance_profile.name

  security_groups = [aws_security_group.sg_ssh.id]
  user_data       = <<-EOF
              #!/bin/bash
              echo "ECS_CLUSTER=${var.cluster_name}" > /etc/ecs/ecs.config

              EOF

  tags = {
    Name = "ECS Instance - cluster"
  }
}