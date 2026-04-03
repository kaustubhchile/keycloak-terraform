output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "API server endpoint of the EKS cluster"
  value       = module.eks.cluster_endpoint
  sensitive   = true
}

output "rds_endpoint" {
  description = "RDS PostgreSQL hostname"
  value       = module.rds.db_endpoint
  sensitive   = true
}

# ── Secrets Manager ARNs (retrieve credentials from here, not from Terraform) ──
output "rds_credentials_secret_arn" {
  description = "AWS Secrets Manager ARN for RDS credentials. Retrieve with: aws secretsmanager get-secret-value --secret-id <arn>"
  value       = module.rds.rds_secret_arn
}

output "keycloak_admin_credentials_secret_arn" {
  description = "AWS Secrets Manager ARN for Keycloak admin credentials. Retrieve with: aws secretsmanager get-secret-value --secret-id <arn>"
  value       = module.rds.keycloak_admin_secret_arn
}

output "keycloak_load_balancer_hostname" {
  description = "AWS NLB / ALB hostname assigned to the Keycloak service"
  value       = module.keycloak.load_balancer_hostname
}

output "keycloak_url" {
  description = "URL to access the Keycloak admin console"
  value       = "http://${module.keycloak.load_balancer_hostname}"
}

# output "tfstate_bucket_name" {
#   description = "S3 bucket used for Terraform remote state"
#   value       = aws_s3_bucket.tfstate.bucket
# }

# output "tfstate_lock_table" {
#   description = "DynamoDB table used for state locking"
#   value       = aws_dynamodb_table.tfstate_lock.name
# }

# ── Handy CLI snippets printed after apply ─────────────────────────────────────
output "how_to_get_rds_credentials" {
  description = "CLI command to retrieve RDS credentials"
  value       = "aws secretsmanager get-secret-value --secret-id ${module.rds.rds_secret_arn} --query SecretString --output text | jq ."
}

output "how_to_get_keycloak_admin_password" {
  description = "CLI command to retrieve Keycloak admin credentials"
  value       = "aws secretsmanager get-secret-value --secret-id ${module.rds.keycloak_admin_secret_arn} --query SecretString --output text | jq ."
}

