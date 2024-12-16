

# Provider configuration
provider "aws" {
  region = var.aws_region
}

# S3 bucket for SFTP landing zone
resource "aws_s3_bucket" "sftp_bucket" {
  bucket = var.sftp_bucket_name
}

# S3 bucket versioning
resource "aws_s3_bucket_versioning" "sftp_bucket_versioning" {
  bucket = aws_s3_bucket.sftp_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 bucket encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "sftp_bucket_encryption" {
  bucket = aws_s3_bucket.sftp_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# CloudWatch Log Group for SFTP server
resource "aws_cloudwatch_log_group" "sftp_log_group" {
  name              = "/aws/transfer/${var.sftp_server_name}"
  retention_in_days = var.log_retention_days
}

# IAM role for SFTP logging
resource "aws_iam_role" "sftp_logging_role" {
  name = "sftp-logging-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "transfer.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policy for SFTP logging
resource "aws_iam_role_policy" "sftp_logging_policy" {
  name = "sftp-logging-policy"
  role = aws_iam_role.sftp_logging_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.sftp_log_group.arn}:*"
      }
    ]
  })
}

# SFTP Server
resource "aws_transfer_server" "sftp" {
  identity_provider_type = "SERVICE_MANAGED"
  protocols             = ["SFTP"]
  domain               = "S3"
  
  endpoint_type = "PUBLIC"
  
  logging_role = aws_iam_role.sftp_logging_role.arn

  tags = {
    Name        = var.sftp_server_name
    Environment = var.environment
  }
}

# IAM role for SFTP users
resource "aws_iam_role" "sftp_user_role" {
  name = "sftp-user-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "transfer.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policy for SFTP users
resource "aws_iam_role_policy" "sftp_user_policy" {
  name = "sftp-user-policy"
  role = aws_iam_role.sftp_user_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowListingOfUserFolder"
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.sftp_bucket.arn
        ]
        Condition = {
          StringLike = {
            "s3:prefix" = ["$${transfer:UserName}/*", "$${transfer:UserName}"]
          }
        }
      },
      {
        Sid    = "HomeDirObjectAccess"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.sftp_bucket.arn}/$${transfer:UserName}/*"
      }
    ]
  })
}

# SFTP Users
resource "aws_transfer_user" "sftp_users" {
  for_each = var.sftp_users

  server_id = aws_transfer_server.sftp.id
  user_name = each.key
  role      = aws_iam_role.sftp_user_role.arn

  home_directory_type = "LOGICAL"
  home_directory_mappings {
    entry  = "/"
    target = "/${aws_s3_bucket.sftp_bucket.id}/$${transfer:UserName}"
  }

  tags = {
    Name        = each.key
    Environment = var.environment
  }
}

# SSH Keys for SFTP users
resource "aws_transfer_ssh_key" "user_ssh_keys" {
  for_each = var.sftp_users

  server_id = aws_transfer_server.sftp.id
  user_name = each.key
  body      = each.value.ssh_public_key
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "sftp_errors" {
  alarm_name          = "sftp-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Transfer"
  period             = "300"
  statistic          = "Sum"
  threshold          = "0"
  alarm_description  = "This metric monitors SFTP server errors"
  alarm_actions      = [aws_sns_topic.sftp_alerts.arn]

  dimensions = {
    ServerId = aws_transfer_server.sftp.id
  }
}

# SNS Topic for alerts
resource "aws_sns_topic" "sftp_alerts" {
  name = "sftp-alerts"
}

# SNS Topic subscription
resource "aws_sns_topic_subscription" "sftp_alerts_email" {
  topic_arn = aws_sns_topic.sftp_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}
