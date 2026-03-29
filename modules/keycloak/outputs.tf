output "load_balancer_hostname" {
  description = "AWS NLB hostname assigned to Keycloak"
  value = try(
    data.kubernetes_service.keycloak_lb.status[0].load_balancer[0].ingress[0].hostname,
    "pending — re-run terraform output after LB is provisioned"
  )
}

