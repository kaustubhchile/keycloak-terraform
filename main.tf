# ── S3 + DynamoDB remote-state bootstrap ──────────────────────────────────────
# These two resources are intentionally kept in the root so you can do a
# one-time `terraform apply -target=...` before enabling the S3 backend.
# After the bucket + table exist, uncomment the backend block in versions.tf
# and run `terraform init -migrate-state`.

resource "aws_s3_bucket" "tfstate" {
  bucket        = "keycloak-tfstate-bucket" # ← must match versions.tf backend block
  force_destroy = false

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "tfstate_lock" {
  name         = "keycloak-tfstate-lock" # ← must match versions.tf backend block
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

# ── VPC ────────────────────────────────────────────────────────────────────────
module "vpc" {
  source = "./modules/vpc"

  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  private_subnets    = var.private_subnets
  public_subnets     = var.public_subnets
  cluster_name       = var.cluster_name
}

# ── EKS ────────────────────────────────────────────────────────────────────────
module "eks" {
  source = "./modules/eks"

  environment        = var.environment
  cluster_name       = var.cluster_name
  kubernetes_version = var.kubernetes_version
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  node_instance_type = var.node_instance_type
  node_desired_size  = var.node_desired_size
  node_min_size      = var.node_min_size
  node_max_size      = var.node_max_size
}

# ── RDS (PostgreSQL) ───────────────────────────────────────────────────────────
module "rds" {
  source = "./modules/rds"

  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  eks_security_group_id = module.eks.node_security_group_id
  eks_node_role_name    = module.eks.node_role_name
  db_name               = var.db_name
  db_instance_class     = var.db_instance_class
  db_allocated_storage  = var.db_allocated_storage
  db_engine_version     = var.db_engine_version
  db_multi_az           = var.db_multi_az

  # Optional BYO credentials — null = auto-generate
  db_username             = var.db_username             # null → auto-generate
  db_password             = var.db_password             # null → auto-generate
  keycloak_admin_user     = var.keycloak_admin_user     # null → "admin"
  keycloak_admin_password = var.keycloak_admin_password # null → auto-generate
}

# ── Keycloak (Helm) ────────────────────────────────────────────────────────────
module "keycloak" {
  source = "./modules/keycloak"

  environment               = var.environment
  keycloak_namespace        = var.keycloak_namespace
  keycloak_replica_count    = var.keycloak_replica_count
  keycloak_chart_version    = var.keycloak_chart_version
  rds_secret_arn            = module.rds.rds_secret_arn
  keycloak_admin_secret_arn = module.rds.keycloak_admin_secret_arn

  depends_on = [module.eks, module.rds]
}
