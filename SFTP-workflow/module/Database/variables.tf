

variable "aws_region" {
  description = "Primary AWS region"
  type        = string
  default     = "us-west-2"
}

variable "aws_secondary_region" {
  description = "Secondary AWS region for backup"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Environment = "test"
    Project     = "data-processing"
    Managed_by  = "terraform"
  }
}
