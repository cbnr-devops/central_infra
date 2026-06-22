output "adot_irsa_role_arn" {
  value = aws_iam_role.adot_irsa_role.arn
}

output "amp_workspace_arn" {
  value = aws_prometheus_workspace.this.arn
}

output "amp_workspace_id" {
  value = aws_prometheus_workspace.this.id
}

output "loki_bucket_name" {
  value = aws_s3_bucket.loki.bucket
}

output "loki_irsa_role_arn" {
  value = aws_iam_role.loki_irsa_role.arn
}