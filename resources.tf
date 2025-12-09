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

# Upload files to S3 bucket
resource "aws_s3_object" "upload_objects_bucket" {
    bucket = aws_s3_bucket.app_bucket.id

    for_each = {for file in fileset("../frontend/build/", "**"): file => file}

    key          = each.value
    source       = "../frontend/build/${each.value}"
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

# Create OAC for S3 bucket and CloudFront distribution
resource "aws_cloudfront_origin_access_control" "default" {
    name                              = "default-oac"
    origin_access_control_origin_type = "s3"
    signing_behavior                  = "always"
    signing_protocol                  = "sigv4"
}

# Create Cloudfront distribution
resource "aws_cloudfront_distribution" "app_distribution" {
    origin {
        domain_name              = aws_s3_bucket.app_bucket.bucket_regional_domain_name
        origin_access_control_id = aws_cloudfront_origin_access_control.default.id
        origin_id                = local.s3_origin_id
    }

    enabled             = true
    is_ipv6_enabled     = true
    default_root_object = "index.html"
  
    custom_error_response {
        error_code            = 404
        response_code         = 200
        response_page_path    = "/index.html"
        error_caching_min_ttl = 0
    }

    aliases = [local.root_domain, local.subdomain]

    default_cache_behavior {
        allowed_methods  = ["GET", "HEAD"]
        cached_methods   = ["GET", "HEAD"]
        target_origin_id = local.s3_origin_id

        forwarded_values {
          query_string = false

          cookies {
            forward = "none"
          }
        }

        viewer_protocol_policy = "allow-all"
        min_ttl                = 0
        default_ttl            = 3600
        max_ttl                = 86400
    }

    price_class = "PriceClass_All"

    restrictions {
        geo_restriction {
          restriction_type = "none"
          locations        = []
        }
    }  

    viewer_certificate {
      acm_certificate_arn = data.aws_acm_certificate.banksie_app_cert.arn
      ssl_support_method  = "sni-only"
    }
}

# Create A records pointing to the CloudFront distribution
resource "aws_route53_record" "cloudfront" {
    for_each = aws_cloudfront_distribution.cf_distribution.aliases
    zone_id  = data.aws_route53_zone.banksie_app.zone_id
    name     = each.value
    type     = "A"

    alias {
        name                   = aws_cloudfront_distribution.cf_distribution.domain_name
        zone_id                = aws_cloudfront_distribution.cf_distribution.hosted_zone_id
        evaluate_target_health = false
    }
}

# Create VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

# Create subnets
resource "aws_subnet" "subnet_a" {
    vpc_id            = aws_vpc.main.id
    cidr_block        = "10.0.1.0/24"
    availability_zone = "us-east-1a"
}

resource "aws_subnet" "subnet_b" {
    vpc_id            = aws_vpc.main.id
    cidr_block        = "10.0.2.0/24"
    availability_zone = "us-east-1b"
}

# Create VPC security group
resource "aws_security_group" "rds_sg" {
  name        = "rds-sg"
  vpc_id      = aws_vpc.main.id
}

# Create RDS subnet group to attach to VPC
resource "aws_db_subnet_group" "db_subnet_group" {
    name = "db-subnet-group"
    subnet_ids = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]
}

# Create database instance
resource "aws_db_instance" "app_db" {
    allocated_storage      = 20
    db_name                = "mydb"
    identifier             = "mydb"
    engine                 = "postgresql"
    instance_class         = "db.t3.micro"
    username               = "postgres"
    password               = "password"

    vpc_security_group_ids = [aws_security_group.rds_sg.id]
    db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name

    skip_final_snapshot    = true
}

# Create secret for database URL
resource "aws_secretsmanager_secret" "db_secret" {
    name = "DATABASE_URL"
}

# Add secret value to secret
resource "aws_secretsmanager_secret_version" "db_secret" {
    secret_id     = aws_secretsmanager_secret.db_secret.id
    secret_string = "postgresql://${aws_db_instance.app_db.username}:${aws_db_instance.app_db.password}@{aws_db_instance.app_db.endpoint}:${aws_db_instance.app_db.port}/${aws_db_instance.app_db.db_name}"

# Create private repository in ECR
resource "aws_ecr_repository" "app_repo" {
    name                 = "app-repo"
    image_tag_mutability = "MUTABLE"

    image_scanning_configuration {
      scan_on_push = true
    }
}

# Create cluster in ECS
resource "aws_ecs_cluster" "app_cluster" {
    name = "app-cluster"
}

# Create task execution role that allows access to Secret Manager for environment variable/secret
resource "aws_iam_role" "task_execution_role" {
    name               = "ecsTaskExecutionRole"
    assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

# Create task definition
resource "aws_ecs_task_definition" "app_task" {
  family = "app-task"
  container_definitions = jsonencode([
    {
      name      = "first"
      image     = "service-first"
      cpu       = 10
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
    }
  ])

  volume {
    name      = "service-storage"
    host_path = "/ecs/service-storage"
  }

  placement_constraints {
    type       = "memberOf"
    expression = "attribute:ecs.availability-zone in [us-west-2a, us-west-2b]"
  }
}
