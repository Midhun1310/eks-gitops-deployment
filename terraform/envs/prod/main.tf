provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "mk-platform"
      Environment = "prod"
      ManagedBy   = "terraform"
    }
  }
}

module "platform" {
  source = "../../modules/platform"

  environment  = "prod"
  region       = var.region
  ecr_registry = var.ecr_registry

  vpc_cidr             = var.vpc_cidr
  az_count             = var.az_count
  single_nat_gateway   = var.single_nat_gateway
  enable_vpc_flow_logs = var.enable_vpc_flow_logs

  kubernetes_version                   = var.kubernetes_version
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs
  cluster_admin_role_arns              = var.cluster_admin_role_arns

  node_instance_types = var.node_instance_types
  node_capacity_type  = var.node_capacity_type
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size
  node_desired_size   = var.node_desired_size

  db_instance_class        = var.db_instance_class
  db_multi_az              = var.db_multi_az
  db_backup_retention_days = var.db_backup_retention_days
  db_deletion_protection   = var.db_deletion_protection

  app_hostname    = var.app_hostname
  route53_zone_id = var.route53_zone_id
}
