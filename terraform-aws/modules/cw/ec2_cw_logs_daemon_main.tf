variable "region" {
  type    = string
  default = ""

}


data "aws_region" "current" {}


# Fetch the latest Amazon Linux 2 AMI available in the region
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"] # Amazon's official AMI owner ID

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"] # Amazon Linux 2 AMI
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# generating key: $ ssh-keygen -t rsa -b 4096 -f key_saa -N ""
# Create the key pair only if it doesn't already exist
resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = file("${path.module}/key_saa.pub")

  tags = {
    Name      = "deployer-key"
    Terraform = "yes"
  }
}


resource "aws_security_group" "sg_ssh" {

  name = "sg_ssh"
  ingress {
    from_port   = "22"
    to_port     = "22"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  vpc_id = "vpc-53cd6b2e"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name      = "sg_ssh"
    Terraform = "yes"
    aws_saa   = "yes"
  }
}

resource "random_integer" "suffix" {
  min = 1000
  max = 1999
}

variable "Component" {
  type    = string
  default = "ec2_cw"
}

# CloudWatch Log Group for CloudWatch Logs Daemon, CloudWatch Agent and    Unified
resource "aws_cloudwatch_log_group" "ec2_log_group" {
  name              = "/${data.aws_region.current.name}/${var.Component}"
  retention_in_days = 1 # Retain logs for 7 days

}

# CloudWatch Log Stream for CloudWatch Logs Daemon
resource "aws_cloudwatch_log_stream" "ec2_log_stream" {
  name           = "ec2_cw-${random_integer.suffix.result}"
  log_group_name = aws_cloudwatch_log_group.ec2_log_group.name
}

# IAM Role for EC2 to Access CloudWatch
resource "aws_iam_role" "ec2_cloudwatch_role" {
  name = "ec2-cloudwatch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for Logging Permissions
resource "aws_iam_policy" "cloudwatch_log_policy" {
  name = "cloudwatch-log-policy-logs-daemon"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

# Attach IAM Policy to Role
resource "aws_iam_role_policy_attachment" "attach_policy" {
  role       = aws_iam_role.ec2_cloudwatch_role.name
  policy_arn = aws_iam_policy.cloudwatch_log_policy.arn
}

# EC2 Instance Profile for IAM Role
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2-instance-profile"
  role = aws_iam_role.ec2_cloudwatch_role.name
}


# EC2 Instance  -- Exporting files to CW using AWS CloudWatch Logs Daemon (different from AWS CW Agent and Unified Agent)
resource "aws_instance" "ec2_cw_logs_daemon" {

  ami                    = data.aws_ami.amazon_linux.id
  key_name               = aws_key_pair.deployer.key_name
  instance_type          = "t2.micro"
  subnet_id              = "subnet-48672b46"
  vpc_security_group_ids = [aws_security_group.sg_ssh.id]

  # User Data to Configure Logging and Generate Logs, this script also add lines to the var/log/mesagge file which will be sent to cloudwatch
  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y awslogs

    # Configure AWS Logs
    cat <<EOT > /etc/awslogs/awslogs.conf
    [general]
    state_file = /var/lib/awslogs/agent-state

    [/var/log/messages]
    file = /var/log/messages
    log_group_name = ${aws_cloudwatch_log_group.ec2_log_group.name}
    log_stream_name = ${aws_cloudwatch_log_stream.ec2_log_stream.name}
    datetime_format = %b %d %H:%M:%S.%f


    [/var/log/sample_logs]
    file = /var/log/sample_logs
    log_group_name = ${aws_cloudwatch_log_group.ec2_log_group.name}
    log_stream_name = ${aws_cloudwatch_log_stream.ec2_log_stream.name}
    datetime_format = %b %d %H:%M:%S.%f


    EOT

    # Update AWS Logs Configuration
    sed -i 's/region = .*/region = ${data.aws_region.current.name}/' /etc/awslogs/awscli.conf

    # Start AWS Logs Service
    systemctl start awslogsd
    systemctl enable awslogsd

    # Generate Logs Every Minute
    echo "* * * * * root echo '{\"LogType\": \"sample_logs\", \"message\": \"Sample log generated at $(date --iso-8601=seconds)\"} from AWS CloudWatch Logs Daemon' >> /var/log/sample_logs" > /etc/cron.d/generate_logs
    chmod 0644 /etc/cron.d/generate_logs
  EOF

  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name


  tags = {
    Name         = "ec2_cw-${random_integer.suffix.result}"
    Terraform    = "yes"
    aws_dva_c02  = "yes"
    Component    = var.Component
    CW_collector = "AWS CloudWatch Logs Daemon"

  }
}
