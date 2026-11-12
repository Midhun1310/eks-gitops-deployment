resource "aws_security_group" "this" {
  name_prefix = "${var.identifier}-"
  description = "PostgreSQL access from EKS nodes only"
  vpc_id      = var.vpc_id

  lifecycle {
    create_before_destroy = true
  }
}

# Only the EKS node security group may reach 5432. (Original: 0.0.0.0/0.)
resource "aws_vpc_security_group_ingress_rule" "from_sg" {
  for_each                     = toset(var.allowed_security_group_ids)
  security_group_id            = aws_security_group.this.id
  referenced_security_group_id = each.value
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  description                  = "PostgreSQL from EKS nodes"
}

resource "aws_db_parameter_group" "this" {
  name_prefix = "${var.identifier}-"
  family      = "postgres${var.engine_major_version}"

  parameter {
    name  = "rds.force_ssl"
    value = "1" # reject non-TLS connections
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000" # log queries slower than 1s
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_instance" "this" {
  identifier     = var.identifier
  engine         = "postgres"
  engine_version = var.engine_major_version
  instance_class = var.instance_class

  db_name  = var.db_name
  username = var.admin_username
  port     = 5432

  # RDS creates the master password in Secrets Manager and rotates it. Nothing sensitive
  # ever lands in Terraform state, tfvars or a K8s manifest.
  manage_master_user_password = true

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  multi_az               = var.multi_az
  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = [aws_security_group.this.id]
  parameter_group_name   = aws_db_parameter_group.this.name
  publicly_accessible    = false

  backup_retention_period             = var.backup_retention_days
  backup_window                       = "21:00-22:00"
  maintenance_window                  = "sun:22:30-sun:23:30"
  copy_tags_to_snapshot               = true
  deletion_protection                 = var.deletion_protection
  skip_final_snapshot                 = !var.deletion_protection
  final_snapshot_identifier           = var.deletion_protection ? "${var.identifier}-final" : null
  auto_minor_version_upgrade          = true
  iam_database_authentication_enabled = true
  enabled_cloudwatch_logs_exports     = ["postgresql", "upgrade"]

  performance_insights_enabled = true # 7-day retention is free
  apply_immediately            = !var.deletion_protection

  lifecycle {
    ignore_changes = [engine_version] # minor versions are upgraded by RDS
  }
}
