output "cluster_name" { value = aws_eks_cluster.this.name }
output "cluster_endpoint" { value = aws_eks_cluster.this.endpoint }
output "cluster_ca_certificate" { value = aws_eks_cluster.this.certificate_authority[0].data }
output "cluster_auth_token" {
  value     = data.aws_eks_cluster_auth.this.token
  sensitive = true
}
output "node_security_group_id" { value = aws_security_group.eks_nodes.id }
output "cluster_oidc_issuer" { value = aws_eks_cluster.this.identity[0].oidc[0].issuer }
output "node_role_name" { value = aws_iam_role.eks_nodes.name }

