locals {
    s3_origin_id = "s3origin"
    root_domain = "banksie.app"
    subdomain = "www.banksie.app"
}

# Create hosted zone
resource "aws_route53_zone" "hosted_zone" {
  name = "banksie.app"
}

# Create S3 bucket
resource "aws_s3_bucket" "app_bucket" {
  bucket = "banksie.app"
}

# Attach bucket policy to S3 bucket for CloudFront access
resource "aws_s3_bucket_policy" "app_bucket_policy" {
  bucket = aws_s3_bucket.app_bucket.bucket
  policy = data.aws_iam_policy_document.origin_bucket_policy.json
}


