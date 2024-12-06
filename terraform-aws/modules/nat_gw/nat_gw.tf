# HOW to use it
# module "nat_gw" {
#   source="./modules/nat_gw"
#   subnet_id= module.vpc.public_subnet_a_id # optional, if not provided it will use the AZ a in the current region
#   private_route_table=module.vpc.private_route_table # Madatory
# }


variable "subnet_id" {
  type        = string
  default     = ""
  description = "description"
}

variable "private_route_table" {
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


# Allocate an Elastic IP for the NAT Gateway
resource "aws_eip" "nat_eip" {

  tags = {
    Name      = "DemoNATEIP"
    Terraform = "yes"
  }
}

# Create the NAT Gateway
resource "aws_nat_gateway" "demo_nat_gateway" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = var.subnet_id != "" ? var.subnet_id : data.aws_subnets.available_subnets.ids[random_integer.random_index.result]

  tags = {
    Name      = "DemoNATG"
    Terraform = "yes"
  }
}




# Add a route to the route table for the NAT Gateway
resource "aws_route" "nat_gateway_route" {
  route_table_id         = var.private_route_table
  destination_cidr_block = "0.0.0.0/0" # Route all traffic to the NAT Gateway
  nat_gateway_id         = aws_nat_gateway.demo_nat_gateway.id
}

