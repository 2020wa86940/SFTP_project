

provider "aws" {
  region = var.aws_region
}

# SNS Topic for bucket notifications
resource "aws_sns_topic" "bucket_notifications" {
  name = "s3-bucket-notifications"
}

# SNS Topic Policy
resource "aws_sns_topic_policy" "default" {
  arn = aws_sns_topic.bucket_notifications.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowS3BucketNotifications"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.bucket_notifications.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

# Raw PDF Landing Bucket
resource "aws_s3_bucket" "pdf_landing" {
  bucket = "${var.environment}-${var.pdf_landing_bucket}"
}

resource "aws_s3_bucket_versioning" "pdf_landing" {
  bucket = aws_s3_bucket.pdf_landing.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "pdf_landing" {
  bucket = aws_s3_bucket.pdf_landing.id

  rule {
    id     = "move_to_ia"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }

  rule {
    id     = "clean_incomplete_mpu"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# Excel Reference Data Bucket
resource "aws_s3_bucket" "excel_reference" {
  bucket = "${var.environment}-${var.excel_reference_bucket}"
}

resource "aws_s3_bucket_versioning" "excel_reference" {
  bucket = aws_s3_bucket.excel_reference.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "excel_reference" {
  bucket = aws_s3_bucket.excel_reference.id

  rule {
    id     = "version_cleanup"
    status = "Enabled"

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# Processed Files Bucket
resource "aws_s3_bucket" "processed_files" {
  bucket = "${var.environment}-${var.processed_files_bucket}"
}

resource "aws_s3_bucket_versioning" "processed_files" {
  bucket = aws_s3_bucket.processed_files.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "processed_files" {
  bucket = aws_s3_bucket.processed_files.id

  rule {
    id     = "archive_old_files"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 60
      storage_class = "GLACIER"
    }
  }
}

# Reports Bucket
resource "aws_s3_bucket" "reports" {
  bucket = "${var.environment}-${var.reports_bucket}"
}

resource "aws_s3_bucket_versioning" "reports" {
  bucket = aws_s3_bucket.reports.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "reports" {
  bucket = aws_s3_bucket.reports.id

  rule {
    id     = "archive_reports"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }
}

# Bucket Notifications
resource "aws_s3_bucket_notification" "pdf_landing_notification" {
  bucket = aws_s3_bucket.pdf_landing.id

  topic {
    topic_arn     = aws_sns_topic.bucket_notifications.arn
    events        = ["s3:ObjectCreated:*"]
    filter_suffix = ".pdf"
  }
}

# Server-side encryption for all buckets
resource "aws_s3_bucket_server_side_encryption_configuration" "pdf_landing" {
  bucket = aws_s3_bucket.pdf_landing.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "excel_reference" {
  bucket = aws_s3_bucket.excel_reference.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "processed_files" {
  bucket = aws_s3_bucket.processed_files.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "reports" {
  bucket = aws_s3_bucket.reports.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Bucket policies
resource "aws_s3_bucket_public_access_block" "pdf_landing" {
  bucket = aws_s3_bucket.pdf_landing.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "excel_reference" {
  bucket = aws_s3_bucket.excel_reference.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "processed_files" {
  bucket = aws_s3_bucket.processed_files.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "reports" {
  bucket = aws_s3_bucket.reports.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
