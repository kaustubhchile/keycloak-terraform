variable "environment" { type = string }
variable "keycloak_namespace" { type = string }
variable "keycloak_replica_count" { type = number }
variable "keycloak_chart_version" { type = string }

# Secret ARNs — credentials are fetched directly from Secrets Manager at apply time
variable "rds_secret_arn" {
  description = "ARN of the Secrets Manager secret containing RDS credentials JSON"
  type        = string
}

variable "keycloak_admin_secret_arn" {
  description = "ARN of the Secrets Manager secret containing Keycloak admin credentials JSON"
  type        = string
}

