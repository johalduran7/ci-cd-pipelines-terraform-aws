# this module is called from cw/cw_metrics_alarm.tf
variable "instance_id" {
  type    = string
  default = ""
}

variable "log_group" {
  type    = string
  default = ""
}
variable "log_stream" {
  type    = string
  default = ""
}

# IAM Role for Lambda and Firehose
resource "aws_iam_role" "lambda_for_cloudwatch_role" {
  name = "lambda-for-cloudwatch-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = [
            "lambda.amazonaws.com"
          ]
        }
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_for_cloudwatch_role_policy" {
  name = "terminate-ec2-policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ec2:TerminateInstances",
          "ec2:DescribeInstances" # Optional: Useful for logging or debugging
        ],
        Resource = "arn:aws:ec2:*:*:instance/*" # Allows termination of all EC2 instances in the account
      },
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:DescribeLogStreams",
          "logs:CreateLogStream",
          "logs:PutLogEvents" # Allows Lambda to write to CloudWatch logs
        ],
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}


resource "aws_iam_role_policy_attachment" "cloudwatch_lambda_attach" {
  role       = aws_iam_role.lambda_for_cloudwatch_role.name
  policy_arn = aws_iam_policy.lambda_for_cloudwatch_role_policy.arn
}


# Lambda Function for Message Transformation
# to zip: $ zip modules/lambda/lambda_cw_alarm/lambda_cw_terminate.zip modules/lambda/lambda_cw_alarm/lambda_cw_terminate.py
resource "aws_lambda_function" "cloudwatch_terminate_ec2_function" {
  filename         = "modules/lambda/lambda_cw_alarm/lambda_cw_terminate.zip" # Replace with actual Lambda deployment package
  function_name    = "cloudwatch-terminate-ec2-function"
  role             = aws_iam_role.lambda_for_cloudwatch_role.arn
  handler          = "modules/lambda/lambda_cw_alarm/lambda_cw_terminate.lambda_handler"
  runtime          = "python3.9"
  timeout          = 60
  source_code_hash = filebase64sha256("modules/lambda/lambda_cw_alarm/lambda_cw_terminate.zip")

  environment {
    variables = {
      instance_id = var.instance_id
      log_group   = var.log_group
      log_stream  = var.log_stream
    }
  }
}

output "lambda_arn" {
  value = aws_lambda_function.cloudwatch_terminate_ec2_function.arn
}

output "lambda_function_name" {
  value = aws_lambda_function.cloudwatch_terminate_ec2_function.function_name
}
