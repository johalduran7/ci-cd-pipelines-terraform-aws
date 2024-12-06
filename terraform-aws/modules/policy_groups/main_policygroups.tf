
# Define an IAM Policy
resource "aws_iam_policy" "s3_list_buckets_policy" {
  name        = "S3ListBucketsPolicy_test"
  description = "IAM policy to allow listing of S3 buckets for AWS Solutions architect course"

  # Define the policy using JSON format
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "s3:ListAllMyBuckets"
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
  # Add tags to the policy
  tags = {
    "Terraform" = "yes"
    "AWS_SAA"   = "yes"
  }
}

# Optionally, create a user and attach the policy to the user
resource "aws_iam_user" "user1s" {
  name = "john_saa_test"
  # Add tags to the policy
  tags = {
    "Terraform" = "yes"
    "AWS_SAA"   = "yes"
  }
}

# Attach the policy to the user
resource "aws_iam_user_policy_attachment" "user_policy_attachment" {
  user       = aws_iam_user.user1s.name
  policy_arn = aws_iam_policy.s3_list_buckets_policy.arn

}

# Create an IAM group
resource "aws_iam_group" "example_group" {
  name = "example-group"

}

# Attach the policy to the group
resource "aws_iam_group_policy_attachment" "group_policy_attachment" {
  group      = aws_iam_group.example_group.name
  policy_arn = aws_iam_policy.s3_list_buckets_policy.arn

}

# Add the user to the group
resource "aws_iam_user_group_membership" "user_group_membership" {
  user = aws_iam_user.user1s.name
  groups = [
    aws_iam_group.example_group.name
  ]

}

resource "aws_iam_account_password_policy" "strict" {
  minimum_password_length        = 8
  require_lowercase_characters   = true
  require_numbers                = true
  require_uppercase_characters   = true
  require_symbols                = true
  allow_users_to_change_password = true

}