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
      "description": "Expire untagged images",
      "selection": {
        "tagStatus": "untagged",
        "countType": "sinceImagePushed",
        "countUnit": "days",
        "countNumber": 1
      },
      "action": {
        "type": "expire"
      }
    },
    {
      "rulePriority": 2,
      "description": "Keep only the latest two tagged images",
      "selection": {
        "tagStatus": "tagged",
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
