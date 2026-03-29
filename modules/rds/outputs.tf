output "db_endpoint" {
  description = "RDS hostname (without port)"
  value       = aws_db_instance.this.address
  sensitive   = true
}

output "db_port" {
  description = "RDS port"
  value       = aws_db_instance.this.port
}

output "keycloak_admin_user" {
  description = "Resolved Keycloak admin username (BYO or 'admin')"
  value       = local.keycloak_admin_user
}

output "rds_secret_arn" {
  description = "ARN of the Secrets Manager secret holding RDS credentials"
  value       = aws_secretsmanager_secret.rds.arn
}

output "keycloak_admin_secret_arn" {
  description = "ARN of the Secrets Manager secret holding Keycloak admin credentials"
  value       = aws_secretsmanager_secret.keycloak_admin.arn
}


