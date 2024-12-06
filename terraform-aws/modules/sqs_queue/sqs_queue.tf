# This SQS template leverage the module S3 where some preset objects are already uploaded
# then, a policy is added to the SQS to permit S3 to send messages to the queue
# the S3 is also configured to send messages about creation of objects, so whenever you upload an object, a messege will be sent to the SQS  queue
# Then go to the GUI to "Send and Receive messages", poll the messages or send messages even
#  the first run will throw an error about ACL S3, just run it again, I'm not concern about this right now.
variable "bucket_name" {
  default = "demo-john-sqs-queue-v1"
}

data "aws_region" "current" {}


module "s3" {
  source      = "../s3"
  bucket_name = var.bucket_name
}

output "endpoint" {
  value = module.s3.endpoint
}

output "bucket_name" {
  value = module.s3.bucket_name
}

output "bucket_id" {
  value = module.s3.bucket_id
}

# create SQS Queue

# Step 1: Create the SQS Queue
resource "aws_sqs_queue" "s3_notification_queue" {
  #name = "DemoS3Notification"
  name       = "DemoS3Notification.fifo"
  fifo_queue = true

  tags = {
    Name      = "deployer-key"
    Terraform = "yes"
  }
}

# Step 2: Create the SQS Queue Policy to allow S3 access
resource "aws_sqs_queue_policy" "s3_notification_queue_policy" {
  queue_url = aws_sqs_queue.s3_notification_queue.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Id": "SQSQueuePolicyForS3Notification",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "s3.amazonaws.com"
      },
      "Action": "sqs:SendMessage",
      "Resource": "${aws_sqs_queue.s3_notification_queue.arn}",
      "Condition": {
        "ArnLike": {
          "aws:SourceArn": "arn:aws:s3:::${module.s3.bucket_name}"
        }
      }
    },
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "${aws_iam_role.ec2_role_sqs.arn}"
      },
      "Action": [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:ChangeMessageVisibility",
        "sqs:GetQueueAttributes",
        "sqs:GetQueueUrl"
      ],
      "Resource": "${aws_sqs_queue.s3_notification_queue.arn}"
    }
  ]
}
EOF
}


# Step 3: Define an S3 Bucket (optional) and Configure Notifications to SQS


# Optional: Add S3 Notification Configuration to send events to SQS
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = module.s3.bucket_id

  queue {
    queue_arn = aws_sqs_queue.s3_notification_queue.arn
    events    = ["s3:ObjectCreated:*"]
  }
}


###### In the following part, I'm adding an EC2 instance that will poll the messges every 5 minutes and store them in the folder /var/log/sqs_messages.log

# IAM Role for EC2
resource "aws_iam_role" "ec2_role_sqs" {
  name = "ec2-role-sqs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}


# IAM Policy for SQS and S3 Access
resource "aws_iam_policy" "sqs_s3_policy" {
  name = "sqs-s3-access-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:ChangeMessageVisibility"],
        Resource = "arn:aws:s3:::${module.s3.bucket_name}"
      },
      {
        Effect   = "Allow",
        Action   = ["s3:GetObject"],
        Resource = "arn:aws:s3:::${module.s3.bucket_name}/*"
      }
    ]
  })
}

# Attach Policy to Role
resource "aws_iam_role_policy_attachment" "attach_sqs_s3_policy" {
  role       = aws_iam_role.ec2_role_sqs.name
  policy_arn = aws_iam_policy.sqs_s3_policy.arn
}

# EC2 Instance Profile
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2-instance-profile"
  role = aws_iam_role.ec2_role_sqs.name
}

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
  # lifecycle {
  #   create_before_destroy = true
  # }

  // connectivity to ubuntu mirrors is required to run `apt-get update` and `apt-get install apache2`
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

# EC2 Instance
resource "aws_instance" "ec2_sqs" {

  ami                    = data.aws_ami.amazon_linux.id
  key_name               = aws_key_pair.deployer.key_name
  instance_type          = "t2.micro"
  subnet_id              = "subnet-48672b46"
  vpc_security_group_ids = [aws_security_group.sg_ssh.id]

  user_data = <<-EOF
    #!/bin/bash
    yum install -y aws-cli
    while true; do
      aws sqs receive-message --queue-url ${aws_sqs_queue.s3_notification_queue.id} --region ${data.aws_region.current.name} --output json >> /var/log/sqs_messages.log
      sleep 300
    done
  EOF 

  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name


  tags = {
    #Name      = "aws_saa_${var.ec2_type}"
    Name = "ec2_sqs"

    Terraform   = "yes"
    aws_dva_c02 = "yes"
  }
}

output "command_polling" {
  value       = "aws sqs receive-message --queue-url ${aws_sqs_queue.s3_notification_queue.id} --region ${data.aws_region.current.name} --output json >> /var/log/sqs_messages.log"
  description = "to poll messages from ec2"

}

#aws sqs receive-message --queue-url https://sqs.us-east-1.amazonaws.com/948586925757/DemoS3Notification --region us-east-1 --output json 

