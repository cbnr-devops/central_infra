locals {
  oidc_provider = replace(var.cluster_oidc_issuer, "https://", "")

  common_tags = merge(
    {
      Environment = var.env
      Project     = "central-infra"
    },
    var.tags
  )

  sa_fqdn = "${var.service_account_namespace}:${var.service_account_name}"
}

resource "aws_iam_role" "this" {
  name = "central-${var.env}-irsa-${var.service_account_namespace}-${var.service_account_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.oidc_provider}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.oidc_provider}:sub" = "system:serviceaccount:${local.sa_fqdn}"
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "secretsmanager_read" {
  statement {
    sid    = "ReadDbSecrets"
    effect = "Allow"

    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]

    resources = var.secret_arns
  }
}

resource "aws_iam_policy" "this" {
  name        = "central-${var.env}-secretsmanager-read-${var.service_account_namespace}-${var.service_account_name}"
  description = "Allow reading specified Secrets Manager secrets for IRSA service account"

  policy = data.aws_iam_policy_document.secretsmanager_read.json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this.arn
}