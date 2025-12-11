locals {
  s3_origin_id = "s3origin"
  root_domain  = "banksie.app"
  subdomain    = "www.banksie.app"
  api_domain   = "api.banksie.app"
  types        = {
    html = "text/html"
    css  = "text/css"
    js   = "application/javascript"
    json = "application/json"
    png  = "image/png"
    jpg  = "image/jpeg"
    jpeg = "image/jpeg"
    svg  = "image/svg+xml"
    ico  = "image/x-icon"
    map  = "application/json"
    txt  = "text/plain"
  }
}

# Create hosted zone
resource "aws_route53_zone" "hosted_zone" {
  name = local.root_domain
}

# Create S3 bucket
resource "aws_s3_bucket" "app_bucket" {
  bucket = local.root_domain
}

# Upload objects to S3 bucket
resource "aws_s3_object" "upload_source_files" {
  bucket       = aws_s3_bucket.app_bucket.id

  for_each     = fileset("../python-banking-app/frontend/build/", "**/*")

  key          = each.value
  source       = "../python-banking-app/frontend/build/${each.value}"
  content_type = lookup(local.types, regex("\\.([^.]+)$", each.value)[0], "application/octet-stream")
}

# Attach bucket policy to S3 bucket for CloudFront access
resource "aws_s3_bucket_policy" "app_bucket_policy" {
  bucket = aws_s3_bucket.app_bucket.bucket
  policy = data.aws_iam_policy_document.origin_bucket_policy.json

  depends_on = [aws_cloudfront_distribution.app_distribution]
}

# Create certificate for root and subdomain
resource "aws_acm_certificate" "domain_cert" {
  domain_name       = local.root_domain
  subject_alternative_names = [local.subdomain]
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# Create CNAME records in hosted zone for domain/subdomain
resource "aws_route53_record" "validation_records" {
  for_each = {
    for domain in aws_acm_certificate.domain_cert.domain_validation_options : domain.domain_name => {
      name    = domain.resource_record_name
      record  = domain.resource_record_value
      type    = domain.resource_record_type
      zone_id = aws_route53_zone.hosted_zone.zone_id
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 300
  type            = each.value.type
  zone_id         = each.value.zone_id
}

# Validate the domain/subdomain certificate using CNAME records
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
    acm_certificate_arn = aws_acm_certificate.domain_cert.arn
    ssl_support_method  = "sni-only"
  }
}

# Create A records pointing to the CloudFront distribution
resource "aws_route53_record" "cloudfront" {
  for_each = aws_cloudfront_distribution.app_distribution.aliases
  zone_id  = aws_route53_zone.hosted_zone.zone_id
  name     = each.value
  type     = "A"

  alias {
    name                   = aws_cloudfront_distribution.app_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.app_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

# Create VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

# Create private subnets
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
}

# Create internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

# Create public subnets
resource "aws_subnet" "public_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.101.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.102.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true
}

# Create public route table and connect internet gateway
resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.main.id
  route {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.igw.id
  }
}

# Connect public subnet to route table for internet access
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.route_table.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.route_table.id
}

# Create RDS security group
resource "aws_security_group" "db_sg" {
  name        = "rds-sg"
  vpc_id      = aws_vpc.main.id
}

# Allow database traffic from ECS tasks
resource "aws_security_group_rule" "allow_task" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.app_task_sg.id
  security_group_id        = aws_security_group.db_sg.id
}

# Allow database outbound traffic anywhere
resource "aws_vpc_security_group_egress_rule" "db_allow_all" {
  security_group_id = aws_security_group.db_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}


# Create database subnet group to attach to VPC
resource "aws_db_subnet_group" "db_subnet_group" {
  name = "db-subnet-group"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}

# Create database instance
resource "aws_db_instance" "app_db" {
  allocated_storage      = 20
  db_name                = "mydb"
  identifier             = "mydb"
  engine                 = "postgres"
  instance_class         = "db.t3.micro"
  username               = "postgres"
  password               = "password"

  vpc_security_group_ids = [aws_security_group.db_sg.id]
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
  secret_string = "postgresql://${aws_db_instance.app_db.username}:${aws_db_instance.app_db.password}@${aws_db_instance.app_db.endpoint}:${aws_db_instance.app_db.port}/${aws_db_instance.app_db.db_name}"
}

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

