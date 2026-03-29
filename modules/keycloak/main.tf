
# ── Read credentials from Secrets Manager (never passed as plain variables) ───
data "aws_secretsmanager_secret_version" "rds" {
  secret_id = var.rds_secret_arn
}

data "aws_secretsmanager_secret_version" "keycloak_admin" {
  secret_id = var.keycloak_admin_secret_arn
}

locals {
  rds_creds   = jsondecode(data.aws_secretsmanager_secret_version.rds.secret_string)
  admin_creds = jsondecode(data.aws_secretsmanager_secret_version.keycloak_admin.secret_string)
}

# ── Kubernetes Namespace ───────────────────────────────────────────────────────
resource "kubernetes_namespace" "keycloak" {
  metadata {
    name = var.keycloak_namespace
    labels = {
      environment = var.environment
      app         = "keycloak"
    }
  }
}

# ── Kubernetes Secret: Keycloak Admin (sourced from Secrets Manager) ───────────
resource "kubernetes_secret" "keycloak_admin" {
  metadata {
    name      = "keycloak-admin-credentials"
    namespace = kubernetes_namespace.keycloak.metadata[0].name
    annotations = {
      "managed-by"      = "terraform"
      "secrets-manager" = var.keycloak_admin_secret_arn
    }
  }

  data = {
    admin-user     = local.admin_creds["username"]
    admin-password = local.admin_creds["password"]
  }

  type = "Opaque"
}

# ── Kubernetes Secret: RDS credentials (sourced from Secrets Manager) ──────────
resource "kubernetes_secret" "keycloak_db" {
  metadata {
    name      = "keycloak-db-credentials"
    namespace = kubernetes_namespace.keycloak.metadata[0].name
    annotations = {
      "managed-by"      = "terraform"
      "secrets-manager" = var.rds_secret_arn
    }
  }

  data = {
    db-host     = local.rds_creds["host"]
    db-port     = tostring(local.rds_creds["port"])
    db-name     = local.rds_creds["dbname"]
    db-username = local.rds_creds["username"]
    db-password = local.rds_creds["password"]
    jdbc-url    = local.rds_creds["jdbc_url"]
  }

  type = "Opaque"
}

# ── Helm Release: Keycloak (Bitnami) ──────────────────────────────────────────
resource "helm_release" "keycloak" {
  name       = "keycloak"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "keycloak"
  version    = var.keycloak_chart_version
  namespace  = kubernetes_namespace.keycloak.metadata[0].name

  timeout         = 600
  cleanup_on_fail = true
  atomic          = true

  # ── Admin credentials — pulled from K8s secret ────────────────────────────
  set {
    name  = "auth.adminUser"
    value = local.admin_creds["username"]
  }

  set_sensitive {
    name  = "auth.adminPassword"
    value = local.admin_creds["password"]
  }

  # ── Replicas ──────────────────────────────────────────────────────────────
  set {
    name  = "replicaCount"
    value = var.keycloak_replica_count
  }

  # ── External PostgreSQL — pulled from K8s secret ──────────────────────────
  set {
    name  = "postgresql.enabled"
    value = "false"
  }

  set {
    name  = "externalDatabase.host"
    value = local.rds_creds["host"]
  }

  set {
    name  = "externalDatabase.port"
    value = tostring(local.rds_creds["port"])
  }

  set {
    name  = "externalDatabase.database"
    value = local.rds_creds["dbname"]
  }

  set {
    name  = "externalDatabase.user"
    value = local.rds_creds["username"]
  }

  set_sensitive {
    name  = "externalDatabase.password"
    value = local.rds_creds["password"]
  }

  # ── Service: AWS NLB ──────────────────────────────────────────────────────
  set {
    name  = "service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
    value = "nlb"
  }

  # ── Production mode ───────────────────────────────────────────────────────
  set {
    name  = "production"
    value = "false" # set to true + configure TLS when you have a domain + cert
  }

  set {
    name  = "proxy"
    value = "edge"
  }

  # ── Resources ─────────────────────────────────────────────────────────────
  set {
    name  = "resources.requests.memory"
    value = "512Mi"
  }

  set {
    name  = "resources.requests.cpu"
    value = "250m"
  }

  set {
    name  = "resources.limits.memory"
    value = "1Gi"
  }

  set {
    name  = "resources.limits.cpu"
    value = "500m"
  }

  depends_on = [
    kubernetes_namespace.keycloak,
    kubernetes_secret.keycloak_admin,
    kubernetes_secret.keycloak_db,
  ]
}

# ── Read the LB hostname after Helm deploy ─────────────────────────────────────
data "kubernetes_service" "keycloak_lb" {
  metadata {
    name      = "keycloak"
    namespace = kubernetes_namespace.keycloak.metadata[0].name
  }

  depends_on = [helm_release.keycloak]
}

