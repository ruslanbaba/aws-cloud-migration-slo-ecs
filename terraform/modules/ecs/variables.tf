variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnet IDs"
  type        = list(string)
}

variable "app_name" {
  description = "Name of the application"
  type        = string
}

variable "app_image" {
  description = "Docker image for the application"
  type        = string
}

variable "app_port" {
  description = "Port the application listens on"
  type        = number
}

variable "desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
}

variable "cpu" {
  description = "CPU units for ECS task"
  type        = number
}

variable "memory" {
  description = "Memory for ECS task"
  type        = number
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the application"
  type        = list(string)
}

variable "app_secrets" {
  description = "List of secrets for the application"
  type = list(object({
    name      = string
    valueFrom = string
  }))
  default = []
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
  default     = ""
}

variable "hosted_zone_name" {
  description = "Hosted zone name for the application"
  type        = string
  default     = "example.com"
}
