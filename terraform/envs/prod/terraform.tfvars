region               = "ap-south-1"
vpc_cidr             = "10.30.0.0/16"
az_count             = 3
single_nat_gateway   = false # one NAT per AZ
enable_vpc_flow_logs = true

kubernetes_version = "1.35"
# REQUIRED: replace with your office/VPN egress CIDR(s). The placeholder below is intentionally
# invalid so `terraform plan` fails until you do.
cluster_endpoint_public_access_cidrs = ["REPLACE_ME/32"]

node_instance_types = ["m6i.large"]
node_capacity_type  = "ON_DEMAND"
node_min_size       = 3
node_max_size       = 9
node_desired_size   = 3

db_instance_class        = "db.t4g.medium"
db_multi_az              = true
db_backup_retention_days = 14
db_deletion_protection   = true

app_hostname    = "mk.example.com"
route53_zone_id = "Z0000000000000EXAMPLE"
