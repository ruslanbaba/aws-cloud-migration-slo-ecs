# CloudWatch Synthetics Canary for Availability SLO
resource "aws_synthetics_canary" "availability" {
  count                = var.enable_synthetics ? 1 : 0
  name                 = "${var.project_name}-${var.environment}-availability-canary"
  artifact_s3_location = "s3://${aws_s3_bucket.synthetics_artifacts.bucket}/"
  execution_role_arn   = aws_iam_role.synthetics.arn
  handler              = "synthetics-availability-check.handler"
  zip_file             = data.archive_file.synthetics_availability.output_path
  runtime_version      = "syn-nodejs-puppeteer-6.2"

  schedule {
    expression                = "rate(${var.synthetics_frequency} minute${var.synthetics_frequency == 1 ? "" : "s"})"
    duration_in_seconds       = 0
  }

  run_config {
    timeout_in_seconds    = 60
    memory_in_mb         = 960
    active_tracing       = true
    environment_variables = {
      TARGET_URL = "https://${var.alb_dns_name}"
    }
  }

  failure_retention_period = 30
  success_retention_period = 30

  tags = {
    Name = "${var.project_name}-${var.environment}-availability-canary"
    SLO  = "Availability-99.95%"
  }
}

# Synthetics Scripts
data "archive_file" "synthetics_availability" {
  type        = "zip"
  output_path = "${path.module}/synthetics-availability-check.zip"

  source {
    content = templatefile("${path.module}/synthetics-scripts/availability-check.js", {
      target_url = "https://${var.alb_dns_name}"
    })
    filename = "nodejs/node_modules/synthetics-availability-check.js"
  }
}

# S3 Bucket for Synthetics Artifacts
resource "aws_s3_bucket" "synthetics_artifacts" {
  bucket        = "${var.project_name}-${var.environment}-synthetics-artifacts-${random_id.synthetics_suffix.hex}"
  force_destroy = var.environment != "prod"

  tags = {
    Name = "${var.project_name}-${var.environment}-synthetics-artifacts"
  }
}

resource "random_id" "synthetics_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket_versioning" "synthetics_artifacts" {
  bucket = aws_s3_bucket.synthetics_artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_encryption" "synthetics_artifacts" {
  bucket = aws_s3_bucket.synthetics_artifacts.id

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

resource "aws_s3_bucket_public_access_block" "synthetics_artifacts" {
  bucket = aws_s3_bucket.synthetics_artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# IAM Role for Synthetics
resource "aws_iam_role" "synthetics" {
  name = "${var.project_name}-${var.environment}-synthetics-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-synthetics-role"
  }
}

resource "aws_iam_role_policy_attachment" "synthetics" {
  role       = aws_iam_role.synthetics.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchSyntheticsExecutionRolePolicy"
}

# CloudWatch Dashboard for SLO Monitoring
resource "aws_cloudwatch_dashboard" "slo" {
  dashboard_name = "${var.project_name}-${var.environment}-slo-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/Synthetics", "SuccessPercent", "CanaryName", var.enable_synthetics ? aws_synthetics_canary.availability[0].name : ""],
            [".", "Duration", ".", "."],
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Availability SLO - Target: 99.95%"
          period  = 300
          annotations = {
            horizontal = [
              {
                label = "SLO Threshold"
                value = 99.95
              }
            ]
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix, {"stat": "Average"}],
            [".", ".", ".", ".", {"stat": "p95"}],
            [".", ".", ".", ".", {"stat": "p99"}]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Latency SLO - Target: <500ms (P95)"
          period  = 300
          yAxis = {
            left = {
              min = 0
              max = 1000
            }
          }
          annotations = {
            horizontal = [
              {
                label = "SLO Threshold (P95)"
                value = 500
              }
            ]
          }
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_Target_2XX_Count", "LoadBalancer", var.alb_arn_suffix],
            [".", "HTTPCode_Target_4XX_Count", ".", "."],
            [".", "HTTPCode_Target_5XX_Count", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "HTTP Response Codes"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ServiceName", var.ecs_service_name, "ClusterName", var.ecs_cluster_name],
            [".", "MemoryUtilization", ".", ".", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "ECS Resource Utilization"
          period  = 300
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 12
        width  = 24
        height = 6

        properties = {
          query   = "SOURCE '${var.log_group_name}' | fields @timestamp, @message | filter @message like /ERROR/ | sort @timestamp desc | limit 100"
          region  = data.aws_region.current.name
          title   = "Recent Application Errors"
          view    = "table"
        }
      }
    ]
  })
}

# CloudWatch Alarms for SLO Monitoring

# Availability SLO Alarm
resource "aws_cloudwatch_metric_alarm" "availability_slo" {
  count               = var.enable_synthetics ? 1 : 0
  alarm_name          = "${var.project_name}-${var.environment}-availability-slo-breach"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "SuccessPercent"
  namespace           = "AWS/Synthetics"
  period              = "300"
  statistic           = "Average"
  threshold           = "99.95"
  alarm_description   = "Availability SLO breach - below 99.95%"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "breaching"

  dimensions = {
    CanaryName = aws_synthetics_canary.availability[0].name
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-availability-slo-alarm"
    SLO  = "Availability"
  }
}

