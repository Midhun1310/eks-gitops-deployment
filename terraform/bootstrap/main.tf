# Account-level foundation. Applied ONCE by a human with admin rights, with LOCAL state
# (it creates the bucket that every other stack uses for remote state).
provider "aws" {
  region = var.region

  default_tags {
    tags = { Project = "mk-platform", ManagedBy = "terraform", Stack = "bootstrap" }
  }
}

data "aws_caller_identity" "current" {}

locals {
  account_id  = data.aws_caller_identity.current.account_id
  bucket_name = "${var.name_prefix}-tfstate-${local.account_id}"
}

############ Remote state ############
resource "aws_s3_bucket" "tfstate" {
  bucket = local.bucket_name

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"
    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

data "aws_iam_policy_document" "tfstate_tls_only" {
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.tfstate.arn, "${aws_s3_bucket.tfstate.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  policy = data.aws_iam_policy_document.tfstate_tls_only.json
}

############ Container registry (shared by all environments: build once, promote the same digest) ############
module "ecr" {
  source       = "../modules/ecr"
  prefix       = var.name_prefix
  repositories = ["backend", "frontend"]
}

############ GitHub Actions -> AWS (OIDC, no long-lived keys) ############
data "aws_iam_policy_document" "ecr_push" {
  statement {
    sid       = "Login"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "Push"
    actions = [
      "ecr:BatchCheckLayerAvailability", "ecr:BatchGetImage", "ecr:CompleteLayerUpload",
      "ecr:GetDownloadUrlForLayer", "ecr:InitiateLayerUpload", "ecr:PutImage",
      "ecr:UploadLayerPart", "ecr:DescribeImages", "ecr:DescribeImageScanFindings",
    ]
    resources = values(module.ecr.repository_arns)
  }
}

data "aws_iam_policy_document" "tf_state_rw" {
  statement {
    sid       = "StateBucketList"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.tfstate.arn]
  }

  statement {
    sid       = "StateObjects"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.tfstate.arn}/*"]
  }
}

module "github_oidc" {
  source            = "../modules/github-oidc"
  github_repository = var.github_repository
  name_prefix       = var.name_prefix

  roles = {
    # Runs on pushes to main: build + push images only.
    "ci-ecr-push" = {
      description        = "GitHub Actions: push images to ECR"
      subjects           = ["ref:refs/heads/main"]
      has_inline_policy  = true
      inline_policy_json = data.aws_iam_policy_document.ecr_push.json
    }

    # Runs on pull requests: read-only AWS + state access so `terraform plan` can run.
    "terraform-plan" = {
      description         = "GitHub Actions: terraform plan (read-only)"
      subjects            = ["pull_request"]
      managed_policy_arns = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
      has_inline_policy   = true
      inline_policy_json  = data.aws_iam_policy_document.tf_state_rw.json
    }

    # One apply role per GitHub *Environment*. Protect the environments in repo settings
    # (required reviewers on prod) - that approval is what gates these roles.
    # AdministratorAccess keeps this readable; tighten with a permissions boundary for real orgs.
    "terraform-apply-dev" = {
      description         = "GitHub Actions: terraform apply (dev environment)"
      subjects            = ["environment:dev"]
      managed_policy_arns = ["arn:aws:iam::aws:policy/AdministratorAccess"]
    }

    "terraform-apply-prod" = {
      description         = "GitHub Actions: terraform apply (prod environment)"
      subjects            = ["environment:prod"]
      managed_policy_arns = ["arn:aws:iam::aws:policy/AdministratorAccess"]
    }
  }
}
