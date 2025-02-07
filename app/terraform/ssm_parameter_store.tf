resource "aws_ssm_parameter" "infrastructure_version" {
  name  = "/app/${var.env}/infrastructure_version"
  type  = "String" # For standard parameters
  value = var.infrastructure_version

  tags = {
    Env       = "${var.env}"
    Terraform = "yes"
  }
}

resource "aws_ssm_parameter" "app_version" {
  name  = "/app/${var.env}/app_version"
  type  = "String" # For standard parameters
  value = var.app_version

  lifecycle {
    ignore_changes = [value] # it prevents the value from being updated after the first run of Terraform.
  }


  tags = {
    Env       = "${var.env}"
    Terraform = "yes"
  }
}

resource "aws_ssm_parameter" "running_time_user_data" {
  name  = "/app/${var.env}/running_time_user_data"
  type  = "String" # For standard parameters
  value = "no ec2 has run yet"

  lifecycle {
    ignore_changes = [value] # it prevents the value from being updated after the first run of Terraform.
  }


  tags = {
    Env       = "${var.env}"
    Terraform = "yes"
  }
}