# Create the Internet Gateway
resource "aws_internet_gateway" "demo_igw" {
  vpc_id = aws_vpc.demo_vpc.id

  tags = {
    Name      = "demo_internet_gateway"
    Terraform = "yes"
  }
}