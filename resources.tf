resource "aws_route53_zone" "hosted_zone" {
  name = "banksie.app"
}

resource "aws_s3_bucket" "app_bucket" {
  bucket = "banksie.app"
}
