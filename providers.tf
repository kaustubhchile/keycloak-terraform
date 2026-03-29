provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "keycloak"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# Kubernetes provider — wired to EKS cluster output
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
  token                  = module.eks.cluster_auth_token
}

# Helm provider — wired to same EKS cluster
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
    token                  = module.eks.cluster_auth_token
  }
}
