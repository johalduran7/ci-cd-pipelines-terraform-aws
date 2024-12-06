
variable "bucket_name" {
  default = "demo-john-general-v1"
}



resource "aws_s3_bucket" "bucket" {
  bucket = var.bucket_name

  force_destroy = true
}

# set the following to false so you can access the S3 website from the internet
resource "aws_s3_bucket_public_access_block" "bucket" {
  bucket = aws_s3_bucket.bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_ownership_controls" "bucket" {
  bucket = aws_s3_bucket.bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_website_configuration" "bucket" {
  bucket = aws_s3_bucket.bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

resource "aws_s3_bucket_acl" "bucket" {
  depends_on = [
    aws_s3_bucket_public_access_block.bucket,
    aws_s3_bucket_ownership_controls.bucket,
  ]
  bucket = aws_s3_bucket.bucket.id

  acl = "public-read"
}

resource "aws_s3_bucket_policy" "policy" {
  bucket = aws_s3_bucket.bucket.id
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": [
                "s3:GetObject"
            ],
            "Resource": [
                "arn:aws:s3:::${aws_s3_bucket.bucket.id}/*"
            ]
        }
    ]
}
EOF
}

resource "aws_s3_object" "webapp" {
  acl          = "public-read"
  key          = "index.html"
  bucket       = aws_s3_bucket.bucket.id
  content      = file("${path.module}/assets/index.html")
  content_type = "text/html"
}

resource "aws_s3_object" "page2" {
  acl          = "public-read"
  key          = "page2.html"
  bucket       = aws_s3_bucket.bucket.id
  content      = file("${path.module}/assets/page2.html")
  content_type = "text/html"
}

resource "aws_s3_object" "page3" {
  acl          = "public-read"
  key          = "page3.html"
  bucket       = aws_s3_bucket.bucket.id
  content      = file("${path.module}/assets/page3.html")
  content_type = "text/html"
}

resource "aws_s3_object" "bike" {
  acl          = "public-read"
  bucket       = aws_s3_bucket.bucket.id
  key          = "bike.jpeg"
  source       = "${path.module}/assets/bike.jpeg"
  content_type = "image/jpeg"
}


output "endpoint" {
  value = aws_s3_bucket_website_configuration.bucket.website_endpoint
}
output "bucket_regional_domain_name" {
  value = aws_s3_bucket.bucket.bucket_regional_domain_name
}


output "bucket_name" {
  value = var.bucket_name
}

output "bucket_id" {
  value = aws_s3_bucket.bucket.id
}

output "bucket_arn" {
  value = aws_s3_bucket.bucket.arn
}

## create SQS Queue

# # Step 1: Create the SQS Queue
# resource "aws_sqs_queue" "s3_notification_queue" {
#   name = "DemoS3Notification"
# }

# # Step 2: Create the SQS Queue Policy to allow S3 access
# resource "aws_sqs_queue_policy" "s3_notification_queue_policy" {
#   queue_url = aws_sqs_queue.s3_notification_queue.id

#   policy = <<EOF
# {
#   "Version": "2012-10-17",
#   "Id": "SQSQueuePolicyForS3Notification",
#   "Statement": [
#     {
#       "Effect": "Allow",
#       "Principal": {
#         "Service": "s3.amazonaws.com"
#       },
#       "Action": "sqs:SendMessage",
#       "Resource": "${aws_sqs_queue.s3_notification_queue.arn}",
#       "Condition": {
#         "ArnLike": {
#           "aws:SourceArn": "arn:aws:s3:::${var.bucket_name}"
#         }
#       }
#     }
#   ]
# }
# EOF
# }

# # Step 3: Define an S3 Bucket (optional) and Configure Notifications to SQS


# # Optional: Add S3 Notification Configuration to send events to SQS
# resource "aws_s3_bucket_notification" "bucket_notification" {
#   bucket = aws_s3_bucket.bucket.id

#   queue {
#     queue_arn = aws_sqs_queue.s3_notification_queue.arn
#     events    = ["s3:ObjectCreated:*"]
#   }
# }

