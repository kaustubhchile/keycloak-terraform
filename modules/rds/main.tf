# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  CREDENTIAL STRATEGY — BYO or Auto-generate
#
#  For each of the four credentials:
#    • If the matching variable is null (default) → Terraform auto-generates it
#    • If you set the variable                    → your value is used
#
#  All four final values land in AWS Secrets Manager regardless of which
#  path was taken. Retrieval is always the same CLI command.
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# ── Auto-generated fallbacks ───────────────────────────────────────────────────
resource "random_password" "db_password" {
  length           = 32
  special          = true
  override_special = "!#$%^&*()-_=+[]"
  min_upper        = 4
  min_lower        = 4
  min_numeric      = 4
  min_special      = 2
}

resource "random_string" "db_username_suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "random_password" "keycloak_admin_password" {
  length           = 24
  special          = true
  override_special = "!#$%^&*()-_=+"
  min_upper        = 4
  min_lower        = 4
  min_numeric      = 4
  min_special      = 2
}

# ── Resolve final values ───────────────────────────────────────────────────────
locals {
  db_username             = var.db_username != null ? var.db_username : "keycloak_${var.environment}_${random_string.db_username_suffix.result}"
  db_password             = var.db_password != null ? var.db_password : random_password.db_password.result
  keycloak_admin_user     = var.keycloak_admin_user != null ? var.keycloak_admin_user : "admin"
  keycloak_admin_password = var.keycloak_admin_password != null ? var.keycloak_admin_password : random_password.keycloak_admin_password.result
}

# ── AWS Secrets Manager — RDS credentials ─────────────────────────────────────
resource "aws_secretsmanager_secret" "rds" {
  name                    = "${var.environment}/keycloak/rds-credentials"
  description             = "RDS PostgreSQL credentials for Keycloak (${var.environment})"
  recovery_window_in_days = 7
  tags                    = { Name = "${var.environment}-keycloak-rds-secret" }
}

resource "aws_secretsmanager_secret_version" "rds" {
  secret_id = aws_secretsmanager_secret.rds.id

  secret_string = jsonencode({
    username          = local.db_username
    password          = local.db_password
    host              = aws_db_instance.this.address
    port              = aws_db_instance.this.port
    dbname            = var.db_name
    engine            = "postgres"
    jdbc_url          = "jdbc:postgresql://${aws_db_instance.this.address}:${aws_db_instance.this.port}/${var.db_name}"
    credential_source = var.db_password != null ? "user-supplied" : "auto-generated"
  })

  depends_on = [aws_db_instance.this]
}

# ── AWS Secrets Manager — Keycloak admin credentials ──────────────────────────
resource "aws_secretsmanager_secret" "keycloak_admin" {
  name                    = "${var.environment}/keycloak/admin-credentials"
  description             = "Keycloak admin console credentials (${var.environment})"
  recovery_window_in_days = 7
  tags                    = { Name = "${var.environment}-keycloak-admin-secret" }
}

resource "aws_secretsmanager_secret_version" "keycloak_admin" {
  secret_id = aws_secretsmanager_secret.keycloak_admin.id

  secret_string = jsonencode({
    username          = local.keycloak_admin_user
    password          = local.keycloak_admin_password
    credential_source = var.keycloak_admin_password != null ? "user-supplied" : "auto-generated"
  })
}

# ── IAM policy — allows EKS nodes to read both secrets ────────────────────────
data "aws_iam_policy_document" "secrets_read" {
  statement {
    sid    = "AllowReadKeycloakSecrets"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    resources = [
      aws_secretsmanager_secret.rds.arn,
      aws_secretsmanager_secret.keycloak_admin.arn,
    ]
  }
}

resource "aws_iam_policy" "secrets_read" {
  name        = "${var.environment}-keycloak-secrets-read"
  description = "Allows reading Keycloak RDS + admin secrets from Secrets Manager"
  policy      = data.aws_iam_policy_document.secrets_read.json
}

resource "aws_iam_role_policy_attachment" "node_secrets" {
  policy_arn = aws_iam_policy.secrets_read.arn
  role       = var.eks_node_role_name
}

# ── RDS Security Group ─────────────────────────────────────────────────────────
resource "aws_security_group" "rds" {
  name        = "${var.environment}-rds-sg"
  description = "Allow PostgreSQL traffic from EKS nodes only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from EKS nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.eks_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.environment}-rds-sg" }
}

# ── RDS Subnet Group ───────────────────────────────────────────────────────────
resource "aws_db_subnet_group" "this" {
  name       = "${var.environment}-keycloak-db-subnet-group"
  subnet_ids = var.private_subnet_ids
  tags       = { Name = "${var.environment}-keycloak-db-subnet-group" }
}

# ── RDS Parameter Group ────────────────────────────────────────────────────────
resource "aws_db_parameter_group" "this" {
  name   = "${var.environment}-keycloak-pg15"
  family = "postgres15"

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  tags = { Name = "${var.environment}-keycloak-pg15" }
}

# ── RDS Instance ───────────────────────────────────────────────────────────────
resource "aws_db_instance" "this" {
  identifier = "${var.environment}-keycloak-postgres"

  engine         = "postgres"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_allocated_storage * 3
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = local.db_username # BYO or auto-generated
  password = local.db_password # BYO or auto-generated

  manage_master_user_password = false

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.this.name

  multi_az            = var.db_multi_az
  publicly_accessible = false
  deletion_protection = true

  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.environment}-keycloak-final-snapshot"

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  performance_insights_enabled = true

  tags = { Name = "${var.environment}-keycloak-postgres" }
}
