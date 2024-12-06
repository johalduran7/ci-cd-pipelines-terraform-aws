# Enable this all to play with peering connection
# module "ec2" {
#   source              = "../ec2"

# }

# ### Peering connection between default and my DemoVPC

# # Data source to get the default VPC
# data "aws_vpc" "default" {
#   default = true
# }



# # Define the VPC Peering Connection
# resource "aws_vpc_peering_connection" "demo_peering_connection" {
#   # Name tag for the peering connection
#   tags = {
#     Name = "DemoPeeringConnection"
#     Terraform ="yes"
#   }

#   # Requester VPC (your DemoVPC)
#   vpc_id = aws_vpc.demo_vpc.id  # Replace with your actual DemoVPC ID

#   # Accepter VPC (default VPC)
#   peer_vpc_id = data.aws_vpc.default.id

#   # Optional: Specify the region (if it's not the same)
#   # peer_region = "us-west-2"  # Uncomment if needed
# }

# resource "aws_route" "route_to_default_vpc" {
#   route_table_id         = aws_route_table.public_route_table.id  # Replace with the route table ID of DemoVPC
#   destination_cidr_block = data.aws_vpc.default.cidr_block  # Use the CIDR block of the default VPC
#   vpc_peering_connection_id = aws_vpc_peering_connection.demo_peering_connection.id
# }

# resource "aws_route" "route_to_demo_vpc" {
#   route_table_id         = data.aws_vpc.default.main_route_table_id # Replace with the route table ID of DemoVPC
#   destination_cidr_block = aws_vpc.demo_vpc.cidr_block  # Use the CIDR block of the default VPC
#   vpc_peering_connection_id = aws_vpc_peering_connection.demo_peering_connection.id
# }