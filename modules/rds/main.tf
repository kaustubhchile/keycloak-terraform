# Terraform Configuration for RDS

provider "aws" {
  region = "us-west-2"
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name = "${var.environment}/keycloak/rds-credentials-${formatdate("YYYYMMDDhhmmss", timestamp())}"
  description = "Credentials for RDS database for Keycloak"
  force_overwrite_replica_secret = true
}

# Other resource configurations...

resource "aws_secretsmanager_secret" "admin_credentials" {
  name = "${var.environment}/keycloak/admin-credentials-${formatdate("YYYYMMDDhhmmss", timestamp())}"
  description = "Admin credentials for Keycloak"
  force_overwrite_replica_secret = true
}

variable "override_special" {
  type    = list(string)
  default = ["!#$%^&*-_=+"]
}

# The rest of your existing Terraform configuration
