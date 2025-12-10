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
            values   = [aws_cloudfront_distribution.s3_distribution.arn]
        }
    }
}

# Provides details about the hosted zone
data "aws_route53_zone" "hosted_zone" {
    name         = "banksie.app"
    private_zone = false
}

# Provides details for the root/subdomain certificate
data "aws_acm_certificate" "app_cert" {
    region   = var.region
    domain   = local.root_domain
    statuses = ["ISSUED"]
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

data "aws_acm_certificate" "api_cert" {
    region   = var.region
    domain   = local.api_domain
    statuses = ["ISSUED"]
}
