variable "github_repository" {
  description = "org/repo that is allowed to assume the roles"
  type        = string
}

variable "name_prefix" {
  type = string
}

variable "roles" {
  description = "Roles to create. subjects are the OIDC 'sub' suffixes after 'repo:<org>/<repo>:' (e.g. ref:refs/heads/main, pull_request, environment:prod)."
  type = map(object({
    description         = string
    subjects            = list(string)
    managed_policy_arns = optional(list(string), [])
    has_inline_policy   = optional(bool, false) # must be explicit: the JSON may be unknown at plan time
    inline_policy_json  = optional(string)
  }))
}
