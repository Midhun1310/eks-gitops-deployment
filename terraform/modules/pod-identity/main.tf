# IAM role for a Kubernetes ServiceAccount via EKS Pod Identity (no IRSA annotations,
# no per-cluster OIDC trust to maintain - the original repo hard-coded OIDC IDs in JSON files).
data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = var.name
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_policy" "this" {
  count  = var.create_policy ? 1 : 0
  name   = var.name
  policy = var.policy_json
}

resource "aws_iam_role_policy_attachment" "custom" {
  count      = var.create_policy ? 1 : 0
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this[0].arn
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each   = toset(var.managed_policy_arns)
  role       = aws_iam_role.this.name
  policy_arn = each.value
}

resource "aws_eks_pod_identity_association" "this" {
  count           = var.create_association ? 1 : 0
  cluster_name    = var.cluster_name
  namespace       = var.namespace
  service_account = var.service_account
  role_arn        = aws_iam_role.this.arn
}