# Latency SLO Alarm
resource "aws_cloudwatch_metric_alarm" "latency_slo" {
  alarm_name          = "${var.project_name}-${var.environment}-latency-slo-breach"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "p95"
  threshold           = "0.5"
  alarm_description   = "Latency SLO breach - P95 response time above 500ms"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-latency-slo-alarm"
    SLO  = "Latency"
  }
}

# Error Rate SLO Alarm
resource "aws_cloudwatch_metric_alarm" "error_rate_slo" {
  alarm_name          = "${var.project_name}-${var.environment}-error-rate-slo-breach"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  threshold           = "0.1"
  alarm_description   = "Error rate SLO breach - above 0.1%"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "error_rate"
    expression  = "100 * (m2 + m3) / (m1 + m2 + m3)"
    label       = "Error Rate Percentage"
    return_data = "true"
  }

  metric_query {
    id = "m1"
    metric {
      metric_name = "HTTPCode_Target_2XX_Count"
      namespace   = "AWS/ApplicationELB"
      period      = "300"
      stat        = "Sum"

      dimensions = {
        LoadBalancer = var.alb_arn_suffix
      }
    }
  }

  metric_query {
    id = "m2"
    metric {
      metric_name = "HTTPCode_Target_4XX_Count"
      namespace   = "AWS/ApplicationELB"
      period      = "300"
      stat        = "Sum"

      dimensions = {
        LoadBalancer = var.alb_arn_suffix
      }
    }
  }

  metric_query {
    id = "m3"
    metric {
      metric_name = "HTTPCode_Target_5XX_Count"
      namespace   = "AWS/ApplicationELB"
      period      = "300"
      stat        = "Sum"

      dimensions = {
        LoadBalancer = var.alb_arn_suffix
      }
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-error-rate-slo-alarm"
    SLO  = "ErrorRate"
  }
}

# High CPU Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.project_name}-${var.environment}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "High CPU utilization detected"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    ServiceName = var.ecs_service_name
    ClusterName = var.ecs_cluster_name
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-high-cpu-alarm"
  }
}

# High Memory Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "high_memory" {
  alarm_name          = "${var.project_name}-${var.environment}-high-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "85"
  alarm_description   = "High memory utilization detected"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    ServiceName = var.ecs_service_name
    ClusterName = var.ecs_cluster_name
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-high-memory-alarm"
  }
}

# SNS Topic for Alerts
resource "aws_sns_topic" "alerts" {
  name         = "${var.project_name}-${var.environment}-alerts"
  display_name = "${var.project_name} ${var.environment} Alerts"

  tags = {
    Name = "${var.project_name}-${var.environment}-alerts"
  }
}

resource "aws_sns_topic_subscription" "alerts_email" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# Custom Metrics for SLO Tracking
resource "aws_cloudwatch_log_metric_filter" "application_errors" {
  name           = "${var.project_name}-${var.environment}-application-errors"
  log_group_name = var.log_group_name
  pattern        = "[timestamp, request_id, level=\"ERROR\", ...]"

  metric_transformation {
    name      = "ApplicationErrors"
    namespace = "Custom/${var.project_name}/${var.environment}"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "slow_requests" {
  name           = "${var.project_name}-${var.environment}-slow-requests"
  log_group_name = var.log_group_name
  pattern        = "[timestamp, request_id, ..., duration > 1000]"

  metric_transformation {
    name      = "SlowRequests"
    namespace = "Custom/${var.project_name}/${var.environment}"
    value     = "1"
  }
}

# SLO Tracking Dashboard
resource "aws_cloudwatch_dashboard" "slo_tracking" {
  dashboard_name = "${var.project_name}-${var.environment}-slo-tracking"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "number"
        x      = 0
        y      = 0
        width  = 6
        height = 6

        properties = {
          metrics = [
            ["AWS/Synthetics", "SuccessPercent", "CanaryName", var.enable_synthetics ? aws_synthetics_canary.availability[0].name : ""]
          ]
          view    = "singleValue"
          region  = data.aws_region.current.name
          title   = "Current Availability"
          period  = 3600
          stat    = "Average"
        }
      },
      {
        type   = "number"
        x      = 6
        y      = 0
        width  = 6
        height = 6

        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix]
          ]
          view    = "singleValue"
          region  = data.aws_region.current.name
          title   = "Current P95 Latency (ms)"
          period  = 3600
          stat    = "p95"
        }
      },
      {
        type   = "number"
        x      = 12
        y      = 0
        width  = 6
        height = 6

        properties = {
          view    = "singleValue"
          region  = data.aws_region.current.name
          title   = "Current Error Rate (%)"
          period  = 3600
          metrics = []
          
          annotations = {
            horizontal = [
              {
                label = "SLO Target"
                value = 0.1
              }
            ]
          }
        }
      },
      {
        type   = "number"
        x      = 18
        y      = 0
        width  = 6
        height = 6

        properties = {
          metrics = [
            ["AWS/ECS", "RunningTaskCount", "ServiceName", var.ecs_service_name, "ClusterName", var.ecs_cluster_name]
          ]
          view    = "singleValue"
          region  = data.aws_region.current.name
          title   = "Running Tasks"
          period  = 300
          stat    = "Average"
        }
      }
    ]
  })
}

# Data sources
data "aws_region" "current" {}
