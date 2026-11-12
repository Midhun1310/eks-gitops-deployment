variable "name" {
  description = "Resource name prefix, e.g. mk"
  type        = string
  default     = "mk"
}

variable "environment" {
  type = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging or prod."
  }
}

variable "region" {
  type = string
}

variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "az_count" {
  description = "Number of AZs (2 for dev, 3 for prod)"
  type        = number
  default     = 2
}

variable "single_nat_gateway" {
  description = "true = one shared NAT (cheap, single point of failure); false = one NAT per AZ"
  type        = bool
  default     = true
}

variable "enable_vpc_flow_logs" {
  type    = bool
  default = false
}

variable "kubernetes_version" {
  description = "EKS minor version. Check the EKS version calendar - standard support is 14 months."
  type        = string
  default     = "1.35"
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDRs allowed to reach the public Kubernetes API endpoint"
  type        = list(string)

  validation {
    condition     = alltrue([for c in var.cluster_endpoint_public_access_cidrs : can(cidrnetmask(c))])
    error_message = "Every entry must be a valid IPv4 CIDR (e.g. 203.0.113.10/32)."
  }
}

variable "cluster_admin_role_arns" {
  description = "Extra IAM roles (e.g. SSO admin role) granted cluster-admin via EKS access entries"
  type        = list(string)
  default     = []
}

variable "node_instance_types" {
  type    = list(string)
  default = ["t3.large"]
}

variable "node_capacity_type" {
  type    = string
  default = "ON_DEMAND"
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 4
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "db_instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "db_multi_az" {
  type    = bool
  default = false
}

variable "db_backup_retention_days" {
  type    = number
  default = 7
}

variable "db_deletion_protection" {
  type    = bool
  default = false
}

variable "app_hostname" {
  description = "Public hostname for the app, e.g. mk.dev.example.com. Empty = ALB DNS name over HTTP."
  type        = string
  default     = ""
}

variable "route53_zone_id" {
  description = "Hosted zone that contains app_hostname (for ACM validation + ExternalDNS). Empty = skip."
  type        = string
  default     = ""
}

variable "ecr_registry" {
  description = "<account>.dkr.ecr.<region>.amazonaws.com (output of the bootstrap stack)"
  type        = string
}

variable "app_namespace" {
  type    = string
  default = "mk"
}
