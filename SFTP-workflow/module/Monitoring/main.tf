

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "application_logs" {
  name              = "/aws/${var.environment}/application"
  retention_in_days = var.log_retention_days
  tags             = var.common_tags
}

resource "aws_cloudwatch_log_group" "audit_logs" {
  name              = "/aws/${var.environment}/audit"
  retention_in_days = var.audit_log_retention_days
  tags             = var.common_tags
}

# SNS Topics for Alerts
resource "aws_sns_topic" "critical_alerts" {
  name = "${var.environment}-critical-alerts"
  tags = var.common_tags
}

resource "aws_sns_topic" "warning_alerts" {
  name = "${var.environment}-warning-alerts"
  tags = var.common_tags
}

# SNS Topic Subscriptions
resource "aws_sns_topic_subscription" "critical_alerts_email" {
  for_each  = toset(var.critical_alert_emails)
  topic_arn = aws_sns_topic.critical_alerts.arn
  protocol  = "email"
  endpoint  = each.value
}

resource "aws_sns_topic_subscription" "warning_alerts_email" {
  for_each  = toset(var.warning_alert_emails)
  topic_arn = aws_sns_topic.warning_alerts.arn
  protocol  = "email"
  endpoint  = each.value
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.environment}-operations-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/States", "ExecutionsStarted", "StateMachineArn", aws_sfn_state_machine.document_processing.id],
            ["AWS/States", "ExecutionsSucceeded", "StateMachineArn", aws_sfn_state_machine.document_processing.id],
            ["AWS/States", "ExecutionsFailed", "StateMachineArn", aws_sfn_state_machine.document_processing.id]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Step Functions Executions"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/Textract", "SuccessfulJobCount", "Operation", "StartDocumentAnalysis"],
            ["AWS/Textract", "FailedJobCount", "Operation", "StartDocumentAnalysis"],
            ["AWS/Textract", "ResponseTime", "Operation", "StartDocumentAnalysis"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Textract Performance"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.pdf_processor.function_name],
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.pdf_processor.function_name],
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.pdf_processor.function_name]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Lambda Performance"
          period  = 300
        }
      },
      {
        type   = "log"
        x      = 12
        y      = 6
        width  = 12
        height = 6

        properties = {
          query   = "fields @timestamp, @message | filter @message like /ERROR/"
          region  = var.aws_region
          title   = "Error Logs"
          view    = "table"
        }
      }
    ]
  })
}

# CloudWatch Alarms

# Step Functions Alarms
resource "aws_cloudwatch_metric_alarm" "step_functions_failed" {
  alarm_name          = "${var.environment}-step-functions-failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "ExecutionsFailed"
  namespace           = "AWS/States"
  period             = "300"
  statistic          = "Sum"
  threshold          = "0"
  alarm_description  = "Step Functions execution failures detected"
  alarm_actions      = [aws_sns_topic.critical_alerts.arn]

  dimensions = {
    StateMachineArn = aws_sfn_state_machine.document_processing.id
  }
}

# Lambda Alarms
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.environment}-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period             = "300"
  statistic          = "Sum"
  threshold          = "0"
  alarm_description  = "Lambda function errors detected"
  alarm_actions      = [aws_sns_topic.critical_alerts.arn]

  dimensions = {
    FunctionName = aws_lambda_function.pdf_processor.function_name
  }
}

# Textract Alarms
resource "aws_cloudwatch_metric_alarm" "textract_failures" {
  alarm_name          = "${var.environment}-textract-failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "FailedJobCount"
  namespace           = "AWS/Textract"
  period             = "300"
  statistic          = "Sum"
  threshold          = "0"
  alarm_description  = "Textract job failures detected"
  alarm_actions      = [aws_sns_topic.critical_alerts.arn]

  dimensions = {
    Operation = "StartDocumentAnalysis"
  }
}

# DynamoDB Alarms
resource "aws_cloudwatch_metric_alarm" "dynamodb_throttles" {
  alarm_name          = "${var.environment}-dynamodb-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "ThrottledRequests"
  namespace           = "AWS/DynamoDB"
  period             = "300"
  statistic          = "Sum"
  threshold          = "0"
  alarm_description  = "DynamoDB throttling detected"
  alarm_actions      = [aws_sns_topic.warning_alerts.arn]

  dimensions = {
    TableName = aws_dynamodb_table.audit_trail.id
  }
}

# Audit Logging Configuration
resource "aws_cloudwatch_log_metric_filter" "audit_events" {
  name           = "${var.environment}-audit-events"
  pattern        = "[timestamp, event_type, user, action, resource]"
  log_group_name = aws_cloudwatch_log_group.audit_logs.name

  metric_transformation {
    name      = "AuditEvents"
    namespace = "Custom/Audit"
    value     = "1"
  }
}

# CloudWatch Metrics for Audit Events
resource "aws_cloudwatch_metric_alarm" "audit_events_threshold" {
  alarm_name          = "${var.environment}-audit-events-threshold"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "AuditEvents"
  namespace           = "Custom/Audit"
  period             = "300"
  statistic          = "Sum"
  threshold          = var.audit_events_threshold
  alarm_description  = "High number of audit events detected"
  alarm_actions      = [aws_sns_topic.warning_alerts.arn]
}

# CloudWatch Insights Query
resource "aws_cloudwatch_query_definition" "error_analysis" {
  name = "${var.environment}-error-analysis"

  log_group_names = [
    aws_cloudwatch_log_group.application_logs.name,
    aws_cloudwatch_log_group.audit_logs.name
  ]

  query_string = <<EOF
fields @timestamp, @message
| filter @message like /ERROR/
| stats count(*) as error_count by bin(30m)
| sort error_count desc
EOF
}

# Custom Metrics for Business KPIs
resource "aws_cloudwatch_log_metric_filter" "processing_time" {
  name           = "${var.environment}-processing-time"
  pattern        = "[timestamp, processing_time, document_id]"
  log_group_name = aws_cloudwatch_log_group.application_logs.name

  metric_transformation {
    name      = "ProcessingTime"
    namespace = "Custom/Processing"
    value     = "$processing_time"
  }
}
