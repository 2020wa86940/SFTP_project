

output "sftp_server_endpoint" {
  description = "SFTP server endpoint"
  value       = aws_transfer_server.sftp.endpoint
}

output "sftp_server_id" {
  description = "SFTP server ID"
  value       = aws_transfer_server.sftp.id
}

output "sftp_bucket_name" {
  description = "Name of the S3 bucket for SFTP"
  value       = aws_s3_bucket.sftp_bucket.id
}

output "cloudwatch_log_group" {
  description = "CloudWatch Log Group name"
  value       = aws_cloudwatch_log_group.sftp_log_group.name
}
