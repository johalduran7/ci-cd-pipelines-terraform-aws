# Create the Internet Gateway
resource "aws_internet_gateway" "app_igw" {
  vpc_id = aws_vpc.app_vpc.id

  tags = {
    Name      = "app_internet_gateway"
    Terraform = "yes"
  }
}