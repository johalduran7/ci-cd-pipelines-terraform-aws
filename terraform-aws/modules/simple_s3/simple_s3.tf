
variable "bucket_name" {
  default = "demo-john-general-v1"
}



resource "aws_s3_bucket" "bucket" {
  bucket = var.bucket_name

  force_destroy = true
}


resource "aws_s3_bucket_website_configuration" "bucket" {
  bucket = aws_s3_bucket.bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}


resource "aws_s3_object" "webapp" {

  key          = "index.html"
  bucket       = aws_s3_bucket.bucket.id
  content      = file("${path.module}/assets/index.html")
  content_type = "text/html"
}

output "endpoint" {
  value = aws_s3_bucket_website_configuration.bucket.website_endpoint
}
output "bucket_regional_domain_name" {
  value = aws_s3_bucket.bucket.bucket_regional_domain_name
}


output "bucket_name" {
  value = var.bucket_name
}

output "bucket_id" {
  value = aws_s3_bucket.bucket.id
}

output "bucket_arn" {
  value = aws_s3_bucket.bucket.arn
}
