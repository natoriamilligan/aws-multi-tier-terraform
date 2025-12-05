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

# Create certificate for root and subdomain
resource "aws_acm_certificate" "domain_cert" {
  domain_name       = "banksie.app"
  subject_alternative_names = ["www.banksie.app"]
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# Create CNAME records in hosted zone
resource "aws_route53_record" "validation_records" {
  for_each = {
    for domain in aws_acm_certificate.domain_cert.domain_validation_options : domain.domain_name => {
      name    = domain.resource_record_name
      record  = domain.resource_record_value
      type    = domain.resource_record_type
      zone_id = data.aws_route53_zone.banksie_app.zone_id
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = each.value.zone_id
}

# Validate the certificate using CNAME records
resource "aws_acm_certificate_validation" "cert_validation" {
  certificate_arn         = aws_acm_certificate.domain_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.validation_records : record.fqdn]
}

