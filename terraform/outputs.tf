# VPC and Networking Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnet_ids
}

# Load Balancer Outputs
output "alb_dns_name" {
  description = "DNS name of the load balancer"
  value       = module.ecs.alb_dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the load balancer"
  value       = module.ecs.alb_zone_id
}

output "alb_arn" {
  description = "ARN of the load balancer"
  value       = module.ecs.alb_arn
}

# ECS Outputs
output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs.cluster_name
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = module.ecs.cluster_arn
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = module.ecs.service_name
}

output "ecs_task_definition_arn" {
  description = "ARN of the ECS task definition"
  value       = module.ecs.task_definition_arn
}

# Security Outputs
output "ecs_security_group_id" {
  description = "ID of the ECS security group"
  value       = module.ecs.ecs_security_group_id
}

output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = module.ecs.alb_security_group_id
}

# Monitoring Outputs
output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = module.monitoring.log_group_name
}

output "synthetics_canary_name" {
  description = "Name of the CloudWatch Synthetics canary"
  value       = module.monitoring.synthetics_canary_name
  sensitive   = false
}

output "dashboard_url" {
  description = "URL of the CloudWatch dashboard"
  value       = "https://${data.aws_region.current.name}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${module.monitoring.dashboard_name}"
}

# Database Outputs (if enabled)
output "database_endpoint" {
  description = "Database endpoint"
  value       = var.enable_rds ? module.database[0].endpoint : null
  sensitive   = true
}

output "database_port" {
  description = "Database port"
  value       = var.enable_rds ? module.database[0].port : null
}

# WAF Outputs (if enabled)
output "waf_acl_arn" {
  description = "ARN of the WAF Web ACL"
  value       = var.enable_waf ? module.security.waf_acl_arn : null
}

# Application URL
output "application_url" {
  description = "URL to access the application"
  value       = "https://${module.ecs.alb_dns_name}"
}

# Cost Tracking
output "resource_tags" {
  description = "Common tags applied to all resources"
  value = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = var.owner
    CostCenter  = var.cost_center
  }
}

# SLO Metrics
output "slo_metrics" {
  description = "SLO monitoring endpoints and metrics"
  value = {
    availability_target    = "99.95%"
    latency_target_p95    = "500ms"
    error_rate_target     = "0.1%"
    recovery_time_target  = "15 minutes"
    synthetics_endpoint   = "https://${module.ecs.alb_dns_name}/health"
    dashboard_name        = module.monitoring.dashboard_name
    alarm_topic_arn       = module.monitoring.sns_topic_arn
  }
}
