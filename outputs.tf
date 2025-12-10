output "db_secret_string" {
  value     = aws_secretsmanager_secret_version.db_secret.secret_string
  sensitive = true
}