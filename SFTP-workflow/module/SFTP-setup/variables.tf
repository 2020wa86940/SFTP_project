# variables.tf

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "sftp_bucket_name" {
  description = "Name of the S3 bucket for SFTP"
  type        = string
}

variable "sftp_server_name" {
  description = "Name of the SFTP server"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "log_retention_days" {
  description = "Number of days to retain logs"
  type        = number
  default     = 30
}

variable "sftp_users" {
  description = "Map of SFTP users and their SSH public keys"
  type = map(object({
    ssh_public_key = string
  }))
}

variable "alert_email" {
  description = "Email address for SFTP alerts"
  type        = string
}
