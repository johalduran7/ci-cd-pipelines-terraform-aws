# This example is just to show how alb can invoke the lambda function.
# running the following, we get the response including the event (parameters translated from HTTP to json)
# http://alb-lambda-1750844358.us-east-1.elb.amazonaws.com/?parameter1=something&parameter2=somethingelse
# the dns alb can change of course.

resource "aws_iam_role" "lambda_role" {
  name = "lambda_ssm_role"
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

resource "aws_iam_policy" "ssm_policy" {
  name        = "LambdaSSMPolicy"
  description = "Policy to allow Lambda to access SSM parameters"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "kms:Decrypt"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:kms:us-east-1:948586925757:key/8bbcc45c-89af-4dd2-99ce-34a3eb3465a4" # Reference to KMS key
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_policy" {
  policy_arn = aws_iam_policy.ssm_policy.arn
  role       = aws_iam_role.lambda_role.name
}

resource "aws_lambda_function" "lambda_alb" {
  function_name = "lambda_alb"
  handler       = "modules/lambda/lambda_alb/lambda_function.lambda_handler" # Python handler
  runtime       = "python3.9"                                                # Specify the Python runtime version
  role          = aws_iam_role.lambda_role.arn
  timeout       = 10

  source_code_hash = filebase64sha256("modules/lambda/lambda_alb/lambda_function.zip")

  # Specify the S3 bucket and object if you upload the ZIP file to S3, or use the `filename` attribute for local deployment
  filename = "modules/lambda/lambda_alb/lambda_function.zip" # Path to your ZIP file
}


# Ensure that you have a ZIP file created with your Lambda function code

# zip modules/lambda/lambda_alb/lambda_function.zip modules/lambda/lambda_alb/lambda_function.py

# add permission to allow alb to invoke lambda
resource "aws_lambda_permission" "allow_alb_invoke" {
  statement_id  = "AllowExecutionFromALB"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_alb.arn
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.lambda_tg.arn
}
