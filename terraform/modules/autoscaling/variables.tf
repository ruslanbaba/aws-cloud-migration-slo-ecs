variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
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

variable "min_capacity" {
  description = "Minimum number of ECS tasks"
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Maximum number of ECS tasks"
  type        = number
  default     = 10
}

variable "target_cpu_utilization" {
  description = "Target CPU utilization for auto scaling"
  type        = number
  default     = 70
}

variable "target_memory_utilization" {
  description = "Target memory utilization for auto scaling"
  type        = number
  default     = 80
}

variable "target_requests_per_target" {
  description = "Target requests per target for auto scaling"
  type        = number
  default     = 1000
}

variable "alb_arn_suffix" {
  description = "ARN suffix of the load balancer"
  type        = string
}

variable "target_group_arn_suffix" {
  description = "ARN suffix of the target group"
  type        = string
}

variable "enable_scheduled_scaling" {
  description = "Enable scheduled scaling"
  type        = bool
  default     = false
}

variable "enable_custom_metric_scaling" {
  description = "Enable custom metric scaling"
  type        = bool
  default     = false
}

variable "custom_metric_name" {
  description = "Name of the custom metric for scaling"
  type        = string
  default     = "CustomMetric"
}

variable "custom_metric_target_value" {
  description = "Target value for custom metric scaling"
  type        = number
  default     = 50
}

variable "enable_predictive_scaling" {
  description = "Enable predictive scaling"
  type        = bool
  default     = false
}

variable "notification_topic_arn" {
  description = "SNS topic ARN for auto scaling notifications"
  type        = string
  default     = ""
}
