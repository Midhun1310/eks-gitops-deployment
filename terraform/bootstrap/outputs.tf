output "state_bucket" {
  value = aws_s3_bucket.tfstate.bucket
}

output "ecr_registry" {
  value = "${local.account_id}.dkr.ecr.${var.region}.amazonaws.com"
}

output "ecr_repository_urls" {
  value = module.ecr.repository_urls
}

output "github_role_arns" {
  description = "Set these as GitHub repo/environment variables (see docs/runbook.md)"
  value       = module.github_oidc.role_arns
}
