output "dashboard_name" {
  description = "Name of the main CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.slo.dashboard_name
}

output "slo_tracking_dashboard_name" {
  description = "Name of the SLO tracking dashboard"
  value       = aws_cloudwatch_dashboard.slo_tracking.dashboard_name
}

output "synthetics_canary_name" {
  description = "Name of the CloudWatch Synthetics canary"
  value       = var.enable_synthetics ? aws_synthetics_canary.availability[0].name : null
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  value       = aws_sns_topic.alerts.arn
}

output "log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = var.log_group_name
}

output "availability_alarm_name" {
  description = "Name of the availability SLO alarm"
  value       = var.enable_synthetics ? aws_cloudwatch_metric_alarm.availability_slo[0].alarm_name : null
}

output "latency_alarm_name" {
  description = "Name of the latency SLO alarm"
  value       = aws_cloudwatch_metric_alarm.latency_slo.alarm_name
}

output "error_rate_alarm_name" {
  description = "Name of the error rate SLO alarm"
  value       = aws_cloudwatch_metric_alarm.error_rate_slo.alarm_name
}

output "dashboard_url" {
  description = "URL of the main CloudWatch dashboard"
  value       = "https://${data.aws_region.current.name}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.slo.dashboard_name}"
}

output "slo_tracking_dashboard_url" {
  description = "URL of the SLO tracking dashboard"
  value       = "https://${data.aws_region.current.name}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.slo_tracking.dashboard_name}"
}
