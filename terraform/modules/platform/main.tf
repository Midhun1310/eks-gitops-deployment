data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

locals {
  cluster_name = "${var.name}-${var.environment}"
  azs          = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # /20 private (4k IPs - pods consume VPC IPs), /24 public, /24 database
  private_subnets  = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 4, i)]
  public_subnets   = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, 100 + i)]
  database_subnets = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, 200 + i)]

  manage_dns = var.route53_zone_id != "" && var.app_hostname != ""
}

############ Network ############
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.7"

  name = local.cluster_name
  cidr = var.vpc_cidr
  azs  = local.azs

  private_subnets  = local.private_subnets
  public_subnets   = local.public_subnets
  database_subnets = local.database_subnets

  create_database_subnet_group = true
  enable_nat_gateway           = true
  single_nat_gateway           = var.single_nat_gateway
  one_nat_gateway_per_az       = !var.single_nat_gateway
  enable_dns_hostnames         = true

  # Lock down the default SG/NACL so nothing accidentally uses them.
  manage_default_security_group  = true
  default_security_group_ingress = []
  default_security_group_egress  = []

  enable_flow_log                      = var.enable_vpc_flow_logs
  create_flow_log_cloudwatch_log_group = var.enable_vpc_flow_logs
  create_flow_log_cloudwatch_iam_role  = var.enable_vpc_flow_logs
  flow_log_max_aggregation_interval    = 60

  # Subnet discovery tags used by the AWS Load Balancer Controller
  public_subnet_tags  = { "kubernetes.io/role/elb" = 1 }
  private_subnet_tags = { "kubernetes.io/role/internal-elb" = 1 }
}

############ EKS ############
module "ebs_csi_role" {
  source              = "../pod-identity"
  name                = "${local.cluster_name}-ebs-csi"
  cluster_name        = local.cluster_name
  namespace           = "kube-system"
  service_account     = "ebs-csi-controller-sa"
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"]
  create_association  = false # the EKS addon creates the association (below)
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.29"

  name               = local.cluster_name
  kubernetes_version = var.kubernetes_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  endpoint_public_access       = true
  endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs
  endpoint_private_access      = true

  enabled_log_types                      = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  cloudwatch_log_group_retention_in_days = 30

  # API-based access (no aws-auth ConfigMap). The identity running Terraform becomes admin,
  # plus any roles listed in cluster_admin_role_arns.
  enable_cluster_creator_admin_permissions = true
  access_entries = {
    for arn in var.cluster_admin_role_arns : replace(arn, "/^.*//", "") => {
      principal_arn = arn
      policy_associations = {
        admin = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  }

  addons = {
    eks-pod-identity-agent = { before_compute = true }
    vpc-cni = {
      before_compute = true
      # NetworkPolicy enforcement for the chart's default-deny policies
      configuration_values = jsonencode({ enableNetworkPolicy = "true" })
    }
    kube-proxy = {}
    coredns    = {}
    aws-ebs-csi-driver = {
      pod_identity_association = [{
        role_arn        = module.ebs_csi_role.role_arn
        service_account = "ebs-csi-controller-sa"
      }]
    }
  }

  eks_managed_node_groups = {
    default = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = var.node_instance_types
      capacity_type  = var.node_capacity_type
      min_size       = var.node_min_size
      max_size       = var.node_max_size
      desired_size   = var.node_desired_size

      update_config = { max_unavailable_percentage = 33 }

      # IMDSv2 only, hop limit 1: pods cannot reach the node's instance credentials.
      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 1
      }

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 50
            volume_type           = "gp3"
            encrypted             = true
            delete_on_termination = true
          }
        }
      }

      iam_role_additional_policies = {
        ssm = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore" # shell via SSM, no SSH keys / bastion
      }
    }
  }
}

############ Database + secrets ############
module "rds" {
  source                     = "../rds"
  identifier                 = "${local.cluster_name}-db"
  vpc_id                     = module.vpc.vpc_id
  db_subnet_group_name       = module.vpc.database_subnet_group_name
  allowed_security_group_ids = [module.eks.node_security_group_id]
  instance_class             = var.db_instance_class
  multi_az                   = var.db_multi_az
  backup_retention_days      = var.db_backup_retention_days
  deletion_protection        = var.db_deletion_protection
}

resource "random_password" "flask_secret_key" {
  length  = 64
  special = false
}

resource "aws_secretsmanager_secret" "app" {
  name                    = "${var.name}/${var.environment}/app"
  description             = "Flask SECRET_KEY for ${local.cluster_name}"
  recovery_window_in_days = var.environment == "prod" ? 30 : 0
}

resource "aws_secretsmanager_secret_version" "app" {
  secret_id     = aws_secretsmanager_secret.app.id
  secret_string = jsonencode({ secret_key = random_password.flask_secret_key.result })
}

############ Pod Identity roles for platform controllers ############
module "alb_controller" {
  source          = "../pod-identity"
  name            = "${local.cluster_name}-aws-lb-controller"
  create_policy   = true
  cluster_name    = module.eks.cluster_name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  policy_json     = file("${path.module}/../pod-identity/aws-load-balancer-controller-policy.json")
}

data "aws_iam_policy_document" "external_secrets" {
  statement {
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [module.rds.master_user_secret_arn, aws_secretsmanager_secret.app.arn]
  }
}

module "external_secrets" {
  source          = "../pod-identity"
  name            = "${local.cluster_name}-external-secrets"
  create_policy   = true
  cluster_name    = module.eks.cluster_name
  namespace       = "external-secrets"
  service_account = "external-secrets"
  policy_json     = data.aws_iam_policy_document.external_secrets.json
}

data "aws_iam_policy_document" "external_dns" {
  count = local.manage_dns ? 1 : 0

  statement {
    actions   = ["route53:ChangeResourceRecordSets"]
    resources = ["arn:aws:route53:::hostedzone/${var.route53_zone_id}"]
  }

  statement {
    actions   = ["route53:ListHostedZones", "route53:ListResourceRecordSets", "route53:ListTagsForResources"]
    resources = ["*"]
  }
}

module "external_dns" {
  count           = local.manage_dns ? 1 : 0
  source          = "../pod-identity"
  name            = "${local.cluster_name}-external-dns"
  create_policy   = true
  cluster_name    = module.eks.cluster_name
  namespace       = "external-dns"
  service_account = "external-dns"
  policy_json     = data.aws_iam_policy_document.external_dns[0].json
}

############ TLS (ACM, DNS-validated). The ALB terminates TLS; cert-manager is not needed. ############
resource "aws_acm_certificate" "app" {
  count             = local.manage_dns ? 1 : 0
  domain_name       = var.app_hostname
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "acm_validation" {
  for_each = local.manage_dns ? {
    for o in aws_acm_certificate.app[0].domain_validation_options : o.domain_name => o
  } : {}

  zone_id         = var.route53_zone_id
  name            = each.value.resource_record_name
  type            = each.value.resource_record_type
  records         = [each.value.resource_record_value]
  ttl             = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "app" {
  count                   = local.manage_dns ? 1 : 0
  certificate_arn         = aws_acm_certificate.app[0].arn
  validation_record_fqdns = [for r in aws_route53_record.acm_validation : r.fqdn]
}
