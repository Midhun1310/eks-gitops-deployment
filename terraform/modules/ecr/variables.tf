variable "prefix" {
  description = "Repository namespace, e.g. mk-platform -> mk-platform/backend"
  type        = string
}

variable "repositories" {
  description = "Repository names to create"
  type        = list(string)
}

variable "keep_images" {
  description = "How many tagged images to retain per repository"
  type        = number
  default     = 30
}

variable "force_delete" {
  description = "Allow terraform destroy to delete repos that still contain images"
  type        = bool
  default     = false
}
