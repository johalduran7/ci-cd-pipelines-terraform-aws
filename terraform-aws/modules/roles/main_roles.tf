# designed mainly for ec2 roles
# just add statements to the policy
#how to use:
# module "ec2_role" {
#   source= "../roles"

# }



# Define an IAM Role
resource "aws_iam_role" "ec2_role" {
  name = "ec2-custom-iam-role"

  # Define the trust relationship (allow EC2 to assume the role)
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com" # Replace with another service or AWS account if needed
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attach a policy to the role (allow S3 access)
resource "aws_iam_role_policy" "ec2_role_policy" {
  name = "ec2-role-policy"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject"
        ],
        Resource = "*"
      },
      {
        "Action" : "s3:ListAllMyBuckets",
        "Effect" : "Allow",
        "Resource" : "*"
      }
    ],
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "ssm:DescribeAssociation",
          "ssm:GetDeployablePatchSnapshotForInstance",
          "ssm:GetDocument",
          "ssm:DescribeDocument",
          "ssm:GetManifest",
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:ListAssociations",
          "ssm:ListInstanceAssociations",
          "ssm:PutInventory",
          "ssm:PutComplianceItems",
          "ssm:PutConfigurePackageResult",
          "ssm:UpdateAssociationStatus",
          "ssm:UpdateInstanceAssociationStatus",
          "ssm:UpdateInstanceInformation"
        ],
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ],
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "ec2messages:AcknowledgeMessage",
          "ec2messages:DeleteMessage",
          "ec2messages:FailMessage",
          "ec2messages:GetEndpoint",
          "ec2messages:GetMessages",
          "ec2messages:SendReply"
        ],
        "Resource" : "*"
      }
    ]
  })
}

# Optionally, attach the role to an instance profile (for EC2 usage)
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2-instance-profile"
  role = aws_iam_role.ec2_role.name
}

# Output the Role ARN
output "role_arn" {
  value = aws_iam_role.ec2_role.arn
}

# Output the Role ARN
output "aws_iam_instance_profile_name" {
  value = aws_iam_instance_profile.ec2_instance_profile.name
}