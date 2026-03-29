terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  backend "s3" {
    bucket         = "keycloak-tfstate-bucket"       # ← change to your unique bucket name
    key            = "keycloak/terraform.tfstate"
    region         = "us-east-1"                     # ← change to your region
    encrypt        = true
    dynamodb_table = "keycloak-tfstate-lock"
  }
}
