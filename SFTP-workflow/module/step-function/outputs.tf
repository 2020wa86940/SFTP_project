# outputs.tf

output "state_machine_arn" {
  description = "ARN of the Step Functions state machine"
  value       = aws_sfn_state_machine.document_processing.arn
}

output "notification_topic_arn" {
  description = "ARN of the SNS notification topic"
  value       = aws_sns_topic.processing_notifications.arn
}

output "cloudwatch_log_group" {
  description = "Name of the CloudWatch Log Group"
  value       = aws_cloudwatch_log_group.step_functions.name
}
