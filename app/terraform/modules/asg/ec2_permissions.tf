# IAM Role for EC2 to Access CloudWatch
resource "aws_iam_role" "ec2_execution_role" {
  name = "ec2-app-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for Logging Permissions
#note: "ec2:DescribeTags" this one is needed for CW Agent to run
resource "aws_iam_policy" "cloudwatch_log_policy_agent" {
  name = "cloudwatch-log-policy-agent"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups",
          "logs:PutLogEvents",
          "ec2:DescribeTags",
          "cloudwatch:PutMetricData"
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}


# IAM Policy for SSM Access
resource "aws_iam_role_policy" "ssm_read_policy" {
  name = "ssm-read-policy"
  role = aws_iam_role.ec2_app_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:ssm:us-east-1:948586925757:parameter/app/dev/app_version"
      }
    ]
  })
}

# Attach IAM Policy to Role
resource "aws_iam_role_policy_attachment" "attach_policy_cw_agent" {
  role       = aws_iam_role.ec2_execution_role.name
  policy_arn = aws_iam_policy.cloudwatch_log_policy_agent.arn
}

resource "aws_iam_role_policy_attachment" "attach_policy_ecr" {
  role       = aws_iam_role.ec2_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilderECRContainerBuilds"
}

resource "aws_iam_role_policy_attachment" "attach_policy_read_ssm" {
  role       = aws_iam_role.ec2_execution_role.name
  policy_arn = aws_iam_policy.ssm_read_policy.arn
}


# EC2 Instance Profile for IAM Role
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2-instance-profile"
  role = aws_iam_role.ec2_execution_role.name
}

