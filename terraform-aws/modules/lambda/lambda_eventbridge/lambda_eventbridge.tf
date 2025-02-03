resource "aws_iam_role" "lambda_role" {
  name = "lambda_eventbridge_role"
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
  policy_arn = "arn:aws:iam::aws:policy/AmazonEventBridgeFullAccess"

}

resource "aws_iam_role_policy_attachment" "lambda_execution_policy_AWSLambdaBasic_forCW" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}



# using the same function as the other module. It doesn't really matter
resource "aws_lambda_function" "lambda_eventbridge" {
  function_name = "lambda_eventbridge"
  handler       = "modules/lambda/lambda_dlq/lambda_function.lambda_handler" # Python handler
  runtime       = "python3.9"                                                # Specify the Python runtime version
  role          = aws_iam_role.lambda_role.arn
  timeout       = 10
  #   dead_letter_config {
  #     target_arn="${aws_sqs_queue.dlq_queue.arn}"
  #   }
  source_code_hash = filebase64sha256("modules/lambda/lambda_dlq/lambda_function.zip")

  # Specify the S3 bucket and object if you upload the ZIP file to S3, or use the `filename` attribute for local deployment
  filename = "modules/lambda/lambda_dlq/lambda_function.zip" # Path to your ZIP file
}



module "eventbridge" {
  source = "terraform-aws-modules/eventbridge/aws"

  create_bus = false

  rules = {
    crons = {
      description         = "Trigger for a Lambda"
      schedule_expression = "cron(0/1 * * * ? *)"
    }
  }

  targets = {
    crons = [
      {
        name  = "lambda-loves-cron"
        arn   = "${aws_lambda_function.lambda_eventbridge.arn}"
        input = jsonencode({ "job" : "cron-by-rate" })
      }
    ]
  }
  tags = {
    Name      = "lambda_rule"
    Terraform = "yes"
  }
}

output "eventbridge_rules" {
  value = module.eventbridge.eventbridge_rule_arns
}


resource "aws_lambda_permission" "eventbridge_permission" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_eventbridge.function_name
  principal     = "events.amazonaws.com"
  source_arn    = module.eventbridge.eventbridge_rule_arns.crons
}

