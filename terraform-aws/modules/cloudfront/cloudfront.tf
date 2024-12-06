#HOW TO USE:
# module "cloudfront" {
#   source = "./modules/cloudfront"
#   alb_dns_name= "" # OPTIONAL
#   alb_id = "" # OPTIONAL but has to be set up if alb dns is set up
# }

variable "bucket_name" {
  default = "demo-john-cloudfront-v1"
}

variable "alb_dns_name" {
  type    = string
  default = ""
}


variable "alb_id" {
  type    = string
  default = ""
}


module "s3" {
  source      = "../s3"
  bucket_name = var.bucket_name
}

output "endpoint" {
  value = module.s3.endpoint
}

output "bucket_name" {
  value = module.s3.bucket_name
}

output "bucket_id" {
  value = module.s3.bucket_id
}




# Step 2: Create Origin Access Control (OAC) for CloudFront
resource "aws_cloudfront_origin_access_control" "oac" {
  name = "s3-oac"

  description = "OAC for CloudFront to access S3 bucket"

  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
  origin_access_control_origin_type = "s3"
}

# Step 3: Create CloudFront Distribution
resource "aws_cloudfront_distribution" "cdn" {
  # Create origin for S3
  origin {
    domain_name = module.s3.bucket_regional_domain_name
    origin_id   = module.s3.bucket_id

    # Origin access control setting for S3
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  # create origin for ALB
  dynamic "origin" {
    for_each = var.alb_id != "" ? [var.alb_id] : []

    content {
      domain_name = var.alb_dns_name # The ALB's DNS name
      origin_id   = origin.value     # Use the variable value as the origin ID

      custom_origin_config {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "http-only" # Use HTTPS to communicate with ALB
        origin_ssl_protocols   = ["TLSv1.2"] # SSL protocols allowed
        #origin_ssl_protocols   = []  # SSL protocols disbled since my apache is on http 80

      }
    }
  }
  enabled         = true
  is_ipv6_enabled = false
  #default_root_object = "index.html"

  # Cache Behavior - Default
  default_cache_behavior {
    target_origin_id = module.s3.bucket_id

    viewer_protocol_policy = "allow-all"

    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

  }

  #custom cache behavior
  ordered_cache_behavior {
    path_pattern           = "/bike.jpeg"
    target_origin_id       = module.s3.bucket_id
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]

    cache_policy_id = aws_cloudfront_cache_policy.basic_cache_policy.id

    min_ttl     = 0
    default_ttl = 86400    # Set cache duration to 1 day
    max_ttl     = 31536000 # Set maximum cache duration to 1 year
  }

  ordered_cache_behavior {
    path_pattern           = "/index.html"
    target_origin_id       = module.s3.bucket_id
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]

    cache_policy_id = aws_cloudfront_cache_policy.basic_cache_policy.id

    min_ttl     = 0
    default_ttl = 86400    # Set cache duration to 1 day
    max_ttl     = 31536000 # Set maximum cache duration to 1 year
  }

  #custom cache behavior for page*.html TTL set up to 60 seconds
  ordered_cache_behavior {
    path_pattern           = "/page*.html"
    target_origin_id       = module.s3.bucket_id
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]

    cache_policy_id = aws_cloudfront_cache_policy.ttl_60_cache_policy.id

    min_ttl     = 0
    default_ttl = 60       # Set cache duration to 1 day
    max_ttl     = 31536000 # Set maximum cache duration to 1 year
  }

  #custom cache behavior for ALB
  dynamic "ordered_cache_behavior" {
    for_each = var.alb_id != "" ? [1] : [] # Only create the block if var.alb_id is not empty

    content {
      path_pattern           = "*"         # Matches all paths
      target_origin_id       = var.alb_id  # Use ALB origin ID
      viewer_protocol_policy = "allow-all" # Allow both HTTP and HTTPS for viewer connections

      allowed_methods = ["GET", "HEAD"]
      cached_methods  = ["GET", "HEAD"]

      cache_policy_id = aws_cloudfront_cache_policy.basic_cache_policy.id

      min_ttl     = 0
      default_ttl = 86400    # Set cache duration to 1 day
      max_ttl     = 31536000 # Set maximum cache duration to 1 year
    }
  }

  # Disable WAF (optional, no need to define it)

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
  tags = {
    Terraform = "yes"
  }
}

resource "aws_cloudfront_cache_policy" "basic_cache_policy" {
  name = "BasicCachePolicy"

  parameters_in_cache_key_and_forwarded_to_origin {
    headers_config {
      header_behavior = "none"
    }
    cookies_config {
      cookie_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "none"
    }
  }

  default_ttl = 86400    # 1 day
  max_ttl     = 31536000 # 1 year
  min_ttl     = 0

  comment = "Cache policy basic"
}


resource "aws_cloudfront_cache_policy" "ttl_60_cache_policy" {
  name = "TTL_60_CachePolicy"

  parameters_in_cache_key_and_forwarded_to_origin {
    headers_config {
      header_behavior = "none"
    }
    cookies_config {
      cookie_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "none"
    }
  }

  default_ttl = 60       # 1 day
  max_ttl     = 31536000 # 1 year
  min_ttl     = 0

  comment = "Cache policy for page*.html"
}

## TO REPLACE POLICY:
resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = module.s3.bucket_id

  policy = <<EOF
{
	"Version": "2008-10-17",
	"Id": "PolicyForCloudFrontPrivateContent",
	"Statement": [
	    {
	        "Sid": "AllowCloudFrontServicePrincipal",
	        "Effect": "Allow",
	        "Principal": {
	            "Service": "cloudfront.amazonaws.com"
	        },
	        "Action": "s3:GetObject",
	        "Resource": "${module.s3.bucket_arn}/*",
	        "Condition": {
	            "StringEquals": {
	              "AWS:SourceArn": "${aws_cloudfront_distribution.cdn.arn}"
	            }
	        }
	    }
	]
}
EOF
}

## TO MERGE
# Step 4: Fetch the Existing S3 Bucket Policy (if exists)
# data "aws_s3_bucket_policy" "existing_policy" {
#   bucket = module.s3.bucket_id
# }

# # Step 5: MERGE: Update the S3 Bucket Policy to Allow CloudFront (OAC) Access
# resource "aws_s3_bucket_policy" "bucket_policy" {
#   bucket = module.s3.bucket_id

#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = concat(
#       # Existing bucket policy statements
#     try(
#         jsondecode(data.aws_s3_bucket_policy.existing_policy.policy).Statement,
#         []  # Return an empty list if there's an error or no existing policy
#       ),      
#       # New statement for CloudFront OAC access
#       [
#         {
#           Effect = "Allow",
#           Principal = {
#             Service = "cloudfront.amazonaws.com"  # CloudFront service principal
#           },
#           Action = "s3:GetObject",
#           Resource = "${module.s3.bucket_arn}/*",
#           Condition = {
#             StringEquals = {
#               "AWS:SourceArn" = aws_cloudfront_distribution.cdn.arn  # Restrict access to this specific CloudFront distribution
#             }
#           }
#         }
#       ]
#     )
#   })
# }