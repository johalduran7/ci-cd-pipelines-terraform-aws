resource "aws_iam_role" "lambda_execution_role" {
  name = "lambda_layer_role"
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


# Allow Lambda to write to CW
resource "aws_iam_role_policy_attachment" "lambda_CW_execution_policy" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.lambda_layer.function_name}"  # Use the log group name of your Lambda function
  retention_in_days = 1
}

# Create the tree of the layer
# mkdir -p modules/lambda/lambda_layer/my-layer/python/lib/python3.9/site-packages

# Install the package
# pip install pycurl --target modules/lambda/lambda_layer/my-layer/python/lib/python3.9/site-packages
# pip install requests --target modules/lambda/lambda_layer/my-layer/python/lib/python3.9/site-packages


# pack the library
# cd modules/lambda/lambda_layer/my-layer/
# zip -r my-layer.zip python



# Add the layer
resource "aws_lambda_layer_version" "my_layer" {
  layer_name          = "my-lambda-layer"
  description         = "My custom Lambda layer"
  filename            = "modules/lambda/lambda_layer/my-layer/my-layer.zip" # Path to your zipped layer
  compatible_runtimes = ["python3.9"]  # Replace with your runtime
  source_code_hash = filebase64sha256("modules/lambda/lambda_layer/my-layer/my-layer.zip")

}


# using the same function as the other module. It doesn't really matter
resource "aws_lambda_function" "lambda_layer" {
  function_name = "lambda_layer"
  handler       = "lambda_function.lambda_handler" # Python handler
  runtime       = "python3.9"                                     # Specify the Python runtime version
  role          = aws_iam_role.lambda_execution_role.arn
  timeout       = 10
  source_code_hash = filebase64sha256("modules/lambda/lambda_layer/lambda_function.zip")

  # Specify the S3 bucket and object if you upload the ZIP file to S3, or use the `filename` attribute for local deployment
  filename = "modules/lambda/lambda_layer/lambda_function.zip" # Path to your ZIP file

  layers = [aws_lambda_layer_version.my_layer.arn] # Attach the layer

}

# Access the folder where you will zip the lambda function, otherwise, the structur of the zip file will add the entire path.
# cd modules/lambda/lambda_layer/
# zip lambda_function.zip lambda_function.py

