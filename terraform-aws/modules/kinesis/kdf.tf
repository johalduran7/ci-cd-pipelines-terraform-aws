# This part of the code is for the arquitecture: KDS->KDF->lambda->KDF->S3
# for every put-record in KDS, KDF processed it leveraging a lambda function and then, a file is created in S3 bucket.

# S3 Bucket for Processed Messages
resource "aws_s3_bucket" "processed_messages_bucket" {
  bucket = "processed-messages-bucket-${random_id.bucket_id.hex}"

  tags = {
    Name        = "Processed Messages Bucket"
    Environment = "dev"
    Terraform   = "yes"
  }

}

resource "random_id" "bucket_id" {
  byte_length = 4
}

# IAM Role for Lambda and Firehose
resource "aws_iam_role" "firehose_lambda_role" {
  name = "firehose-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = [
            "firehose.amazonaws.com",
            "lambda.amazonaws.com"
          ]
        }
      }
    ]
  })
}

resource "aws_iam_policy" "firehose_lambda_policy" {
  name = "firehose-lambda-policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = ["s3:*"],
        Resource = [
          aws_s3_bucket.processed_messages_bucket.arn,
          "${aws_s3_bucket.processed_messages_bucket.arn}/*"
        ]
      },
      {
        Effect   = "Allow",
        Action   = ["logs:*"],
        Resource = "*"
      },
      {
        Effect   = "Allow",
        Action   = ["lambda:InvokeFunction"], # Add this permission
        Resource = aws_lambda_function.transform_function.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "firehose_lambda_attach" {
  role       = aws_iam_role.firehose_lambda_role.name
  policy_arn = aws_iam_policy.firehose_lambda_policy.arn
}

# IAM Role for Kinesis Firehose to access Kinesis Data Stream
resource "aws_iam_role" "firehose_kinesis_role" {
  name = "firehose-kinesis-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "firehose.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# IAM Policy for Firehose to read from Kinesis Data Stream
resource "aws_iam_policy" "firehose_kinesis_policy" {
  name = "firehose-kinesis-policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "kinesis:DescribeStream",
          "kinesis:GetShardIterator",
          "kinesis:GetRecords",
          "kinesis:ListShards"
        ],
        Resource = aws_kinesis_stream.kds_stream.arn
      }
    ]
  })
}

# Attach Policy to Role
resource "aws_iam_role_policy_attachment" "firehose_kinesis_policy_attach" {
  role       = aws_iam_role.firehose_kinesis_role.name
  policy_arn = aws_iam_policy.firehose_kinesis_policy.arn
}


# Lambda Function for Message Transformation
# to zip: $ zip modules/kinesis/lambda_transform.zip modules/kinesis/lambda_transform.py
resource "aws_lambda_function" "transform_function" {
  filename         = "modules/kinesis/lambda_transform.zip" # Replace with actual Lambda deployment package
  function_name    = "kinesis-firehose-transform"
  role             = aws_iam_role.firehose_lambda_role.arn
  handler          = "modules/kinesis/lambda_transform.lambda_handler"
  runtime          = "python3.9"
  timeout          = 60
  source_code_hash = filebase64sha256("modules/kinesis/lambda_transform.zip")

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.processed_messages_bucket.bucket
    }
  }
}



# Kinesis Data Firehose Delivery Stream
resource "aws_kinesis_firehose_delivery_stream" "firehose_stream" {
  name        = "kinesis-firehose-stream"
  destination = "extended_s3"


  # Define Kinesis Data Stream as the source
  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.kds_stream.arn
    role_arn           = aws_iam_role.firehose_kinesis_role.arn
  }



  # S3 Configuration for Firehose
  extended_s3_configuration {
    role_arn            = aws_iam_role.firehose_lambda_role.arn
    bucket_arn          = aws_s3_bucket.processed_messages_bucket.arn
    buffering_size      = 1
    buffering_interval  = 60 # whatever data is in firehose, will be flushed to S3 after this time.
    compression_format  = "UNCOMPRESSED"
    prefix              = ""
    error_output_prefix = "failed/"




    # Lambda Processor configuration
    processing_configuration {
      enabled = true
      processors {
        type = "Lambda"

        parameters {
          parameter_name  = "LambdaArn"
          parameter_value = aws_lambda_function.transform_function.arn
        }
      }
    }
  }

  tags = {
    Environment = "dev"
    Team        = "data-team"
    Terraform   = "yes"
  }
}

# Outputs


output "firehose_name" {
  value = aws_kinesis_firehose_delivery_stream.firehose_stream.name
}

output "s3_bucket_name" {
  value = aws_s3_bucket.processed_messages_bucket.bucket
}
