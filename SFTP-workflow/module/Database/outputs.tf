# outputs.tf

output "participant_data_table_arn" {
  description = "ARN of the participant data table"
  value       = aws_dynamodb_table.participant_data.arn
}

output "audit_trail_table_arn" {
  description = "ARN of the audit trail table"
  value       = aws_dynamodb_table.audit_trail.arn
}

output "process_metadata_table_arn" {
  description = "ARN of the process metadata table"
  value       = aws_dynamodb_table.process_metadata.arn
}

output "backup_plan_arn" {
  description = "ARN of the backup plan"
  value       = aws_backup_plan.dynamodb_backup.arn
}

output "primary_backup_vault_arn" {
  description = "ARN of the primary backup vault"
  value       = aws_backup_vault.dynamodb_backup_vault.arn
}

output "secondary_backup_vault_arn" {
  description = "ARN of the secondary backup vault"
  value       = aws_backup_vault.dynamodb_backup_vault_secondary.arn
}
