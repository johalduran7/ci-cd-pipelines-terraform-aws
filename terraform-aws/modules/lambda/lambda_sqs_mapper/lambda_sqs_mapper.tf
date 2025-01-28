

resource "aws_iam_role" "lambda_execution_role" {
  name = "lambda_sqs_mapper_role"
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


resource "aws_iam_policy" "sqs_access_policy" {
  name        = "sqs_access_policy"
  description = "Policy to allow Lambda to receive messages from sqs"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.sqs_mapper_lambda.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "sqs_access_policy" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.sqs_access_policy.arn
}



# Allow Lambda to write to CW
resource "aws_iam_role_policy_attachment" "lambda_CW_execution_policy" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}



resource "aws_lambda_function" "lambda_sqs_mapper" {
  function_name = "lambda_sqs_mapper"
  handler       = "modules/lambda/lambda_sqs_mapper/lambda_function.lambda_handler" # Python handler
  runtime       = "python3.9"                                     # Specify the Python runtime version
  role          = aws_iam_role.lambda_execution_role.arn
  timeout       = 10
  source_code_hash = filebase64sha256("modules/lambda/lambda_sqs_mapper/lambda_function.zip")

  # Specify the S3 bucket and object if you upload the ZIP file to S3, or use the `filename` attribute for local deployment
  filename = "modules/lambda/lambda_sqs_mapper/lambda_function.zip" # Path to your ZIP file
}

resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.lambda_sqs_mapper.function_name}"  # Use the log group name of your Lambda function
  retention_in_days = 1
}



# Ensure that you have a ZIP file created with your Lambda function code

# zip modules/lambda/lambda_sqs_mapper/lambda_function.zip modules/lambda/lambda_sqs_mapper/lambda_function.py

# create SQS Queue for DLD

# Step 1: Create the SQS Queue
resource "aws_sqs_queue" "sqs_mapper_lambda" {
  #name = "DemoS3Notification"
  name       = "sqs_mapper_lambda"

  tags = {
    Name      = "sqs_mapper_lambda"
    Terraform = "yes"
  }
}

# Step 2: Create the SQS Queue Policy to allow S3 access
# resource "aws_sqs_queue_policy" "sqs_mapper_lambda_policy" {
#   queue_url = aws_sqs_queue.sqs_mapper_lambda.id

#   policy = <<EOF
# {
#   "Version": "2012-10-17",
#   "Id": "AllowLambdaPublish",
#   "Statement": [
#     {
#       "Effect": "Allow",
#       "Principal": {
#         "Service": "lambda.amazonaws.com"
#       },
#       "Action": "sqs:SendMessage",
#       "Resource": "${aws_sqs_queue.sqs_mapper_lambda.arn}",
#       "Condition": {
#         "ArnEquals": {
#           "aws:SourceArn": "${aws_lambda_function.lambda_sqs_mapper.arn}"
#         }
#       }
#     }
#   ]
# }

# EOF
# }

# Allow and add SQS as a trigger for lambda. Lambda Resource Based Policy
resource "aws_lambda_permission" "SQS_permission" {
  statement_id  = "AllowSQSInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_sqs_mapper.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_sqs_queue.sqs_mapper_lambda.arn
}

# Event Source Mapping for SQS. Remember this is for KDS, SQS, and DynamoDB Sreams
resource "aws_lambda_event_source_mapping" "sqs_event_source" {
  event_source_arn = aws_sqs_queue.sqs_mapper_lambda.arn
  function_name    = aws_lambda_function.lambda_sqs_mapper.arn
  batch_size       = 10
  enabled          = true
}