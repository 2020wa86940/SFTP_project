# variables.tf - Root variables file

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "private_subnets" {
  description = "List of private subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "alert_emails" {
  description = "List of email addresses for alerts"
  type        = list(string)
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project     = "document-processing"
    Managed_by  = "terraform"
  }
}
