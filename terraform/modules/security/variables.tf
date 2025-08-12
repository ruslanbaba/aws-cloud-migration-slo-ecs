variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "alb_arn" {
  description = "ARN of the Application Load Balancer"
  type        = string
}

variable "enable_waf" {
  description = "Enable AWS WAF"
  type        = bool
  default     = true
}

variable "enable_config" {
  description = "Enable AWS Config"
  type        = bool
  default     = true
}

variable "enable_security_hub" {
  description = "Enable AWS Security Hub"
  type        = bool
  default     = true
}

variable "enable_guardduty" {
  description = "Enable AWS GuardDuty"
  type        = bool
  default     = true
}

variable "enable_inspector" {
  description = "Enable AWS Inspector"
  type        = bool
  default     = true
}

variable "enable_cloudtrail" {
  description = "Enable AWS CloudTrail"
  type        = bool
  default     = true
}

variable "rate_limit_per_5min" {
  description = "Rate limit per 5 minutes for WAF"
  type        = number
  default     = 2000
}

variable "whitelisted_ips" {
  description = "List of whitelisted IP addresses"
  type        = list(string)
  default     = []
}

variable "blocked_countries" {
  description = "List of blocked country codes"
  type        = list(string)
  default     = []
}

variable "database_connection_string" {
  description = "Database connection string"
  type        = string
  default     = ""
  sensitive   = true
}

variable "api_keys" {
  description = "API keys for the application"
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "encryption_key" {
  description = "Encryption key for the application"
  type        = string
  default     = ""
  sensitive   = true
}
