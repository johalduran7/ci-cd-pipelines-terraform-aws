# Asynchronous:  aws lambda invoke --function-name lambda_dlq --cli-binary-format raw-in-base64-out --payload '{"key1": "value1", "key2": "value2", "key3": "value3" }' --invocation-type Event response.json
# Synchronous:  aws lambda invoke --function-name lambda_dlq --cli-binary-format raw-in-base64-out --payload '{"key1": "value1", "key2": "value2", "key3": "value3" }' response.json



resource "aws_iam_role" "lambda_role" {
  name = "lambda_dlq_role"
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

resource "aws_iam_role_policy_attachment" "lambda_execution_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"

}

resource "aws_lambda_function" "lambda_dlq" {
  function_name = "lambda_dlq"
  handler       = "modules/lambda/lambda_dlq/lambda_function.lambda_handler" # Python handler
  runtime       = "python3.9"                                                # Specify the Python runtime version
  role          = aws_iam_role.lambda_role.arn
  timeout       = 10
  dead_letter_config {
    target_arn = aws_sqs_queue.dlq_queue.arn
  }
  source_code_hash = filebase64sha256("modules/lambda/lambda_dlq/lambda_function.zip")

  # Specify the S3 bucket and object if you upload the ZIP file to S3, or use the `filename` attribute for local deployment
  filename = "modules/lambda/lambda_dlq/lambda_function.zip" # Path to your ZIP file
}


# Ensure that you have a ZIP file created with your Lambda function code

# zip modules/lambda/lambda_dlq/lambda_function.zip modules/lambda/lambda_dlq/lambda_function.py


# create SQS Queue for DLD

# Step 1: Create the SQS Queue
resource "aws_sqs_queue" "dlq_queue" {
  #name = "DemoS3Notification"
  name = "dlq_sqs_lambda"

  tags = {
    Name      = "DLQ_SQS_LAMBDA"
    Terraform = "yes"
  }
}

# Step 2: Create the SQS Queue Policy to allow S3 access
resource "aws_sqs_queue_policy" "lambda_dlq_queue_policy" {
  queue_url = aws_sqs_queue.dlq_queue.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Id": "AllowLambdaPublish",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sqs:SendMessage",
      "Resource": "${aws_sqs_queue.dlq_queue.arn}",
      "Condition": {
        "ArnEquals": {
          "aws:SourceArn": "${aws_lambda_function.lambda_dlq.arn}"
        }
      }
    }
  ]
}

EOF
}