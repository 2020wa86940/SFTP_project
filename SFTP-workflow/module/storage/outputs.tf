# outputs.tf

output "pdf_landing_bucket" {
  description = "PDF landing bucket name"
  value       = aws_s3_bucket.pdf_landing.id
}

output "excel_reference_bucket" {
  description = "Excel reference bucket name"
  value       = aws_s3_bucket.excel_reference.id
}

output "processed_files_bucket" {
  description = "Processed files bucket name"
  value       = aws_s3_bucket.processed_files.id
}

output "reports_bucket" {
  description = "Reports bucket name"
  value       = aws_s3_bucket.reports.id
}

output "sns_topic_arn" {
  description = "SNS Topic ARN for bucket notifications"
  value       = aws_sns_topic.bucket_notifications.arn
}
