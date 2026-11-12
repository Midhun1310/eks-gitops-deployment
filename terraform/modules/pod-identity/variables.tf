variable "name" {
  description = "IAM role (and policy) name"
  type        = string
}

variable "cluster_name" {
  type = string
}

variable "namespace" {
  type = string
}

variable "service_account" {
  type = string
}

variable "create_policy" {
  description = "Set true when policy_json is provided (must be known at plan time, so it is a separate flag)"
  type        = bool
  default     = false
}

variable "policy_json" {
  type    = string
  default = null
}

variable "managed_policy_arns" {
  type    = list(string)
  default = []
}

variable "create_association" {
  description = "false when an EKS addon creates the association itself (e.g. aws-ebs-csi-driver)"
  type        = bool
  default     = true
}
