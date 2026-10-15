output "address" {
  description = "Database hostname"
  value       = aws_db_instance.this.address
}

output "port" {
  description = "Database port"
  value       = aws_db_instance.this.port
}

output "database_name" {
  description = "Initial database name"
  value       = aws_db_instance.this.db_name
}

output "master_user_secret_arn" {
  description = "Secrets Manager secret holding the master credentials"
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}

output "security_group_id" {
  description = "Security group attached to the instance"
  value       = aws_security_group.this.id
}

output "kms_key_arn" {
  description = "KMS key used for storage and the master secret"
  value       = aws_kms_key.this.arn
}

output "instance_id" {
  description = "Instance identifier"
  value       = aws_db_instance.this.id
}
