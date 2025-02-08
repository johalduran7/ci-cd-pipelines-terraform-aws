resource "aws_ecr_repository" "nodejs-app" {
  name                 = "${var.env}-nodejs-app"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ssm_parameter" "ecr_repository" {
  name  = "/app/${var.env}/ecr_repository_name"
  type  = "String" # For standard parameters
  value = aws_ecr_repository.nodejs-app.name

  tags = {
    Env       = "${var.env}"
    Terraform = "yes"
  }
}

resource "aws_ecr_lifecycle_policy" "ecr_policy" {
  repository = aws_ecr_repository.nodejs-app.name

  policy = <<EOF
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Keep only the latest two images",
      "selection": {
        "tagStatus": "any",
        "countType": "imageCountMoreThan",
        "countNumber": 2
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
EOF
}
