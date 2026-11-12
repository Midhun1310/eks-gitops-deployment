output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "rds_endpoint" {
  value = module.rds.address
}

output "rds_master_secret_arn" {
  value = module.rds.master_user_secret_arn
}

output "app_secret_name" {
  value = aws_secretsmanager_secret.app.name
}

output "acm_certificate_arn" {
  value = local.manage_dns ? aws_acm_certificate_validation.app[0].certificate_arn : ""
}

# Facts about this cluster. scripts/bootstrap-argocd.sh passes them to the ArgoCD root
# Application, which hands them to the Helm charts - so no AWS ID is ever typed by hand.
output "cluster_facts" {
  value = {
    environment          = var.environment
    aws_region           = var.region
    aws_account_id       = data.aws_caller_identity.current.account_id
    cluster_name         = module.eks.cluster_name
    vpc_id               = module.vpc.vpc_id
    vpc_cidr             = var.vpc_cidr
    ecr_registry         = var.ecr_registry
    app_namespace        = var.app_namespace
    app_hostname         = var.app_hostname
    route53_zone_id      = var.route53_zone_id
    acm_certificate_arn  = local.manage_dns ? aws_acm_certificate_validation.app[0].certificate_arn : ""
    rds_endpoint         = module.rds.address
    rds_secret_arn       = module.rds.master_user_secret_arn
    app_secret_name      = aws_secretsmanager_secret.app.name
    external_dns_enabled = local.manage_dns
  }
}
