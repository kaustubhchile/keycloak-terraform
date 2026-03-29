# Keycloak on AWS — EKS + RDS + Terraform

Production-grade Keycloak deployment on AWS using:
- **EKS** — managed Kubernetes for Keycloak pods (Bitnami Helm chart)
- **RDS PostgreSQL** — managed, encrypted, Multi-AZ database
- **S3 + DynamoDB** — remote Terraform state with locking
- **GitHub Actions** — manual `plan / apply / destroy` pipeline via OIDC (no long-lived keys)

---

## Architecture

```
Internet
   │
   ▼
AWS NLB (public)
   │
   ▼
EKS Cluster (private subnets)
   │  Keycloak Pods (Helm / Bitnami)
   │
   ▼
RDS PostgreSQL (private subnets, Multi-AZ)
```

All worker nodes and RDS live in **private subnets**. Only the NLB endpoint is public.

---

## Prerequisites

| Tool | Version |
|------|---------|
| Terraform | ≥ 1.6 |
| AWS CLI | ≥ 2.x |
| kubectl | ≥ 1.29 |
| helm | ≥ 3.x |

---

## Quick Start (Local)

### Step 1 — Bootstrap the remote state backend (one-time only)

The S3 bucket and DynamoDB table must exist **before** the S3 backend can be enabled.

```bash
# 1. Comment out the entire backend "s3" block in versions.tf
# 2. Run a targeted apply to create only the bucket + table
terraform init
terraform apply \
  -target=aws_s3_bucket.tfstate \
  -target=aws_s3_bucket_versioning.tfstate \
  -target=aws_s3_bucket_server_side_encryption_configuration.tfstate \
  -target=aws_s3_bucket_public_access_block.tfstate \
  -target=aws_dynamodb_table.tfstate_lock

# 3. Uncomment the backend "s3" block in versions.tf
# 4. Migrate local state into S3
terraform init -migrate-state
```

### Step 2 — Create your tfvars

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values — never commit this file
```

### Step 3 — Plan & Apply

```bash
terraform plan -out=tfplan
terraform apply tfplan
```

### Step 4 — Get the Keycloak URL and admin password

```bash
terraform output keycloak_url
terraform output -raw keycloak_admin_password
```

---

## GitHub Actions Setup

### 1. Create an IAM Role for OIDC (GitHub → AWS)

```bash
# Replace YOUR_ACCOUNT_ID and YOUR_GITHUB_ORG/REPO
aws iam create-role \
  --role-name GitHubActionsKeycloakRole \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_ORG/YOUR_REPO:*"
        }
      }
    }]
  }'

# Attach required policies
aws iam attach-role-policy \
  --role-name GitHubActionsKeycloakRole \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
  # 🔒 For production, scope this down to only EKS/RDS/VPC/S3/DynamoDB actions
```

### 2. Add GitHub Repository Secrets

Go to **Settings → Secrets and variables → Actions** and add:

| Secret Name | Value |
|-------------|-------|
| `AWS_ROLE_ARN` | `arn:aws:iam::YOUR_ACCOUNT_ID:role/GitHubActionsKeycloakRole` |
| `TF_STATE_BUCKET` | `keycloak-tfstate-bucket` (must match `versions.tf`) |
| `TF_LOCK_TABLE` | `keycloak-tfstate-lock` (must match `versions.tf`) |
| `DB_USERNAME` | `keycloak` |
| `KEYCLOAK_ADMIN_USER` | `admin` |

### 3. Add GitHub Environments (optional but recommended)

Create environments named `prod` and `staging` under **Settings → Environments**.  
Add required reviewers for `prod` to enforce manual approval before apply/destroy.

### 4. Run the Workflow

Go to **Actions → Keycloak Infrastructure → Run workflow**:

| Field | Description |
|-------|-------------|
| `action` | `plan` — preview changes; `apply` — deploy; `destroy` — tear down |
| `environment` | `prod` or `staging` |
| `confirm_destroy` | Type exactly `DESTROY` when running destroy |

---

## Accessing Keycloak

### After `terraform apply` or GitHub Actions apply:

```bash
# 1. Get the Load Balancer URL
terraform output keycloak_url
# → http://<aws-nlb-hostname>

# 2. Get the admin password
terraform output -raw keycloak_admin_password

# 3. Open your browser to:
#    http://<aws-nlb-hostname>/admin
#    Username: admin (or whatever keycloak_admin_user is set to)
#    Password: (from step 2)
```

> ⏳ The NLB DNS name takes **2–5 minutes** to propagate after the first apply.

### Update your kubeconfig to use kubectl

```bash
aws eks update-kubeconfig \
  --region us-east-1 \
  --name keycloak-cluster

kubectl get pods -n keycloak
kubectl get svc  -n keycloak
```

### Check Keycloak pod logs

```bash
kubectl logs -n keycloak -l app.kubernetes.io/name=keycloak --tail=100
```

---

## File Structure

```
keycloak-terraform/
├── .github/
│   └── workflows/
│       └── keycloak-infra.yml    # Manual plan/apply/destroy pipeline
├── modules/
│   ├── vpc/                      # VPC, subnets, NAT GW, route tables
│   ├── eks/                      # EKS cluster, node group, IAM roles
│   ├── rds/                      # RDS PostgreSQL, subnet group, SGs
│   └── keycloak/                 # Helm release + K8s namespace/secrets
├── main.tf                       # Wires all modules + S3/DynamoDB bootstrap
├── variables.tf                  # All input variables with defaults
├── outputs.tf                    # LB URL, admin password, cluster name
├── providers.tf                  # AWS, Kubernetes, Helm providers
├── versions.tf                   # Terraform + provider versions + S3 backend
├── terraform.tfvars.example      # Template — copy to terraform.tfvars
└── .gitignore
```

---

## Security Notes

- RDS is **not publicly accessible** — only reachable from EKS node SG
- RDS storage is **encrypted at rest** (AES-256)
- Admin password is **auto-generated** (20 chars) and stored in a Kubernetes Secret
- Terraform state is **encrypted** in S3 with versioning enabled
- GitHub Actions authenticates to AWS via **OIDC** — no long-lived access keys
- `deletion_protection = true` on RDS prevents accidental drops

---

## Destroy

```bash
# Local
terraform destroy

# Via GitHub Actions
# Run workflow → action: destroy → confirm_destroy: DESTROY
```

> ⚠️ RDS has `deletion_protection = true`. You must disable it manually in the AWS console (or set `deletion_protection = false` in variables) before destroy will succeed.
