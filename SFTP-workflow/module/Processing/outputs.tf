

output "textract_output_bucket" {
  description = "Name of the Textract output bucket"
  value       = aws_s3_bucket.textract_output.id
}

output "textract_completion_topic" {
  description = "ARN of the Textract completion SNS topic"
  value       = aws_sns_topic.textract_completion.arn
}

output "textract_jobs_queue" {
  description = "URL of the Textract jobs SQS queue"
  value       = aws_sqs_queue.textract_jobs.url
}
