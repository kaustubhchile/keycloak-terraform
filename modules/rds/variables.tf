variable "environment" { type = string }
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "eks_security_group_id" { type = string }
variable "eks_node_role_name" { type = string }
variable "db_name" { type = string }
variable "db_instance_class" { type = string }
variable "db_allocated_storage" { type = number }
variable "db_engine_version" { type = string }
variable "db_multi_az" { type = bool }

# ── Optional BYO credentials ──────────────────────────────────────────────────
# Leave as null to auto-generate. Set to override with your own values.

variable "db_username" {
  description = "RDS master username. null = auto-generate (e.g. keycloak_prod_a1b2c3). Must start with a letter, letters/digits/underscores only, max 63 chars."
  type        = string
  default     = null
  sensitive   = true

  validation {
    condition     = self == null || can(regex("^[a-zA-Z][a-zA-Z0-9_]{1,62}$", self))
    error_message = "db_username must start with a letter and contain only letters, digits, or underscores (max 63 chars)."
  }
}

variable "db_password" {
  description = "RDS master password. null = auto-generate (32-char random). Minimum 16 chars when supplied."
  type        = string
  default     = null
  sensitive   = true

  validation {
    condition     = self == null || length(self) >= 16
    error_message = "db_password must be at least 16 characters."
  }
}

variable "keycloak_admin_user" {
  description = "Keycloak admin console username. null = use 'admin'."
  type        = string
  default     = null
  sensitive   = false # username is not sensitive — only the password is
}

variable "keycloak_admin_password" {
  description = "Keycloak admin console password. null = auto-generate (24-char random). Minimum 12 chars when supplied."
  type        = string
  default     = null
  sensitive   = true

  validation {
    condition     = self == null || length(self) >= 12
    error_message = "keycloak_admin_password must be at least 12 characters."
  }
}
