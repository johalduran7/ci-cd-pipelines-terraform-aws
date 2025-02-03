# Configuring a new vpc not to mess up with the default one. 
# I'm using an AWS module, not using mine.


module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "my-lambda-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a"]
  private_subnets = ["10.0.1.0/24"]
  public_subnets  = ["10.0.101.0/24"]

  enable_nat_gateway = true
  enable_vpn_gateway = false

  default_security_group_egress = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = "0.0.0.0/0"
    }
  ]


  tags = {
    Terraform   = "yes"
    Environment = "dev"
  }
}

output "private_route_table_ids" {
  value = module.vpc.private_route_table_ids
}

# resource "aws_route" "add_route_to_table" {
#   route_table_id         = module.vpc.private_route_table_ids[0] # Replace with your route table ID
#   destination_cidr_block = "0.0.0.0/0"           # Destination CIDR block for the route
#   gateway_id             = module.vpc.igw_id        # Replace with your internet gateway ID
# }

resource "aws_iam_role" "lambda_execution_role" {
  name = "lambda_vpc_execution_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Effect = "Allow"
        Sid    = ""
      },
    ]
  })
}

# Allow Lambda to write to CW
resource "aws_iam_role_policy_attachment" "lambda_CW_execution_policy" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_VPC_execution_policy" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}


resource "aws_lambda_function" "lambda_vpc" {
  function_name = "lambda_vpc"
  handler       = "modules/lambda/lambda_vpc/lambda_function.lambda_handler" # Python handler
  runtime       = "python3.9"                                                # Specify the Python runtime version
  role          = aws_iam_role.lambda_execution_role.arn
  timeout       = 5

  vpc_config {
    # Every subnet should be able to reach an EFS mount target in the same Availability Zone. Cross-AZ mounts are not permitted.
    subnet_ids         = module.vpc.private_subnets
    security_group_ids = [module.vpc.default_security_group_id]
  }

  source_code_hash = filebase64sha256("modules/lambda/lambda_vpc/lambda_function.zip")

  # Specify the S3 bucket and object if you upload the ZIP file to S3, or use the `filename` attribute for local deployment
  filename = "modules/lambda/lambda_vpc/lambda_function.zip" # Path to your ZIP file
}


# Ensure that you have a ZIP file created with your Lambda function code

# zip modules/lambda/lambda_vpc/lambda_function.zip modules/lambda/lambda_vpc/lambda_function.py


