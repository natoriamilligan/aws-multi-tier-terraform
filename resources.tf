locals {
    s3_origin_id = "s3origin"
    root_domain = "banksie.app"
    subdomain = "www.banksie.app"
}

resource "aws_route53_zone" "hosted_zone" {
  name = "banksie.app"
}

resource "aws_s3_bucket" "app_bucket" {
  bucket = "banksie.app"
}

resource "aws_s3_bucket_policy" "app_bucket_policy" {
  bucket = aws_s3_bucket.app_bucket.bucket
  policy = data.aws_iam_policy_document.origin_bucket_policy.json
}


