# variables.tf

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "environment" {
  description = "Environment name"
  type        = string
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
