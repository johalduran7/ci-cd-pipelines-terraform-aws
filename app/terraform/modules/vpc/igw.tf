# Create the Internet Gateway
resource "aws_internet_gateway" "app_igw" {
  vpc_id = aws_vpc.app_vpc.id

  tags = {
    Name      = "${var.env}-app_igw"
    Terraform = "yes"
  }
}