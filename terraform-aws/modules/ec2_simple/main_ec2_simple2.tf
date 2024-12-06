
#How to use this  module:

# module "ec2_simple" {
#   source     = "../ec2_simple"
#   ec2_type   = "ubuntu"  # optional. default ubuntu
#   subnet_ids = [aws_subnet.public_subnet_a.id, aws_subnet.private_subnet_a.id]  #optional. default subnet on AZ a of the region
#   #subnet_ids = [ "subnet-48672b46", "subnet-7636a757" ]
#   vpc_id         = aws_vpc.demo_vpc.id # optional. default vpc
#   install_apache = true  # optional. default false. When true, it also installs a security gruop on port 80
#   instance_profile_name=module.ec2_role.aws_iam_instance_profile_name # optional 

# }

variable "ec2_type" {
  type    = string
  default = ""
}

variable "subnet_ids" {
  type    = list(string)
  default = []
}

variable "vpc_id" {
  type        = string
  default     = ""
  description = "description"
}

data "aws_vpc" "default" {
  default = true
}

variable "install_apache" {
  description = "Boolean to determine if Apache should be installed"
  type        = bool
  default     = false
}



data "aws_region" "current" {}

data "aws_subnets" "available_subnets" {
  filter {
    name   = "availability-zone"
    values = ["${data.aws_region.current.name}a"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "random_integer" "random_index" {
  min = 0
  max = length(data.aws_subnets.available_subnets.ids) - 1
}

output "random_subnet_id" {
  value = data.aws_subnets.available_subnets.ids[random_integer.random_index.result]
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

# ssh-keygen -t rsa -b 2048 -m PEM -f key_saa.pem -N ""
##  from bastion chmod 0400 key.pem

# resource "aws_key_pair" "deployer_pem" {
#   key_name   = "deployer-key-pem"
#   public_key = file("${path.module}/key_saa.pem.pub")

#   tags = {
#     Name      = "deployer-key"
#     Terraform = "yes"
#   }
# }



resource "aws_security_group" "sg_ssh" {

  name = "sg_ssh"
  ingress {
    from_port   = "22"
    to_port     = "22"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  vpc_id = var.vpc_id != "" ? var.vpc_id : data.aws_vpc.default.id
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
output "test_key" {
  value       = var.subnet_ids #data.aws_subnets.available_subnets.ids[random_integer.random_index.result]
  description = "description"
}

# Read the local file content (private key) into a variable
data "local_file" "private_key" {
  filename = "${path.module}/key_saa" # Adjust the path to your local file
}

output "private_key" {
  value = data.local_file.private_key.content

}

resource "aws_security_group" "sg_web" {
  count       = var.install_apache == true ? 1 : 0
  name        = "sg_web"
  description = "allow 80"
  vpc_id      = var.vpc_id != "" ? var.vpc_id : data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name      = "sg_web"
    Terraform = "yes"
    aws_saa   = "yes"
  }
}


variable "instance_profile_name" {
  type        = string
  default     = ""
  description = "description"
}

# naming my ec2 private or public

# Data source to get route tables for each subnet
data "aws_route_table" "subnet_route_tables" {
  count     = length(var.subnet_ids)
  subnet_id = var.subnet_ids[count.index]
}

# Local variable to determine if each subnet is public or private
locals {
  subnet_types = {
    for i, subnet_id in var.subnet_ids : subnet_id =>
    (
      length([for route in data.aws_route_table.subnet_route_tables[i].routes : route.gateway_id if route.gateway_id != null && startswith(route.gateway_id, "igw-")]) > 0 ? "public" : "private"
    )
  }
}


output "subnet_type_map" {
  value = local.subnet_types
}



resource "aws_instance" "ec2_simple" {
  #count = length(var.subnet_ids) > 0 ? 
  count = length(
    length(var.subnet_ids) > 0 ? var.subnet_ids : [data.aws_subnets.available_subnets.ids[random_integer.random_index.result]]
  )

  ami = var.ec2_type == "amazon" ? data.aws_ami.amazon_linux.id : data.aws_ami.ubuntu.id
  #ami                    = data.aws_ami.ubuntu.id
  key_name               = aws_key_pair.deployer.key_name
  instance_type          = "t2.micro"
  subnet_id              = length(var.subnet_ids) > 0 ? var.subnet_ids[count.index] : data.aws_subnets.available_subnets.ids[random_integer.random_index.result]
  vpc_security_group_ids = var.install_apache == true ? [aws_security_group.sg_ssh.id, aws_security_group.sg_web[0].id] : [aws_security_group.sg_ssh.id]

  user_data = <<-EOF
                #!/bin/bash

                # Update the package list
                sudo apt update

                # Install required packages
                sudo apt install -y unzip curl

                # Download and install AWS CLI
                curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
                unzip awscliv2.zip
                sudo ./aws/install

                # Clean up
                rm -rf awscliv2.zip aws

                # Verify installation
                aws --version
                if [ "${var.install_apache}" = "true" ]; then
                  # Create the key as the ubuntu user
                  sudo -u ubuntu bash -c 'echo "${data.local_file.private_key.content}" > /home/ubuntu/key'
                  sudo -u ubuntu bash -c 'chmod 0400 /home/ubuntu/key'  # Set correct permissions for the private key file

                  #apt-get update
                  apt-get install -y apache2
                  sed -i -e 's/80/80/' /etc/apache2/ports.conf
                  echo "Hello World" > /var/www/html/index.html
                  systemctl restart apache2         
                else
                  # Create the key as the ubuntu user
                  sudo -u ubuntu bash -c 'echo "${data.local_file.private_key.content}" > /home/ubuntu/key'
                  sudo -u ubuntu bash -c 'chmod 0400 /home/ubuntu/key'  # Set correct permissions for the private key file
                fi

                EOF

  iam_instance_profile = var.instance_profile_name


  tags = {
    #Name      = "aws_saa_${var.ec2_type}"
    Name = length(var.subnet_ids) > 0 ? format("saa_ec2_%s", local.subnet_types[var.subnet_ids[count.index]]) : "saa_ec2_${var.ec2_type}_public"

    Terraform = "yes"
    aws_saa   = "yes"
  }
}


## this SG is not needed, I just created it because I  need it for one of the instances.

# Create a new security group that allows SSH from sg_ssh
resource "aws_security_group" "allow_ssh_from_sg_ssh" {
  name        = "private_ssh_sg"
  description = "Security group to allow SSH from another SG"
  vpc_id      = var.vpc_id != "" ? var.vpc_id : data.aws_vpc.default.id

  ingress {
    description     = "Allow SSH from sg_ssh"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_ssh.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name      = "private_ssh_sg"
    Terraform = "yes"
  }
}


# resource "aws_network_interface" "test" {
#   subnet_id       = "subnet-9631a6c9" #aws_subnet.public_a.id
#   private_ips     = ["172.31.32.15"]
#   security_groups = ["sg-9ff5b797"]

#   attachment {
#     instance     = aws_instance.ec2_simple[1].id
#     device_index = 1
#   }
#     tags = {
#     Name      = "aws_saa"
#     Terraform = "yes"
#     aws_saa   = "yes"
#   }
# }

# Create an EBS volume
# resource "aws_ebs_volume" "example_volume" {
#   availability_zone = aws_instance.ec2_simple[0].availability_zone
#   size              = 2     # Size of the volume in GiB
#   type              = "gp2" # General Purpose SSD (can be gp3, io1, etc.)

#   tags = {
#     Name      = "aws_saa_volume"
#     Terraform = "yes"
#     aws_saa   = "yes"
#   }
# }

# # Attach the EBS volume to the EC2 instance
# resource "aws_volume_attachment" "ebs_attachment" {
#   device_name = "/dev/sdh" # Device name used to attach the volume to the instance
#   volume_id   = aws_ebs_volume.example_volume.id
#   instance_id = aws_instance.ec2_simple[0].id
# }