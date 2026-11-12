# ecr_registry is supplied by the Makefile / CI from the bootstrap output (-var).
region               = "ap-south-1"
vpc_cidr             = "10.20.0.0/16"
az_count             = 2
single_nat_gateway   = true # cost: one NAT. NOT highly available - fine for dev.
enable_vpc_flow_logs = false

kubernetes_version = "1.35"
# Restrict to your public IP, e.g. ["203.0.113.10/32"]. Open here so GitHub-hosted runners can reach
# the API for kubectl-based checks; ArgoCD pulls from Git so day-to-day deploys need no API access.
cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]

node_instance_types = ["t3.large"]
node_capacity_type  = "ON_DEMAND"
node_min_size       = 2
node_max_size       = 4
node_desired_size   = 2

db_instance_class        = "db.t4g.micro"
db_multi_az              = false
db_backup_retention_days = 1
db_deletion_protection   = false

# Optional custom domain + HTTPS. Leave empty to use the ALB DNS name over HTTP.
app_hostname    = ""
route53_zone_id = ""
