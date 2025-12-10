# Create bucket policy for S3 bucket to allow CloudFront access
data "aws_iam_policy_document" "origin_bucket_policy" {
  statement {
      sid    = "AllowCloudFrontServicePrincipal"
      effect = "Allow"

      principals {
        type        = "Service"
        identifiers = ["cloudfront.amazonaws.com"]
      }

      actions = [
        "s3:GetObject",
      ]

      resources = [
        "${aws_s3_bucket.app_bucket.arn}/*",
      ]

      condition {
        test     = "StringEquals"
        variable = "AWS:SourceArn"
        values   = [aws_cloudfront_distribution.app_distribution.arn]
      }
    }
}

# Task execution role data
data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# Provides data about the current authenticated AWS identity
data "aws_caller_identity" "current" {}