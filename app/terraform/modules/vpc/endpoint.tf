
# Create the S3 Gateway Endpoint
resource "aws_vpc_endpoint" "demo_endpoint" {
  vpc_id          = aws_vpc.app_vpc.id
  service_name    = "com.amazonaws.${var.aws_region}.s3"     # Dynamically getting the region
  route_table_ids = [aws_route_table.private_route_table.id] # Adding the route table ID for the endpoint

  policy = <<EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": "*",
        "Action": "s3:*",
        "Resource": "*"
      }
    ]
  }
  EOF

  tags = {
    Name      = "AppEndpoint"
    Terraform = "yes"
  }
}

