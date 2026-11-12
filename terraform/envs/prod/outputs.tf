output "cluster_name" {
  value = module.platform.cluster_name
}

output "cluster_facts" {
  value = module.platform.cluster_facts
}

output "kubeconfig_command" {
  value = "aws eks update-kubeconfig --name ${module.platform.cluster_name} --region ${var.region}"
}
