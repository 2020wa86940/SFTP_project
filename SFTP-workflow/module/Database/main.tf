# main.tf

provider "aws" {
  region = var.aws_region
}

# Participant Data Table
resource "aws_dynamodb_table" "participant_data" {
  name           = "${var.environment}-participant-data"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "participant_id"
  range_key      = "document_id"
  
  attribute {
    name = "participant_id"
    type = "S"
  }
  
  attribute {
    name = "document_id"
    type = "S"
  }
  
  attribute {
    name = "process_date"
    type = "S"
  }
  
  attribute {
    name = "status"
    type = "S"
  }

  # GSI for querying by process date
  global_secondary_index {
    name               = "ProcessDateIndex"
    hash_key          = "process_date"
    range_key         = "participant_id"
    projection_type   = "ALL"
  }

  # GSI for querying by status
  global_secondary_index {
    name               = "StatusIndex"
    hash_key          = "status"
    range_key         = "process_date"
    projection_type   = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = var.common_tags
}

# Audit Trail Table
resource "aws_dynamodb_table" "audit_trail" {
  name           = "${var.environment}-audit-trail"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "audit_id"
  range_key      = "timestamp"

  attribute {
    name = "audit_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  attribute {
    name = "participant_id"
    type = "S"
  }

  attribute {
    name = "event_type"
    type = "S"
  }

  # GSI for querying by participant
  global_secondary_index {
    name               = "ParticipantIndex"
    hash_key          = "participant_id"
    range_key         = "timestamp"
    projection_type   = "ALL"
  }

  # GSI for querying by event type
  global_secondary_index {
    name               = "EventTypeIndex"
    hash_key          = "event_type"
    range_key         = "timestamp"
    projection_type   = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = var.common_tags

  # TTL for audit records
  ttl {
    attribute_name = "expiry_time"
    enabled       = true
  }
}

# Process Metadata Table
resource "aws_dynamodb_table" "process_metadata" {
  name           = "${var.environment}-process-metadata"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "process_id"
  range_key      = "created_at"

  attribute {
    name = "process_id"
    type = "S"
  }

  attribute {
    name = "created_at"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  attribute {
    name = "process_type"
    type = "S"
  }

  # GSI for querying by status
  global_secondary_index {
    name               = "StatusIndex"
    hash_key          = "status"
    range_key         = "created_at"
    projection_type   = "ALL"
  }

  # GSI for querying by process type
  global_secondary_index {
    name               = "ProcessTypeIndex"
    hash_key          = "process_type"
    range_key         = "created_at"
    projection_type   = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = var.common_tags
}

# Backup Plan
resource "aws_backup_plan" "dynamodb_backup" {
  name = "${var.environment}-dynamodb-backup-plan"

  rule {
    rule_name         = "daily_backup"
    target_vault_name = aws_backup_vault.dynamodb_backup_vault.name
    schedule          = "cron(0 1 * * ? *)" # Daily at 1 AM UTC

    lifecycle {
      delete_after = 30
    }

    copy_action {
      destination_vault_arn = aws_backup_vault.dynamodb_backup_vault_secondary.arn
      
      lifecycle {
        delete_after = 90
      }
    }
  }

  rule {
    rule_name         = "weekly_backup"
    target_vault_name = aws_backup_vault.dynamodb_backup_vault.name
    schedule          = "cron(0 2 ? * SUN *)" # Weekly on Sunday at 2 AM UTC

    lifecycle {
      delete_after = 90
    }
  }

  tags = var.common_tags
}

# Backup Vault - Primary
resource "aws_backup_vault" "dynamodb_backup_vault" {
  name = "${var.environment}-dynamodb-backup-vault"
  tags = var.common_tags
}

# Backup Vault - Secondary (for cross-region backup)
resource "aws_backup_vault" "dynamodb_backup_vault_secondary" {
  provider = aws.secondary
  name     = "${var.environment}-dynamodb-backup-vault-secondary"
  tags     = var.common_tags
}

# IAM Role for AWS Backup
resource "aws_iam_role" "backup_role" {
  name = "${var.environment}-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for AWS Backup
resource "aws_iam_role_policy_attachment" "backup_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
  role       = aws_iam_role.backup_role.name
}

# Backup Selection
resource "aws_backup_selection" "dynamodb_backup" {
  name         = "${var.environment}-dynamodb-backup-selection"
  plan_id      = aws_backup_plan.dynamodb_backup.id
  iam_role_arn = aws_iam_role.backup_role.arn

  resources = [
    aws_dynamodb_table.participant_data.arn,
    aws_dynamodb_table.audit_trail.arn,
    aws_dynamodb_table.process_metadata.arn
  ]
}
