# security.tf

# KMS Key for Encryption
resource "aws_kms_key" "application_key" {
  description             = "${var.environment} application encryption key"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })

  tags = var.common_tags
}

resource "aws_kms_alias" "application_key_alias" {
  name          = "alias/${var.environment}-application-key"
  target_key_id = aws_kms_key.application_key.key_id
}

# VPC Configuration
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.common_tags, {
    Name = "${var.environment}-vpc"
  })
}

# Private Subnets
resource "aws_subnet" "private" {
  count             = length(var.private_subnets)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(var.common_tags, {
    Name = "${var.environment}-private-${count.index + 1}"
  })
}

# VPC Endpoints
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${var.aws_region}.s3"
  
  tags = merge(var.common_tags, {
    Name = "${var.environment}-s3-endpoint"
  })
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${var.aws_region}.dynamodb"
  
  tags = merge(var.common_tags, {
    Name = "${var.environment}-dynamodb-endpoint"
  })
}

# Security Groups
resource "aws_security_group" "lambda" {
  name_prefix = "${var.environment}-lambda-sg"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${var.environment}-lambda-sg"
  })
}

# IAM Roles and Policies

# Lambda Execution Role
resource "aws_iam_role" "lambda_execution" {
  name = "${var.environment}-lambda-execution-role"

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

  tags = var.common_tags
}

# Lambda Basic Execution Policy
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda VPC Access Policy
resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Custom Lambda Policy
resource "aws_iam_role_policy" "lambda_custom" {
  name = "${var.environment}-lambda-custom-policy"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "${aws_s3_bucket.pdf_landing.arn}",
          "${aws_s3_bucket.pdf_landing.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:Query",
          "dynamodb:UpdateItem"
        ]
        Resource = [
          aws_dynamodb_table.participant_data.arn,
          aws_dynamodb_table.audit_trail.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = [
          aws_kms_key.application_key.arn
        ]
      }
    ]
  })
}

# S3 Bucket Policies
resource "aws_s3_bucket_policy" "pdf_landing" {
  bucket = aws_s3_bucket.pdf_landing.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyUnencryptedObjectUploads"
        Effect = "Deny"
        Principal = "*"
        Action = "s3:PutObject"
        Resource = "${aws_s3_bucket.pdf_landing.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption": "aws:kms"
          }
        }
      },
      {
        Sid    = "DenyHTTP"
        Effect = "Deny"
        Principal = "*"
        Action = "s3:*"
        Resource = [
          aws_s3_bucket.pdf_landing.arn,
          "${aws_s3_bucket.pdf_landing.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport": "false"
          }
        }
      }
    ]
  })
}

# S3 Bucket Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "pdf_landing" {
  bucket = aws_s3_bucket.pdf_landing.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.application_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

# DynamoDB Encryption
resource "aws_dynamodb_table" "participant_data" {
  # ... other configurations ...

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.application_key.arn
  }
}

# WAF Web ACL
resource "aws_wafv2_web_acl" "main" {
  name        = "${var.environment}-web-acl"
  description = "Web ACL for API Gateway"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name               = "AWSManagedRulesCommonRuleSetMetric"
      sampled_requests_enabled  = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name               = "WebACLMetric"
    sampled_requests_enabled  = true
  }

  tags = var.common_tags
}

# CloudTrail
resource "aws_cloudtrail" "main" {
  name                          = "${var.environment}-cloudtrail"
  s3_bucket_name               = aws_s3_bucket.cloudtrail.id
  include_global_service_events = true
  is_multi_region_trail        = true
  enable_logging               = true
  kms_key_id                  = aws_kms_key.application_key.arn

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      values = ["${aws_s3_bucket.pdf_landing.arn}/"]
    }
  }

  tags = var.common_tags
}

# GuardDuty
resource "aws_guardduty_detector" "main" {
  enable = true

  datasources {
    s3_logs {
      enable = true
    }
  }

  tags = var.common_tags
}
