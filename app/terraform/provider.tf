terraform {
  cloud {

    organization = "john-organization"
    workspaces {
      name = "dev"
      #tags =  true # it allows to select the workspace according to TF_WORKSPACE
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