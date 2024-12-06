# Create a Network ACL
resource "aws_network_acl" "demo_nacl" {
  vpc_id = aws_vpc.demo_vpc.id # Replace with your actual VPC ID or data source for DemoVPC
  tags = {
    Name      = "DemoNACL"
    Terraform = "true"

  }
}

# Inbound rule to allow traffic on port 80 (HTTP)
resource "aws_network_acl_rule" "allow_http_inbound" {
  network_acl_id = aws_network_acl.demo_nacl.id
  rule_number    = 100   # Specify a unique rule number
  egress         = false # This is an inbound rule
  protocol       = "tcp"
  from_port      = 80
  to_port        = 80
  cidr_block     = "0.0.0.0/0" # Allow from any IP address
  rule_action    = "allow"     # Action to allow traffic
}

# Outbound rule to allow all traffic (optional)
resource "aws_network_acl_rule" "allow_all_outbound" {
  network_acl_id = aws_network_acl.demo_nacl.id
  rule_number    = 100  # Specify a unique rule number
  egress         = true # This is an outbound rule
  protocol       = "-1" # -1 allows all protocols
  from_port      = 0
  to_port        = 0
  cidr_block     = "0.0.0.0/0" # Allow to any IP address
  rule_action    = "allow"     # Action to allow traffic
}


# locals {
#   subnet_ids = [
#     aws_subnet.public_subnet_a.id,
#     aws_subnet.private_subnet_a.id,
#     aws_subnet.public_subnet_b.id,
#     aws_subnet.private_subnet_b.id
#   ]
# }

# # Associate the NACL with multiple subnets
# resource "aws_network_acl_association" "demo_nacl_association" {
#   for_each       = toset(local.subnet_ids)
#   network_acl_id = aws_network_acl.demo_nacl.id
#   subnet_id      = each.key
# }