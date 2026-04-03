variable "aws_region" {
  description = "AWS region to deploy all resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment label (prod / staging / dev)"
  type        = string
  default     = "prod"
}

# ── VPC ────────────────────────────────────────────────────────────────────────
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of AZs to spread subnets across (must be >= 2)"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "private_subnets" {
  description = "CIDR blocks for private subnets (EKS nodes + RDS)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnets" {
  description = "CIDR blocks for public subnets (NAT GW + LB)"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

# ── EKS ────────────────────────────────────────────────────────────────────────
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "keycloak-cluster"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.29"
}

variable "node_instance_type" {
  description = "EC2 instance type for EKS managed node group"
  type        = string
  default     = "c7i-flex.large"
}

variable "node_desired_size" {
  description = "Desired number of EKS worker nodes"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of EKS worker nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of EKS worker nodes"
  type        = number
  default     = 4
}

# ── RDS ────────────────────────────────────────────────────────────────────────
variable "db_name" {
  description = "Database name for Keycloak (the logical DB inside PostgreSQL)"
  type        = string
  default     = "keycloak"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "Allocated storage in GB for RDS"
  type        = number
  default     = 20
}

variable "db_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "17.6"
}

variable "db_multi_az" {
  description = "Enable Multi-AZ for RDS (AWS Free Tier does not support Multi-AZ)"
  type        = bool
  default     = false # ← Changed from true to false
}

# ── Optional credential overrides (BYO or auto-generate) ──────────────────────
# Leave all four as null to have Terraform auto-generate strong credentials
# and store them in AWS Secrets Manager. Set any of them to use your own value.
# All values — whether supplied or generated — are stored in Secrets Manager.

variable "db_username" {
  description = <<-EOT
    RDS master username.
      null (default) = auto-generate, e.g. "keycloak_prod_a1b2c3"
      custom         = must start with a letter, letters/digits/underscores only, max 63 chars
  EOT
  type        = string
  default     = null
  sensitive   = true
}

variable "db_password" {
  description = <<-EOT
    RDS master password.
      null (default) = auto-generate a 32-char random password
      custom         = minimum 16 characters
  EOT
  type        = string
  default     = null
  sensitive   = true
}

variable "keycloak_admin_user" {
  description = <<-EOT
    Keycloak admin console username.
      null (default) = use "admin"
      custom         = any non-empty string
  EOT
  type        = string
  default     = null
}

variable "keycloak_admin_password" {
  description = <<-EOT
    Keycloak admin console password.
      null (default) = auto-generate a 24-char random password
      custom         = minimum 12 characters
  EOT
  type        = string
  default     = null
  sensitive   = true
}

# ── Keycloak ───────────────────────────────────────────────────────────────────
variable "keycloak_replica_count" {
  description = "Number of Keycloak pod replicas"
  type        = number
  default     = 2
}

variable "keycloak_chart_version" {
  description = "Helm chart version for Keycloak (Bitnami)"
  type        = string
  default     = "21.4.4"
}

variable "keycloak_namespace" {
  description = "Kubernetes namespace to deploy Keycloak into"
  type        = string
  default     = "keycloak"
}
