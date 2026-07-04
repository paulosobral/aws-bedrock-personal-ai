# Terraform Configuration
terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket       = "terraform-state-bedrock-psobral89"
    key          = "terraform-bedrock-secure/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

# Provider AWS
provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = var.default_tags
  }
}

# Módulo IAM Role para Bedrock
module "iam_role" {
  source = "./modules/iam_role"

  role_name                  = var.bedrock_role_name
  tags                       = var.default_tags
  permission_boundary_arn    = var.permission_boundary_arn
  create_permission_boundary = var.create_permission_boundary
  enable_cloudtrail          = var.enable_cloudtrail
  cloudtrail_bucket_name     = var.cloudtrail_bucket_name
}

# Módulo Cost Alarm para Bedrock
module "cost_alarm" {
  source = "./modules/cost_alarm"

  sns_topic_name          = var.sns_topic_name
  notification_email      = var.notification_email
  budget_name             = var.budget_name
  budget_limit            = var.budget_limit
  notification_threshold  = var.notification_threshold
  alarm_prefix            = var.alarm_prefix
  period                  = var.alarm_period
  evaluation_periods      = var.evaluation_periods
  enable_token_alarm      = var.enable_token_alarm
  token_threshold         = var.token_threshold
  enable_invocation_alarm = var.enable_invocation_alarm
  invocation_threshold    = var.invocation_threshold
  enable_cost_alarm       = var.enable_cost_alarm
  cost_threshold          = var.cost_threshold
  tags                    = var.default_tags
}
