provider "aws" {
  region = var.aws_region
}

# S3 Bucket for Textract Results
resource "aws_s3_bucket" "textract_output" {
  bucket = "${var.environment}-textract-output"
  tags   = var.common_tags
}

# SNS Topic for Textract Completion Notifications
resource "aws_sns_topic" "textract_completion" {
  name = "${var.environment}-textract-completion"
  tags = var.common_tags
}

# SQS Queue for Textract Job Management
resource "aws_sqs_queue" "textract_jobs" {
  name                       = "${var.environment}-textract-jobs"
  visibility_timeout_seconds = 900
  message_retention_seconds  = 86400
  delay_seconds             = 0
  tags                      = var.common_tags
}

# Dead Letter Queue for Failed Jobs
resource "aws_sqs_queue" "textract_dlq" {
  name                       = "${var.environment}-textract-dlq"
  message_retention_seconds  = 1209600 # 14 days
  tags                      = var.common_tags
}

# IAM Role for Textract
resource "aws_iam_role" "textract_role" {
  name = "${var.environment}-textract-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "textract.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for Textract (referencing the external JSON file)
resource "aws_iam_role_policy" "textract_policy" {
  name = "${var.environment}-textract-policy"
  role = aws_iam_role.textract_role.id

  policy = file("${path.module}/policies/textract_policy.json")
}

# Lambda Function for PDF Chunking and Processing
resource "aws_lambda_function" "pdf_processor" {
  filename         = "pdf_processor.zip"
  function_name    = "${var.environment}-pdf-processor"
  role             = aws_iam_role.lambda_role.arn
  handler          = "pdf_processor.handler"
  runtime          = "python3.9"
  timeout          = 900
  memory_size      = 1024

  environment {
    variables = {
      OUTPUT_BUCKET     = aws_s3_bucket.textract_output.id
      SNS_TOPIC_ARN    = aws_sns_topic.textract_completion.arn
      SQS_QUEUE_URL    = aws_sqs_queue.textract_jobs.url
      MAX_PAGES_CHUNK  = "100"
      ENVIRONMENT      = var.environment
    }
  }

  tags = var.common_tags
}

# Lambda Code Packaging
resource "archive_file" "pdf_processor_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_code"
  output_path = "${path.module}/pdf_processor.zip"
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "${var.environment}-pdf-processor-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for Lambda (referencing the external JSON file)
resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.environment}-lambda-policy"
  role = aws_iam_role.lambda_role.id

  policy = file("${path.module}/policies/lambda_policy.json")
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "pdf_processor" {
  name              = "/aws/lambda/${aws_lambda_function.pdf_processor.function_name}"
  retention_in_days = 30
  tags             = var.common_tags
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "textract_errors" {
  alarm_name          = "${var.environment}-textract-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Textract"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "Textract processing errors"
  alarm_actions       = [aws_sns_topic.textract_completion.arn]

  dimensions = {
    Operation = "StartDocumentAnalysis"
  }
}
# Step Functions Task for Textract Processing
resource "aws_sfn_state_machine" "textract_processor" {
  name     = "${var.environment}-textract-processor"
  role_arn = aws_iam_role.step_functions_role.arn

  definition = jsonencode({
    StartAt = "InitializeProcessing"
    States = {
      InitializeProcessing = {
        Type = "Task"
        Resource = aws_lambda_function.pdf_processor.arn
        Next = "WaitForCompletion"
        Retry = [
          {
            ErrorEquals = ["States.ALL"]
            IntervalSeconds = 30
            MaxAttempts = 3
            BackoffRate = 2.0
          }
        ]
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            Next = "HandleError"
          }
        ]
      }
      WaitForCompletion = {
        Type = "Wait"
        Seconds = 30
        Next = "CheckStatus"
      }
      CheckStatus = {
        Type = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.check_status.arn
          Payload = {
            "job_id.$": "$.job_id"
          }
        }
        Next = "IsComplete"
      }
      IsComplete = {
        Type = "Choice"
        Choices = [
          {
            Variable = "$.status"
            StringEquals = "SUCCEEDED"
            Next = "ProcessResults"
          },
          {
            Variable = "$.status"
            StringEquals = "IN_PROGRESS"
            Next = "WaitForCompletion"
          }
        ],
        Default = "HandleError"
      }
      ProcessResults = {
        Type = "Task"
        Resource = aws_lambda_function.process_results.arn
        End = true
      }
      HandleError = {
        Type = "Task"
        Resource = aws_lambda_function.handle_error.arn
        End = true
      }
    }
  })
}
