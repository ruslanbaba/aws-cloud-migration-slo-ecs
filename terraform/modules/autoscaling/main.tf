# Auto Scaling Target
resource "aws_appautoscaling_target" "ecs" {
  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = "service/${var.ecs_cluster_name}/${var.ecs_service_name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  tags = {
    Name = "${var.project_name}-${var.environment}-autoscaling-target"
  }
}

# CPU-based Auto Scaling Policy
resource "aws_appautoscaling_policy" "ecs_cpu" {
  name               = "${var.project_name}-${var.environment}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value       = var.target_cpu_utilization
    scale_in_cooldown  = 300
    scale_out_cooldown = 300
  }
}

# Memory-based Auto Scaling Policy
resource "aws_appautoscaling_policy" "ecs_memory" {
  name               = "${var.project_name}-${var.environment}-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }

    target_value       = var.target_memory_utilization
    scale_in_cooldown  = 300
    scale_out_cooldown = 300
  }
}

# ALB Request Count based Auto Scaling Policy
resource "aws_appautoscaling_policy" "ecs_requests" {
  name               = "${var.project_name}-${var.environment}-request-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label        = "${var.alb_arn_suffix}/${var.target_group_arn_suffix}"
    }

    target_value       = var.target_requests_per_target
    scale_in_cooldown  = 300
    scale_out_cooldown = 180
  }
}

# Scheduled Scaling for Predictable Traffic Patterns
resource "aws_appautoscaling_scheduled_action" "scale_up_morning" {
  count              = var.enable_scheduled_scaling ? 1 : 0
  name               = "${var.project_name}-${var.environment}-scale-up-morning"
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension

  scalable_target_action {
    min_capacity = var.min_capacity * 2
    max_capacity = var.max_capacity
  }

  schedule = "cron(0 8 * * MON-FRI)"  # 8 AM weekdays
}

resource "aws_appautoscaling_scheduled_action" "scale_down_evening" {
  count              = var.enable_scheduled_scaling ? 1 : 0
  name               = "${var.project_name}-${var.environment}-scale-down-evening"
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension

  scalable_target_action {
    min_capacity = var.min_capacity
    max_capacity = var.max_capacity
  }

  schedule = "cron(0 20 * * MON-FRI)"  # 8 PM weekdays
}

# CloudWatch Alarms for Auto Scaling Monitoring
resource "aws_cloudwatch_metric_alarm" "high_cpu_scaling" {
  alarm_name          = "${var.project_name}-${var.environment}-autoscaling-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = var.target_cpu_utilization + 10
  alarm_description   = "Auto scaling triggered due to high CPU"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ServiceName = var.ecs_service_name
    ClusterName = var.ecs_cluster_name
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-autoscaling-high-cpu-alarm"
    Type = "AutoScaling"
  }
}

resource "aws_cloudwatch_metric_alarm" "high_memory_scaling" {
  alarm_name          = "${var.project_name}-${var.environment}-autoscaling-high-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = var.target_memory_utilization + 10
  alarm_description   = "Auto scaling triggered due to high memory"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ServiceName = var.ecs_service_name
    ClusterName = var.ecs_cluster_name
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-autoscaling-high-memory-alarm"
    Type = "AutoScaling"
  }
}

# Custom Scaling Policy based on Application Metrics
resource "aws_appautoscaling_policy" "ecs_custom_metric" {
  count              = var.enable_custom_metric_scaling ? 1 : 0
  name               = "${var.project_name}-${var.environment}-custom-metric-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    customized_metric_specification {
      metric_name = var.custom_metric_name
      namespace   = "Custom/${var.project_name}/${var.environment}"
      statistic   = "Average"
    }

    target_value       = var.custom_metric_target_value
    scale_in_cooldown  = 300
    scale_out_cooldown = 300
  }
}

# Predictive Scaling (if supported in the region)
resource "aws_appautoscaling_policy" "ecs_predictive" {
  count              = var.enable_predictive_scaling ? 1 : 0
  name               = "${var.project_name}-${var.environment}-predictive-scaling"
  policy_type        = "PredictiveScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  predictive_scaling_policy_configuration {
    metric_specification {
      target_value = var.target_cpu_utilization
      
      predefined_metric_pair_specification {
        predefined_metric_type = "ECSServiceAverageCPUUtilization"
      }
    }

    mode                         = "ForecastAndScale"
    scheduling_buffer_time       = 300
    max_capacity_breach_behavior = "HonorMaxCapacity"
    max_capacity_buffer          = 10
  }
}

# Auto Scaling Notifications
resource "aws_sns_topic" "autoscaling_notifications" {
  name = "${var.project_name}-${var.environment}-autoscaling-notifications"

  tags = {
    Name = "${var.project_name}-${var.environment}-autoscaling-notifications"
  }
}

resource "aws_autoscaling_notification" "ecs_notifications" {
  count       = var.notification_topic_arn != "" ? 1 : 0
  group_names = [aws_appautoscaling_target.ecs.resource_id]

  notifications = [
    "autoscaling:EC2_INSTANCE_LAUNCH",
    "autoscaling:EC2_INSTANCE_TERMINATE",
    "autoscaling:EC2_INSTANCE_LAUNCH_ERROR",
    "autoscaling:EC2_INSTANCE_TERMINATE_ERROR",
  ]

  topic_arn = var.notification_topic_arn
}
