output "waf_acl_arn" {
  description = "ARN of the WAF Web ACL"
  value       = var.enable_waf ? aws_wafv2_web_acl.main[0].arn : null
}

output "waf_acl_id" {
  description = "ID of the WAF Web ACL"
  value       = var.enable_waf ? aws_wafv2_web_acl.main[0].id : null
}

output "security_kms_key_arn" {
  description = "ARN of the security KMS key"
  value       = aws_kms_key.security.arn
}

output "security_kms_key_id" {
  description = "ID of the security KMS key"
  value       = aws_kms_key.security.key_id
}

output "guardduty_detector_id" {
  description = "ID of the GuardDuty detector"
  value       = var.enable_guardduty ? aws_guardduty_detector.main[0].id : null
}

output "cloudtrail_arn" {
  description = "ARN of the CloudTrail"
  value       = var.enable_cloudtrail ? aws_cloudtrail.main[0].arn : null
}

output "config_recorder_name" {
  description = "Name of the Config recorder"
  value       = var.enable_config ? aws_config_configuration_recorder.main[0].name : null
}

output "secrets_manager_secret_arn" {
  description = "ARN of the Secrets Manager secret"
  value       = aws_secretsmanager_secret.app_config.arn
}

output "secrets_manager_secret_name" {
  description = "Name of the Secrets Manager secret"
  value       = aws_secretsmanager_secret.app_config.name
}