# Create policy to allow ECS to access the secret created in Secrets Manager
resource "aws_iam_role_policy" "test_policy" {
  name = "accessSecretsManager"
  role = aws_iam_role.task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
          Action = ["secretsmanager:GetSecretValue"]
          Effect   = "Allow"
          Resource = [aws_secretsmanager_secret.db_secret.arn]
      },
    ]
  })
}

# Add AWS managed task role policy to role
resource "aws_iam_role_policy_attachment" "AWS_managed_task_policy" {
  role       = aws_iam_role.task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Create task definition
resource "aws_ecs_task_definition" "app_task" {
  family                   = "app-task"
  execution_role_arn       = aws_iam_role.task_execution_role.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "2048"
  container_definitions    = jsonencode([
    {
      name      = "app-container"
      image     = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/${aws_ecr_repository.app_repo.name}:latest"
      cpu       = 0
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ],
      secrets = [
        {
          name = "DATABASE_URL"
          valueFrom = aws_secretsmanager_secret.db_secret.arn
        }
      ]
    }
  ])
}

# Create security group for load balancer
resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  vpc_id      = aws_vpc.main.id
}

# Allow all HTTP traffic to LB
resource "aws_vpc_security_group_ingress_rule" "alb_alb_http" {
  security_group_id = aws_security_group.alb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

# Allow all HTTPS traffic to LB
resource "aws_vpc_security_group_ingress_rule" "alb_alb_https" {
  security_group_id = aws_security_group.alb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

# Allow HTTP traffic to ECS tasks from LB
resource "aws_security_group_rule" "allow_to_app_task_sg" {
  type                     = "egress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.app_task_sg.id
  security_group_id        = aws_security_group.alb_sg.id
}

# Create a load balancer
resource "aws_lb" "app_alb" {
  name               = "app-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id
  ]
}

# Create certificate for LB for public url
resource "aws_acm_certificate" "api_domain_cert" {
  domain_name       = local.api_domain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# Create CNAME records in hosted zone for api
resource "aws_route53_record" "api_validation_record" {
  for_each = {
    for domain in aws_acm_certificate.api_domain_cert.domain_validation_options : domain.domain_name => {
      name    = domain.resource_record_name
      record  = domain.resource_record_value
      type    = domain.resource_record_type
      zone_id = aws_route53_zone.hosted_zone.zone_id
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 300
  type            = each.value.type
  zone_id         = each.value.zone_id
}

# Validate the api certificate using CNAME records
resource "aws_acm_certificate_validation" "api_cert_validation" {
  certificate_arn         = aws_acm_certificate.api_domain_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.api_validation_record : record.fqdn]
}

# Create A record for api domain pointing to LB
resource "aws_route53_record" "alb" {
  zone_id  = aws_route53_zone.hosted_zone.zone_id
  name     = local.api_domain
  type     = "A"

  alias {
    name                   = aws_lb.app_alb.dns_name
    zone_id                = aws_lb.app_alb.zone_id
    evaluate_target_health = false
  }
}

# Create target group for LB
resource "aws_lb_target_group" "app_task_tg" {
  name        = "app-task-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.main.id

  health_check {
    path  = "/health" 
  }
}

# Create listener for LB
resource "aws_lb_listener" "alb_listener" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.api_domain_cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_task_tg.arn
  }
}

# Create security group for ECS tasks
resource "aws_security_group" "app_task_sg" {
  name        = "app-task-sg"
  vpc_id      = aws_vpc.main.id
}

# Allow HTTP traffic to tasks from LB on port 80
resource "aws_security_group_rule" "allow_alb" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb_sg.id
  security_group_id        = aws_security_group.app_task_sg.id
}

# Allow HTTP traffic from tasks
resource "aws_vpc_security_group_egress_rule" "task_allow_all" {
  security_group_id = aws_security_group.app_task_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# Create ECS service
resource "aws_ecs_service" "app-service" {
  name            = "app_service"
  cluster         = aws_ecs_cluster.app_cluster.id
  task_definition = aws_ecs_task_definition.app_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = [aws_security_group.app_task_sg.id]
    subnets          = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app_task_tg.arn
    container_name   = "app-container"
    container_port   = 80
  }
}
