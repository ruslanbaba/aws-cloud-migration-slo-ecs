terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }

  backend "s3" {
    # Backend configuration should be provided via backend config file or CLI
    # bucket  = "your-terraform-state-bucket"
    # key     = "aws-cloud-migration-slo-ecs/terraform.tfstate"
    # region  = "us-west-2"
    # encrypt = true
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = var.owner
      CostCenter  = var.cost_center
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

# Local values
locals {
  availability_zones = length(var.availability_zones) > 0 ? var.availability_zones : slice(data.aws_availability_zones.available.names, 0, 3)
  
  # ALB ARN suffix for monitoring
  alb_arn_suffix = module.ecs.alb_arn != null ? split("/", module.ecs.alb_arn)[1] : ""
  target_group_arn_suffix = module.ecs.target_group_arn != null ? split("/", module.ecs.target_group_arn)[1] : ""
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr            = var.vpc_cidr
  availability_zones   = local.availability_zones
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
}

# ECS Module
module "ecs" {
  source = "./modules/ecs"

  project_name        = var.project_name
  environment         = var.environment
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  public_subnet_ids   = module.vpc.public_subnet_ids
  
  app_name           = var.app_name
  app_image          = var.app_image
  app_port           = var.app_port
  desired_count      = var.desired_count
  cpu                = var.cpu
  memory             = var.memory
  
  allowed_cidr_blocks = var.allowed_cidr_blocks
  
  app_secrets = [
    {
      name      = "DATABASE_CONNECTION_STRING"
      valueFrom = module.security.secrets_manager_secret_arn
    }
  ]

  depends_on = [module.vpc]
}

# Auto Scaling Module
module "autoscaling" {
  source = "./modules/autoscaling"

  project_name               = var.project_name
  environment                = var.environment
  ecs_cluster_name          = module.ecs.cluster_name
  ecs_service_name          = module.ecs.service_name
  
  min_capacity              = var.min_capacity
  max_capacity              = var.max_capacity
  target_cpu_utilization    = var.target_cpu_utilization
  target_memory_utilization = var.target_memory_utilization
  
  alb_arn_suffix           = local.alb_arn_suffix
  target_group_arn_suffix  = local.target_group_arn_suffix
  
  enable_scheduled_scaling = var.environment == "prod" ? true : false

  depends_on = [module.ecs]
}

# Monitoring Module
module "monitoring" {
  source = "./modules/monitoring"

  project_name       = var.project_name
  environment        = var.environment
  alb_dns_name      = module.ecs.alb_dns_name
  alb_arn_suffix    = local.alb_arn_suffix
  ecs_cluster_name  = module.ecs.cluster_name
  ecs_service_name  = module.ecs.service_name
  log_group_name    = module.ecs.log_group_name
  
  enable_synthetics     = var.enable_synthetics
  synthetics_frequency  = var.synthetics_frequency
  alert_email          = var.alert_email

  depends_on = [module.ecs]
}

# Security Module
module "security" {
  source = "./modules/security"

  project_name    = var.project_name
  environment     = var.environment
  alb_arn        = module.ecs.alb_arn
  
  enable_waf         = var.enable_waf
  enable_config      = var.environment == "prod" ? true : false
  enable_security_hub = var.environment == "prod" ? true : false
  enable_guardduty   = true
  enable_inspector   = true
  enable_cloudtrail  = var.environment == "prod" ? true : false
  
  # Security configuration
  rate_limit_per_5min = 2000
  whitelisted_ips     = []
  blocked_countries   = ["CN", "RU", "KP"]  # Example blocked countries

  depends_on = [module.ecs]
}

# Database Module (Optional)
module "database" {
  count  = var.enable_rds ? 1 : 0
  source = "./modules/database"

  project_name       = var.project_name
  environment        = var.environment
  vpc_id            = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  
  db_engine         = var.db_engine
  db_instance_class = var.db_instance_class
  
  backup_retention_days      = var.backup_retention_days
  enable_cross_region_backup = var.enable_cross_region_backup

  depends_on = [module.vpc]
}
