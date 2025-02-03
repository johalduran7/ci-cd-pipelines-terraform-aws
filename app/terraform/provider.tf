terraform {
  cloud {

    organization = "john-organization"
    workspaces {
      name = "app-portfolio"
    }
  }
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.84.0"
    }
  }
}