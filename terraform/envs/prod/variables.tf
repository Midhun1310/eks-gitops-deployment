variable "region" {
  type    = string
  default = "ap-south-1"
}

variable "ecr_registry" {
  description = "Output 'ecr_registry' of the bootstrap stack"
  type        = string
}

variable "vpc_cidr" { type = string }
variable "az_count" { type = number }
variable "single_nat_gateway" { type = bool }
variable "enable_vpc_flow_logs" { type = bool }

variable "kubernetes_version" { type = string }
variable "cluster_endpoint_public_access_cidrs" { type = list(string) }

variable "cluster_admin_role_arns" {
  type    = list(string)
  default = []
}

variable "node_instance_types" { type = list(string) }
variable "node_capacity_type" { type = string }
variable "node_min_size" { type = number }
variable "node_max_size" { type = number }
variable "node_desired_size" { type = number }

variable "db_instance_class" { type = string }
variable "db_multi_az" { type = bool }
variable "db_backup_retention_days" { type = number }
variable "db_deletion_protection" { type = bool }

variable "app_hostname" {
  type    = string
  default = ""
}

variable "route53_zone_id" {
  type    = string
  default = ""
}
