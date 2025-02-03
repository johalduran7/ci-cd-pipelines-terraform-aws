# create a parameter store name '/my-app/dev/db-url', standard, value 'dev.database.johnduran.com:3306'


resource "aws_ssm_parameter" "db_url" {
  name  = "/my-app/dev/db-url"
  type  = "String" # For standard parameters
  value = "dev.database.johnduran.com:3306"

  tags = {
    Environment = "dev"
    Terraform   = "yes"
  }
}


resource "aws_ssm_parameter" "db_password" {
  name  = "/my-app/dev/db-password"
  type  = "SecureString"    # Change type to SecureString for encryption
  value = "just_a_password" # Value you want to encrypt
  #key_id = "arn:aws:kms:us-east-1:948586925757:key/8bbcc45c-89af-4dd2-99ce-34a3eb3465a4" # Full ARN KMS key, this one I created it before but it'll expire in 7 days
  # creating a kms key costs so you also can leave it without encryption
  tags = {
    Environment = "dev"
    Terraform   = "yes "
  }
}

# using them in a lambda function
# create a lambda function called hello-world-ssm. I'm doing this in the module lambda
