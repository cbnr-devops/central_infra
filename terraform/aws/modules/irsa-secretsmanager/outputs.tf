output "role_arn" {
  description = "IAM role ARN to use with IRSA"
  value       = aws_iam_role.this.arn
}

output "service_account_annotation" {
  description = "Annotation value to put on the Kubernetes service account"
  value       = aws_iam_role.this.arn
}