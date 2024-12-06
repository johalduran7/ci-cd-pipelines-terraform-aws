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
resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key-2"
  public_key = file("${path.module}/key_saa.pub")
}

variable "iam_instance_profile" {
  type    = string
  default = ""

}

variable "ec2_type" {
  type    = string
  default = ""
}

# Retrieve the default VPC
data "aws_vpc" "default" {
  default = true
}

# Retrieve the default security group of the VPC by filtering on name and vpc_id
data "aws_security_group" "default" {
  vpc_id = data.aws_vpc.default.id
  name   = "default"
}

output "default_security_group_id" {
  value = data.aws_security_group.default.id
}

resource "aws_instance" "example" {
  ami = var.ec2_type == "amazon" ? data.aws_ami.amazon_linux.id : data.aws_ami.ubuntu.id
  #ami                    = data.aws_ami.ubuntu.id
  key_name      = aws_key_pair.deployer.key_name
  instance_type = "t2.micro"
  #vpc_security_group_ids = [aws_security_group.sg_ssh.id]
  vpc_security_group_ids = [aws_security_group.sg_ssh.id, aws_security_group.sg_web.id]
  iam_instance_profile   = var.iam_instance_profile

  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y apache2
              sed -i -e 's/80/80/' /etc/apache2/ports.conf
              echo "Hello World" > /var/www/html/index.html
              systemctl restart apache2
              EOF
  tags = {
    Name      = "aws_saa"
    Terraform = "yes"
    aws_saa   = "yes"
  }
}


# resource "aws_network_interface" "test" {
#   subnet_id       = "subnet-9631a6c9" #aws_subnet.public_a.id
#   private_ips     = ["172.31.32.5"]
#   security_groups = ["sg-04fc863ac6d91c295"]

#   attachment {
#     instance     = aws_instance.example.id
#     device_index = 1
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

resource "aws_security_group" "sg_web" {
  name        = "sg_web"
  description = "allow 80"
  tags = {
    Terraform = "yes"
    aws_saa   = "yes"
  }
}

resource "aws_security_group_rule" "sg_web" {
  type              = "ingress"
  to_port           = "80"
  from_port         = "80"
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.sg_web.id
}

######################### create AMI:
# Create an AMI from the running instance
# resource "aws_ami_from_instance" "example_ami" {
#   name                    = "example-instance-ami-${aws_instance.example.tags["Name"]}" # Give a name to the AMI
#   source_instance_id      = aws_instance.example.id                                     # Use the ID of the running instance
#   snapshot_without_reboot = false                                                       # If true, creates snapshot without stopping instance

#   tags = {
#     Name      = "example-ami"
#     Terraform = "yes"
#     aws_saa   = "yes"
#   }
# }

# Output the AMI ID
# output "ami_id" {
#   value = aws_ami_from_instance.example_ami.id
# }

# resource "aws_instance" "example_from_ami" {
#   ami = aws_ami_from_instance.example_ami.id
#   #ami                    = data.aws_ami.ubuntu.id
#   key_name      = aws_key_pair.deployer.key_name
#   instance_type = "t2.micro"
#   #vpc_security_group_ids = [aws_security_group.sg_ssh.id]
#   vpc_security_group_ids = [aws_security_group.sg_ssh.id, aws_security_group.sg_web.id]
#   iam_instance_profile   = var.iam_instance_profile

#   user_data = <<-EOF
#               #!/bin/bash
#               echo "Hello World from instance created out of AMI" > /var/www/html/index.html
#               EOF
#   tags = {
#     Name      = "aws_saa_out_of_ami"
#     Terraform = "yes"
#     aws_saa   = "yes"
#   }
# }

########################################3
## testing nginx on port 8080




resource "aws_security_group" "sg_web_nginx" {
  name        = "sg_web_nginx"
  description = "allow 8080"
  tags = {
    Terraform = "yes"
    aws_saa   = "yes"
  }
}

resource "aws_security_group_rule" "sg_web_nginx" {
  type              = "ingress"
  to_port           = "8080"
  from_port         = "8080"
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.sg_web_nginx.id
}


