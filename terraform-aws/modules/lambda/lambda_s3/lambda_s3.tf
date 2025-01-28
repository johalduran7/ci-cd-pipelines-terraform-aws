# every time an object is created on S3, the lambda function is triggered


variable "bucket_name" {
  default = "demo-john-lambda-v1"
}



resource "aws_s3_bucket" "bucket" {
  bucket = var.bucket_name

  force_destroy = true
}

# set the following to false so you can access the S3 website from the internet
resource "aws_s3_bucket_public_access_block" "bucket" {
  bucket = aws_s3_bucket.bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_ownership_controls" "bucket" {
  bucket = aws_s3_bucket.bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_policy" "policy" {
  bucket = aws_s3_bucket.bucket.id
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": [
                "s3:GetObject"
            ],
            "Resource": [
                "arn:aws:s3:::${aws_s3_bucket.bucket.id}/*"
            ]
        }
    ]
}
EOF
}

# create lambda

resource "aws_iam_role" "lambda_role" {
  name = "lambda_s3_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Effect = "Allow"
        Sid    = ""
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_execution_policy_invoke" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  
}

resource "aws_iam_role_policy_attachment" "lambda_execution_policy_AWSLambdaBasic_forCW" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}



# using the same function as the other module. It doesn't really matter
resource "aws_lambda_function" "lambda_s3" {
  function_name = "lambda_s3"
  handler       = "modules/lambda/lambda_s3/lambda_function.lambda_handler" # Python handler
  runtime       = "python3.9"                                     # Specify the Python runtime version
  role          = aws_iam_role.lambda_role.arn
  timeout       = 10
#   dead_letter_config {
#     target_arn="${aws_sqs_queue.dlq_queue.arn}"
#   }
  source_code_hash = filebase64sha256("modules/lambda/lambda_s3/lambda_function.zip")

  # Specify the S3 bucket and object if you upload the ZIP file to S3, or use the `filename` attribute for local deployment
  filename = "modules/lambda/lambda_s3/lambda_function.zip" # Path to your ZIP file
}

# $ zip modules/lambda/lambda_s3/lambda_function.zip modules/lambda/lambda_s3/lambda_function.py


resource "aws_lambda_permission" "allow_s3_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_s3.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.bucket.arn
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.lambda_s3.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_s3_bucket]
}