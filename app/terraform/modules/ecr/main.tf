resource "aws_ecr_repository" "nodejs-app" {
  name                 = "nodejs-app"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ssm_parameter" "ecr_repository" {
  name  = "/app/dev/ecr_repository_name"
  type  = "String" # For standard parameters
  value = aws_ecr_repository.nodejs-app.name

  tags = {
    Environment = "dev"
    Terraform   = "yes"
  }
}