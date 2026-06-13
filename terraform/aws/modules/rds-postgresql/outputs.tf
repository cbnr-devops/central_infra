output "db_endpoint" {
  description = "RDS endpoint hostname"
  value       = aws_db_instance.this.address
}

output "db_port" {
  description = "RDS endpoint port"
  value       = aws_db_instance.this.port
}

output "db_identifier" {
  description = "RDS instance identifier"
  value       = aws_db_instance.this.id
}

output "secret_arn" {
  description = "ARN of the Secrets Manager secret containing DB credentials"
  value       = aws_secretsmanager_secret.db.arn
}