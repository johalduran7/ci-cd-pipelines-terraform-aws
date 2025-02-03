#create a PublicSubnetA tied to AZ a and assign 10.0.0.0/24, create another one called    PublicSubnetB and assign CIDR 10.0.1.0/24. Create a private Subnet called PrivateSubnetA with CIDR 10.0.16.0/20, and another one called PrivateSubnetB with CIDR 10.0.32.0/20. Tie them all to my DemoVPC


# Public Subnet A tied to AZ 'a'
resource "aws_subnet" "public_subnet_a" {
  vpc_id                  = aws_vpc.app_vpc.id
  cidr_block              = var.public_subnet_a_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = var.public_subnet_a_name
  }
}

# Public Subnet B tied to AZ 'b'
resource "aws_subnet" "public_subnet_b" {
  vpc_id                  = aws_vpc.app_vpc.id
  cidr_block              = var.public_subnet_b_cidr
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true

  tags = {
    Name = var.public_subnet_b_name
  }
}

# Private Subnet A tied to AZ 'a'
resource "aws_subnet" "private_subnet_a" {
  vpc_id            = aws_vpc.app_vpc.id
  cidr_block        = var.private_subnet_a_cidr
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = var.private_subnet_a_name
  }
}

# Private Subnet B tied to AZ 'b'
resource "aws_subnet" "private_subnet_b" {
  vpc_id            = aws_vpc.app_vpc.id
  cidr_block        = var.private_subnet_b_cidr
  availability_zone = "${var.aws_region}b"

  tags = {
    Name = var.private_subnet_b_name
  }
}

locals {
  public_subnets = tolist([
    aws_subnet.public_subnet_a.id,
    aws_subnet.public_subnet_b.id
  ])
}

locals {
  private_subnets = tolist([
    aws_subnet.private_subnet_a.id,
    aws_subnet.private_subnet_b.id
  ])
}

