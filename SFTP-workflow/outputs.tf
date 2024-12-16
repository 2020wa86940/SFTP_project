# outputs.tf - Root outputs file

output "sftp_endpoint" {
  description = "SFTP server endpoint"
  value       = module.storage.sftp_endpoint
}

output "dashboard_url" {
  description = "CloudWatch dashboard URL"
  value       = module.monitoring.dashboard_url
}

output "alert_topic_arn" {
  description = "SNS topic ARN for alerts"
  value       = module.monitoring.alert_topic_arn
}
