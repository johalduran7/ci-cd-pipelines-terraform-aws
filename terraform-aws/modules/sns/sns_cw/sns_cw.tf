data "aws_caller_identity" "current" {}
data "aws_region" "current" {}


# Create an SNS Topic
resource "aws_sns_topic" "cloudwatch_alarm_notifications" {
  name = "cloudwatch_alarm_notifications"
}

# SNS Topic Policy to Allow CW notifications
resource "aws_sns_topic_policy" "cloudwatch_alarm_notifications_policy" {
  arn = aws_sns_topic.cloudwatch_alarm_notifications.arn

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        },
        Action    = "SNS:Publish",
        Resource  = aws_sns_topic.cloudwatch_alarm_notifications.arn,
        Condition = {
          ArnLike = {
            "aws:SourceArn" = "arn:aws:cloudwatch:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:alarm:*"
          }
        }
      }
    ]
  })
}


# Create an SNS Subscription for your email
resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.cloudwatch_alarm_notifications.arn
  protocol  = "email"
  endpoint  = "johalduran@gmail.com" # Replace with your email address
}


output "sns_topic_arn" {
  value = aws_sns_topic.cloudwatch_alarm_notifications.arn
}
