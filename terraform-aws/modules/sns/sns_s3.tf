# module sns {
#   source= "./modules/sns"
#   bucket_id= "" # optional
# }

#it notifies me via email every time an object is uploaded to my bucker

variable "bucket_id" {
  type    = string
  default = "virtual-machine-ubuntu"
}

variable "bucket_arn" {
  type    = string
  default = "arn:aws:s3:::virtual-machine-ubuntu"
}



# Create an SNS Topic
resource "aws_sns_topic" "s3_event_notifications" {
  name = "s3-event-notifications"
  #policy = data.aws_iam_policy_document.topic.json
}

# SNS Topic Policy to Allow S3 Bucket
resource "aws_sns_topic_policy" "s3_event_notifications_policy" {
  arn = aws_sns_topic.s3_event_notifications.arn
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "s3.amazonaws.com"
        },
        Action   = "SNS:Publish",
        Resource = aws_sns_topic.s3_event_notifications.arn,
        Condition = {
          ArnLike = {
            "aws:SourceArn" = var.bucket_arn
          }
        }
      }
    ]
  })
}

# Create an SNS Subscription for your email
resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.s3_event_notifications.arn
  protocol  = "email"
  endpoint  = "johalduran@gmail.com" # Replace with your email address
}

# Enable event notifications for the S3 bucket
resource "aws_s3_bucket_notification" "s3_event_notification" {
  bucket = var.bucket_id

  # Trigger notification on object creation events
  topic {
    events    = ["s3:ObjectCreated:*"]
    topic_arn = aws_sns_topic.s3_event_notifications.arn
  }
  depends_on = [aws_sns_topic_policy.s3_event_notifications_policy] # the SNS topic policy has to be created before this one so I have to add this explicit dependency
}

output "sns_topic_arn" {
  value = aws_sns_topic.s3_event_notifications.arn
}
