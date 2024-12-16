

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "pdf_landing_bucket" {
  description = "Name of the PDF landing bucket"
  type        = string
}

variable "excel_reference_bucket" {
  description = "Name of the Excel reference data bucket"
  type        = string
}

variable "processed_files_bucket" {
  description = "Name of the processed files bucket"
  type        = string
}

variable "reports_bucket" {
  description = "Name of the reports bucket"
  type        = string
}

variable "notification_email" {
  description = "Email address for notifications"
  type        = string
}
