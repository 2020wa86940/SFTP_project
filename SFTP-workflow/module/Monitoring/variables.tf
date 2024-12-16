

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "log_retention_days" {
  description = "Number of days to retain application logs"
  type        = number
  default     = 30
}

variable "audit_log_retention_days" {
  description = "Number of days to retain audit logs"
  type        = number
  default     = 365
}

variable "critical_alert_emails" {
  description = "List of email addresses for critical alerts"
  type        = list(string)
}

variable "warning_alert_emails" {
  description = "List of email addresses for warning alerts"
  type        = list(string)
}

variable "audit_events_threshold" {
  description = "Threshold for audit events alarm"
  type        = number
  default     = 1000
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Environment = "production"
    Project     = "document-processing"
    Managed_by  = "terraform"
  }
}
