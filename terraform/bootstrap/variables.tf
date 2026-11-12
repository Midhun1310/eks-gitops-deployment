variable "region" {
  type    = string
  default = "ap-south-1"
}

variable "name_prefix" {
  type    = string
  default = "mk-platform"
}

variable "github_repository" {
  description = "GitHub repository in org/repo form that CI runs in"
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "Use the form org/repo."
  }
}
