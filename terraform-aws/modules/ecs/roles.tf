resource "aws_iam_role" "ecs_execution_role" {
  name = "ecs_execution_role"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : "sts:AssumeRole",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
  tags = {
    Terraform = "yes"
    aws_saa   = "yes"
  }
}

resource "aws_iam_policy_attachment" "ecs_execution_role_policy_attachment" {
  name       = "ecs_execution_role_policy_attachment"
  roles      = [aws_iam_role.ecs_execution_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# this is needed to run aws ecs execution-command
resource "aws_iam_policy_attachment" "ecs_execution_role_ssm_attachment" {
  name       = "ecs_execution_role_ssm_attachment"
  roles      = [aws_iam_role.ecs_execution_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}



resource "aws_iam_role" "ecs_task_role" {
  name = "ecs_task_role"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : "sts:AssumeRole",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# Example policy (adjust based on your task's needs)
resource "aws_iam_policy" "ecs_task_policy" {
  name = "ecs_task_policy"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : [
          "s3:GetObject",
          "s3:PutObject"
        ],
        "Effect" : "Allow",
        "Resource" : "arn:aws:s3:::your-bucket-name/*"
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "ecs_task_role_policy_attachment" {
  name       = "ecs_task_role_policy_attachment_S3"
  roles      = [aws_iam_role.ecs_task_role.name]
  policy_arn = aws_iam_policy.ecs_task_policy.arn
}

# policy for X-Ray
resource "aws_iam_policy" "xray_permissions" {
  name        = "XRayTaskPermissions"
  description = "Permissions for ECS tasks to send X-Ray traces"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "ecs_task_role_policy_attachment_xray" {
  name       = "ecs_task_role_policy_attachment_xray"
  roles      = [aws_iam_role.ecs_task_role.name]
  policy_arn = aws_iam_policy.xray_permissions.arn
}

# policy for  execute command so I can log into the tasks
resource "aws_iam_policy" "execute_command_policy" {
  name        = "ExecuteCommandPermissions"
  description = "Permissions for ECS tasks to use ExecuteCommand"
  policy      = jsonencode({
      "Version": "2012-10-17",
      "Statement": [
          {
              "Effect": "Allow",
              "Action": [
                  "ssmmessages:CreateControlChannel",
                  "ssmmessages:CreateDataChannel",
                  "ssmmessages:OpenControlChannel",
                  "ssmmessages:OpenDataChannel"
              ],
              "Resource": "*"
          },
          {
              "Effect": "Allow",
              "Action": [
                  "logs:DescribeLogGroups"
              ],
              "Resource": "*"
          },
          {
              "Effect": "Allow",
              "Action": [
                  "logs:DescribeLogGroups",
                  "logs:CreateLogStream",
                  "logs:DescribeLogStreams",
                  "logs:PutLogEvents"
              ],
              "Resource": aws_cloudwatch_log_group.ecs_cluster_cloudwatch.arn
          }
      ]
  })
}


resource "aws_iam_policy_attachment" "ecs_task_role_execute_command_attachment" {
  name       = "ecs_task_role_execute_command_attachment"
  roles      = [aws_iam_role.ecs_task_role.name]
  policy_arn = aws_iam_policy.execute_command_policy.arn
}


# EC2 roles

resource "aws_iam_role" "ecs_instance_role" {
  name = "ecsInstanceRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}


resource "aws_iam_role_policy_attachment" "ecs_instance_policy" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "ecs_instance_policy"
  role = aws_iam_role.ecs_instance_role.name
}
