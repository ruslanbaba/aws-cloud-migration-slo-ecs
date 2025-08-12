variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "alb_dns_name" {
  description = "DNS name of the load balancer"
  type        = string
}

variable "alb_arn_suffix" {
  description = "ARN suffix of the load balancer"
  type        = string
}

variable "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
}

variable "ecs_service_name" {
  description = "Name of the ECS service"
  type        = string
}

variable "log_group_name" {
  description = "Name of the CloudWatch log group"
  type        = string
}

variable "enable_synthetics" {
  description = "Enable CloudWatch Synthetics monitoring"
  type        = bool
  default     = true
}

variable "synthetics_frequency" {
  description = "Frequency for synthetic checks in minutes"
  type        = number
  default     = 1
}

variable "alert_email" {
  description = "Email for alerts"
  type        = string
  default     = ""
}
