variable "subnet_id" {
  type        = string
  default     = ""
  description = "description"
}

variable "vpc_id" {
  type        = string
  default     = ""
  description = "description"
}

data "aws_vpc" "default" {
  default = true
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

# generating key: $ ssh-keygen -t rsa -b 4096 -f key_saa -N ""
# Create the key pair only if it doesn't already exist
resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key-nat"
  public_key = file("${path.module}/key_saa.pub")

  tags = {
    Name      = "deployer-key"
    Terraform = "yes"
  }
}

# Create a security group to allow HTTP and HTTPS traffic
resource "aws_security_group" "nat_instance_sg" {
  name        = "nat-instance-sg"
  description = "Allow HTTP and HTTPS traffic"
  vpc_id      = var.vpc_id != "" ? var.vpc_id : data.aws_vpc.default.id

  # Inbound rules for HTTP and HTTPS
  ingress {
    description = "Allow HTTP traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound rules for all traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name      = "NATInstanceSecurityGroup"
    Terraform = "yes"
  }
}

# Launch the NAT instance and disable source/destination check
resource "aws_instance" "nat_instance" {
  ami           = "ami-024cf76afbc833688"
  instance_type = "t2.micro" # Choose the instance type suitable for a NAT instance
  #subnet_id              = var.subnet_id
  subnet_id = var.subnet_id != "" ? var.subnet_id : data.aws_subnets.available_subnets.ids[random_integer.random_index.result]

  key_name                    = aws_key_pair.deployer.key_name # Key pair for SSH access
  associate_public_ip_address = true


  vpc_security_group_ids = [aws_security_group.nat_instance_sg.id]

  # Disable source/destination check
  source_dest_check = false

  # User data script to enable NAT functionality (optional)
  user_data = <<-EOF
    #!/bin/bash
    sysctl -w net.ipv4.ip_forward=1
    iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
  EOF

  tags = {
    Name      = "NATInstance"
    Terraform = "yes"
  }
}

# Update the route table to use the NAT instance for internet-bound traffic
resource "aws_route_table" "public_route_table" {
  vpc_id = var.vpc_id != "" ? var.vpc_id : data.aws_vpc.default.id

  route {
    cidr_block           = "0.0.0.0/0"
    network_interface_id = aws_instance.nat_instance.primary_network_interface_id
  }


  tags = {
    Name      = "PublicRouteTable"
    Terraform = "yes"
  }
}

# Associate the route table with the public subnet
# resource "aws_route_table_association" "public_route_assoc" {
#   subnet_id      = var.subnet_id != "" ? var.subnet_id : data.aws_subnets.available_subnets.ids[random_integer.random_index.result]
#   route_table_id = aws_route_table.public_route_table.id
# }