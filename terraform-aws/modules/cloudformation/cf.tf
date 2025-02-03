
resource "random_integer" "suffix" {
  min = 1000000
  max = 1999999
}

# Step 1: Create an S3 bucket
resource "aws_s3_bucket" "cf_templates" {
  bucket        = "my-cloudformation-templates-bucket-${random_integer.suffix.result}"
  force_destroy = true
  tags = {
    Environment = "Production"
    Terraform   = "true"
  }
}

# Step 2: Enable versioning using aws_s3_bucket_versioning
resource "aws_s3_bucket_versioning" "cf_templates_versioning" {
  bucket = aws_s3_bucket.cf_templates.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Step 3: Set the bucket ACL using aws_s3_bucket_acl
# resource "aws_s3_bucket_acl" "cf_templates_acl" {
#   bucket = aws_s3_bucket.cf_templates.id
#   acl    = "private"
# }

variable "template_filename" {
  default = "eb-java-scorekeep-xray-simplified.yaml"
}


# Step 4: Upload the CloudFormation template to the S3 bucket using aws_s3_object
resource "aws_s3_object" "cf_template" {
  bucket = aws_s3_bucket.cf_templates.bucket
  key    = "templates/${var.template_filename}"
  source = "${path.module}/templates/${var.template_filename}"          # Path to the local CloudFormation template
  etag   = filemd5("${path.module}/templates/${var.template_filename}") # Ensures upload happens only if file changes
}


# Step 4: Create a CloudFormation stack using the uploaded template
resource "aws_cloudformation_stack" "my_stack" {
  name         = "my-cloudformation-stack"
  template_url = "https://${aws_s3_bucket.cf_templates.bucket}.s3.amazonaws.com/${aws_s3_object.cf_template.key}"

  capabilities = ["CAPABILITY_NAMED_IAM"]

  # Tags (Optional)
  tags = {
    Environment = "Production"
    Owner       = "JohnDuran"
    Terraform   = "yes"
  }
}
