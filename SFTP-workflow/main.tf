#  Main configuration file

provider "aws" {
  region = var.aws_region
}

# Import all module configurations
module "storage" {
  source = "./modules/storage"
  
  environment     = var.environment
  common_tags    = var.common_tags
  kms_key_arn    = module.security.kms_key_arn
}

module "database" {
  source = "./modules/database"
  
  environment     = var.environment
  common_tags    = var.common_tags
  kms_key_arn    = module.security.kms_key_arn
}

module "processing" {
  source = "./modules/processing"
  
  environment        = var.environment
  common_tags       = var.common_tags
  vpc_id            = module.security.vpc_id
  private_subnet_ids = module.security.private_subnet_ids
  lambda_sg_id      = module.security.lambda_security_group_id
  kms_key_arn       = module.security.kms_key_arn
  s3_bucket_id      = module.storage.pdf_landing_bucket_id
  dynamodb_table_arn = module.database.participant_table_arn
}

module "monitoring" {
  source = "./modules/monitoring"
  
  environment     = var.environment
  common_tags    = var.common_tags
  lambda_functions = module.processing.lambda_functions
  step_function_arn = module.processing.step_function_arn
  alert_emails    = var.alert_emails
}

module "security" {
  source = "./modules/security"
  
  environment     = var.environment
  common_tags    = var.common_tags
  vpc_cidr       = var.vpc_cidr
  private_subnets = var.private_subnets
}
