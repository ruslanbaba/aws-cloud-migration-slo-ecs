output "autoscaling_target_resource_id" {
  description = "Resource ID of the auto scaling target"
  value       = aws_appautoscaling_target.ecs.resource_id
}

output "cpu_scaling_policy_arn" {
  description = "ARN of the CPU scaling policy"
  value       = aws_appautoscaling_policy.ecs_cpu.arn
}

output "memory_scaling_policy_arn" {
  description = "ARN of the memory scaling policy"
  value       = aws_appautoscaling_policy.ecs_memory.arn
}

output "request_scaling_policy_arn" {
  description = "ARN of the request count scaling policy"
  value       = aws_appautoscaling_policy.ecs_requests.arn
}

output "custom_metric_scaling_policy_arn" {
  description = "ARN of the custom metric scaling policy"
  value       = var.enable_custom_metric_scaling ? aws_appautoscaling_policy.ecs_custom_metric[0].arn : null
}

output "predictive_scaling_policy_arn" {
  description = "ARN of the predictive scaling policy"
  value       = var.enable_predictive_scaling ? aws_appautoscaling_policy.ecs_predictive[0].arn : null
}

output "autoscaling_sns_topic_arn" {
  description = "ARN of the auto scaling notifications SNS topic"
  value       = aws_sns_topic.autoscaling_notifications.arn
}