resource "aws_instance" "nginx_ec2" {

  ami = data.aws_ami.ubuntu.id
  #ami                    = data.aws_ami.ubuntu.id
  key_name      = aws_key_pair.deployer.key_name
  instance_type = "t2.micro"
  #vpc_security_group_ids = [aws_security_group.sg_ssh.id]
  vpc_security_group_ids = [aws_security_group.sg_ssh.id, aws_security_group.sg_web_nginx.id]

  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update
              sudo apt-get install -y nginx
              sudo sed -i 's/listen 80 default_server;/listen 8080 default_server;/' /etc/nginx/sites-available/default
              sudo sed -i 's/listen \\[::\\]:80 default_server;/listen [::]:8080 default_server;/' /etc/nginx/sites-available/default
              HOSTNAME=$(hostname)
              echo "<html><body><h1>Welcome to NGINX sever!</h1><p>Hostname: $HOSTNAME</p></body></html>" | sudo tee /var/www/html/index.html
              sudo systemctl restart nginx
              EOF
  tags = {
    Name      = "aws_ssa_nginx"
    Terraform = "yes"
    aws_saa   = "yes"
  }
}


#######################################
## create EFS and attach it to EC2
# BE CAREFUL WITH THIS! PROVISIONED TRHOUGHPUT CARRIES SOME EXPENSES, I GOT A BILL O 6USD
# resource "aws_instance" "example_efs" {
#   ami = var.ec2_type == "amazon" ? data.aws_ami.amazon_linux.id : data.aws_ami.ubuntu.id
#   #ami                    = data.aws_ami.ubuntu.id
#   key_name      = aws_key_pair.deployer.key_name
#   instance_type = "t2.micro"
#   #vpc_security_group_ids = [aws_security_group.sg_ssh.id]
#   vpc_security_group_ids = [aws_security_group.sg_ssh.id, aws_security_group.sg_web.id, "sg-9ff5b797"]
#   iam_instance_profile   = var.iam_instance_profile

#   user_data = <<-EOF
#               #!/bin/bash
#               sudo apt-get update
#               sudo apt install -y nfs-common
#               sudo mkdir /mnt/efs
#               sudo mount -t nfs4 -o nfsvers=4.1  ${aws_efs_file_system.example.dns_name}:/ /mnt/efs
#               EOF
#   tags = {
#     Name      = "aws_saa_efs"
#     Terraform = "yes"
#     aws_saa   = "yes"
#   }
#   depends_on = [aws_efs_access_point.example]
# }

# Throughput Mode            Storage Cost (for 1 TB)    Throughput Cost    Total Monthly Cost
# -------------------------  ------------------------  -----------------  -------------------
# Bursting                   $307.20                    $0.00               $307.20
# Provisioned (1024 MiB/s)   $307.20                    $6,144.00           $6,451.20


# provisioned mode is too expensive
# resource "aws_efs_file_system" "example" {
#   performance_mode = "generalPurpose"
#   # Enable Provisioned Throughput (Enhanced Elastic)
#   throughput_mode                 = "provisioned"
#   provisioned_throughput_in_mibps = 1024 # Specify the desired throughput in MiB/s
#   tags = {
#     Name      = "aws_saa_efs"
#     Terraform = "yes"
#     aws_saa   = "yes"
#   }
# }

# bursting mode is cheaper
# resource "aws_efs_file_system" "example" {
#   performance_mode = "generalPurpose"  # Or "maxIO" depending on your use case
#   throughput_mode = "bursting"          # Use bursting throughput instead of provisioned
#   tags = {
#     Name      = "aws_saa_efs"
#     Terraform = "yes"
#     aws_saa   = "yes"
#   }
# }


# resource "aws_efs_mount_target" "example" {
#   file_system_id  = aws_efs_file_system.example.id
#   subnet_id       = aws_instance.example_efs.subnet_id #"subnet-f5c09ab8"
#   security_groups = [data.aws_security_group.default.id]
# }

# resource "aws_efs_access_point" "example" {
#   file_system_id = aws_efs_file_system.example.id

#   posix_user {
#     uid = 1001
#     gid = 1001
#   }

#   root_directory {
#     path = "/export"
#     creation_info {
#       owner_uid   = 1001
#       owner_gid   = 1001
#       permissions = "755"
#     }
#   }
# }

# output "efs_id" {
#   value = aws_efs_file_system.example.id
# }

# output "efs_name" {
#   value = aws_efs_file_system.example.dns_name
# }

# output "instance_public_ip" {
#   value = aws_instance.example_efs.public_ip
# }

