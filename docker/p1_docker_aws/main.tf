resource "aws_ecr_repository" "p1-docker-app-local-2" {
  name                 = "p1-docker-app-local-2"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}
