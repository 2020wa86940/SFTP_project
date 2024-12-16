# main.tf

provider "aws" {
  region = var.aws_region
}

# IAM Role for Step Functions
resource "aws_iam_role" "step_functions_role" {
  name = "${var.environment}-step-functions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for Step Functions
resource "aws_iam_role_policy" "step_functions_policy" {
  name = "${var.environment}-step-functions-policy"
  role = aws_iam_role.step_functions_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction",
          "textract:*",
          "sns:Publish",
          "dynamodb:*",
          "s3:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# Step Functions State Machine
resource "aws_sfn_state_machine" "document_processing" {
  name     = "${var.environment}-document-processing"
  role_arn = aws_iam_role.step_functions_role.arn

  definition = jsonencode({
    Comment = "Document Processing Workflow"
    StartAt = "FileValidation"
    States = {
      FileValidation = {
        Type = "Task"
        Resource = aws_lambda_function.validate_file.arn
        Next = "CheckValidationResult"
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next = "HandleValidationError"
        }]
      }

      CheckValidationResult = {
        Type = "Choice"
        Choices = [
          {
            Variable = "$.isValid"
            BooleanEquals = true
            Next = "PDFProcessing"
          },
          {
            Variable = "$.isValid"
            BooleanEquals = false
            Next = "HandleValidationError"
          }
        ]
      }

      HandleValidationError = {
        Type = "Task"
        Resource = aws_lambda_function.handle_error.arn
        Next = "SendErrorNotification"
      }

      PDFProcessing = {
        Type = "Task"
        Resource = "arn:aws:states:::textract:startDocumentAnalysis"
        Parameters = {
          DocumentLocation = {
            S3Object = {
              Bucket = "$.bucket"
              Name = "$.key"
            }
          }
          FeatureTypes = ["TABLES", "FORMS"]
        }
        Next = "WaitForTextractCompletion"
      }

      WaitForTextractCompletion = {
        Type = "Wait"
        Seconds = 30
        Next = "CheckTextractStatus"
      }

      CheckTextractStatus = {
        Type = "Task"
        Resource = "arn:aws:states:::textract:getDocumentAnalysis"
        Next = "TextractStatusChoice"
      }

      TextractStatusChoice = {
        Type = "Choice"
        Choices = [
          {
            Variable = "$.JobStatus"
            StringEquals = "SUCCEEDED"
            Next = "DataExtraction"
          },
          {
            Variable = "$.JobStatus"
            StringEquals = "IN_PROGRESS"
            Next = "WaitForTextractCompletion"
          }
        ],
        Default = "HandleProcessingError"
      }

      DataExtraction = {
        Type = "Task"
        Resource = aws_lambda_function.extract_data.arn
        Next = "StoreRawData"
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next = "HandleProcessingError"
        }]
      }

      StoreRawData = {
        Type = "Task"
        Resource = aws_lambda_function.store_data.arn
        Next = "DataComparison"
      }

      DataComparison = {
        Type = "Task"
        Resource = aws_lambda_function.compare_data.arn
        Next = "ReportGeneration"
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next = "HandleComparisonError"
        }]
      }

      ReportGeneration = {
        Type = "Task"
        Resource = aws_lambda_function.generate_report.arn
        Next = "StoreReport"
      }

      StoreReport = {
        Type = "Task"
        Resource = aws_lambda_function.store_report.arn
        Next = "SendSuccessNotification"
      }

      SendSuccessNotification = {
        Type = "Task"
        Resource = "arn:aws:states:::sns:publish"
        Parameters = {
          TopicArn = aws_sns_topic.processing_notifications.arn
          Message = {
            "status": "success"
            "reportLocation": "$.reportLocation"
          }
        }
        End = true
      }

      SendErrorNotification = {
        Type = "Task"
        Resource = "arn:aws:states:::sns:publish"
        Parameters = {
          TopicArn = aws_sns_topic.processing_notifications.arn
          Message = {
            "status": "error"
            "error": "$.error"
          }
        }
        End = true
      }

      HandleProcessingError = {
        Type = "Task"
        Resource = aws_lambda_function.handle_error.arn
        Next = "SendErrorNotification"
      }

      HandleComparisonError = {
        Type = "Task"
        Resource = aws_lambda_function.handle_error.arn
        Next = "SendErrorNotification"
      }
    }
  })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.step_functions.arn}:*"
    include_execution_data = true
    level                 = "ALL"
  }

  tracing_configuration {
    enabled = true
  }

  tags = var.common_tags
}

# CloudWatch Log Group for Step Functions
resource "aws_cloudwatch_log_group" "step_functions" {
  name              = "/aws/stepfunctions/${var.environment}-document-processing"
  retention_in_days = 30
  tags             = var.common_tags
}

# SNS Topic for notifications
resource "aws_sns_topic" "processing_notifications" {
  name = "${var.environment}-processing-notifications"
  tags = var.common_tags
}

# CloudWatch Metrics and Alarms
resource "aws_cloudwatch_metric_alarm" "step_functions_failed" {
  alarm_name          = "${var.environment}-step-functions-failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "ExecutionsFailed"
  namespace           = "AWS/States"
  period             = "300"
  statistic          = "Sum"
  threshold          = "0"
  alarm_description  = "Step Functions execution failures"
  alarm_actions      = [aws_sns_topic.processing_notifications.arn]

  dimensions = {
    StateMachineArn = aws_sfn_state_machine.document_processing.id
  }
}

# X-Ray Tracing
resource "aws_iam_role_policy_attachment" "step_functions_xray" {
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
  role       = aws_iam_role.step_functions_role.name
}
