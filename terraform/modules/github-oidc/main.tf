# One OIDC provider per AWS account. AWS validates GitHub's certificate chain itself,
# so no thumbprint is required (the original hard-coded one is obsolete).
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_policy_document" "assume" {
  for_each = var.roles

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Exact subject match (not "repo:org/repo:*"): the role can only be assumed from the
    # listed branch / environment / pull_request context of THIS repository.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [for s in each.value.subjects : "repo:${var.github_repository}:${s}"]
    }
  }
}

resource "aws_iam_role" "this" {
  for_each             = var.roles
  name                 = "${var.name_prefix}-${each.key}"
  description          = each.value.description
  assume_role_policy   = data.aws_iam_policy_document.assume[each.key].json
  max_session_duration = 3600
}

resource "aws_iam_role_policy" "inline" {
  for_each = { for k, r in var.roles : k => r if r.has_inline_policy }
  name     = "inline"
  role     = aws_iam_role.this[each.key].id
  policy   = each.value.inline_policy_json
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each = merge([
    for k, r in var.roles : { for arn in r.managed_policy_arns : "${k}|${arn}" => { role = k, arn = arn } }
  ]...)
  role       = aws_iam_role.this[each.value.role].name
  policy_arn = each.value.arn
}
