# WAF Web ACL
resource "aws_wafv2_web_acl" "main" {
  count = var.enable_waf ? 1 : 0
  name  = "${var.project_name}-${var.environment}-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  # AWS Managed Rule - Common Rule Set
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"

        rule_action_override {
          action_to_use {
            block {}
          }
          name = "SizeRestrictions_BODY"
        }

        rule_action_override {
          action_to_use {
            block {}
          }
          name = "GenericRFI_BODY"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "CommonRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rule - Known Bad Inputs
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "KnownBadInputsRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rule - SQL Injection
  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "SQLiRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  # Rate Limiting Rule
  rule {
    name     = "RateLimitRule"
    priority = 4

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.rate_limit_per_5min
        aggregate_key_type = "IP"

        scope_down_statement {
          geo_match_statement {
            country_codes = var.blocked_countries
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitRule"
      sampled_requests_enabled   = true
    }
  }

  # IP Whitelist Rule (if provided)
  dynamic "rule" {
    for_each = length(var.whitelisted_ips) > 0 ? [1] : []
    content {
      name     = "IPWhitelistRule"
      priority = 5

      action {
        allow {}
      }

      statement {
        ip_set_reference_statement {
          arn = aws_wafv2_ip_set.whitelist[0].arn
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "IPWhitelistRule"
        sampled_requests_enabled   = true
      }
    }
  }

  # Geo Blocking Rule
  dynamic "rule" {
    for_each = length(var.blocked_countries) > 0 ? [1] : []
    content {
      name     = "GeoBlockingRule"
      priority = 6

      action {
        block {}
      }

      statement {
        geo_match_statement {
          country_codes = var.blocked_countries
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "GeoBlockingRule"
        sampled_requests_enabled   = true
      }
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-waf"
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-${var.environment}-waf"
    sampled_requests_enabled   = true
  }
}

# IP Set for Whitelisting
resource "aws_wafv2_ip_set" "whitelist" {
  count              = length(var.whitelisted_ips) > 0 ? 1 : 0
  name               = "${var.project_name}-${var.environment}-whitelist"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  addresses          = var.whitelisted_ips

  tags = {
    Name = "${var.project_name}-${var.environment}-ip-whitelist"
  }
}

# WAF Association with ALB
resource "aws_wafv2_web_acl_association" "main" {
  count        = var.enable_waf ? 1 : 0
  resource_arn = var.alb_arn
  web_acl_arn  = aws_wafv2_web_acl.main[0].arn
}

# CloudWatch Log Group for WAF
resource "aws_cloudwatch_log_group" "waf" {
  count             = var.enable_waf ? 1 : 0
  name              = "/aws/wafv2/${var.project_name}-${var.environment}"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.security.arn

  tags = {
    Name = "${var.project_name}-${var.environment}-waf-logs"
  }
}

# WAF Logging Configuration
resource "aws_wafv2_web_acl_logging_configuration" "main" {
  count                   = var.enable_waf ? 1 : 0
  resource_arn            = aws_wafv2_web_acl.main[0].arn
  log_destination_configs = [aws_cloudwatch_log_group.waf[0].arn]

  redacted_fields {
    single_header {
      name = "authorization"
    }
  }

  redacted_fields {
    single_header {
      name = "cookie"
    }
  }
}

# KMS Key for Security
resource "aws_kms_key" "security" {
  description             = "KMS key for security services in ${var.project_name}-${var.environment}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs"
        Effect = "Allow"
        Principal = {
          Service = "logs.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-security-kms"
  }
}

resource "aws_kms_alias" "security" {
  name          = "alias/${var.project_name}-${var.environment}-security"
  target_key_id = aws_kms_key.security.key_id
}

# AWS Config for Compliance Monitoring
resource "aws_config_configuration_recorder" "main" {
  count    = var.enable_config ? 1 : 0
  name     = "${var.project_name}-${var.environment}-config"
  role_arn = aws_iam_role.config[0].arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }

  depends_on = [aws_config_delivery_channel.main]
}

resource "aws_config_delivery_channel" "main" {
  count          = var.enable_config ? 1 : 0
  name           = "${var.project_name}-${var.environment}-config"
  s3_bucket_name = aws_s3_bucket.config[0].bucket

  snapshot_delivery_properties {
    delivery_frequency = "Daily"
  }
}

# S3 Bucket for Config
resource "aws_s3_bucket" "config" {
  count         = var.enable_config ? 1 : 0
  bucket        = "${var.project_name}-${var.environment}-config-${random_id.config_suffix.hex}"
  force_destroy = var.environment != "prod"

  tags = {
    Name = "${var.project_name}-${var.environment}-config"
  }
}

resource "random_id" "config_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket_policy" "config" {
  count  = var.enable_config ? 1 : 0
  bucket = aws_s3_bucket.config[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSConfigBucketPermissionsCheck"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.config[0].arn
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid    = "AWSConfigBucketExistenceCheck"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:ListBucket"
        Resource = aws_s3_bucket.config[0].arn
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid    = "AWSConfigBucketDelivery"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.config[0].arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"      = "bucket-owner-full-control"
            "AWS:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

# IAM Role for Config
resource "aws_iam_role" "config" {
  count = var.enable_config ? 1 : 0
  name  = "${var.project_name}-${var.environment}-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "config" {
  count      = var.enable_config ? 1 : 0
  role       = aws_iam_role.config[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/ConfigRole"
}

# Security Hub
resource "aws_securityhub_account" "main" {
  count                    = var.enable_security_hub ? 1 : 0
  enable_default_standards = true

  control_finding_generator = "SECURITY_CONTROL"
  auto_enable_controls      = true

  depends_on = [aws_config_configuration_recorder.main]
}

# GuardDuty
resource "aws_guardduty_detector" "main" {
  count  = var.enable_guardduty ? 1 : 0
  enable = true

  datasources {
    s3_logs {
      enable = true
    }
    kubernetes {
      audit_logs {
        enable = false
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = true
        }
      }
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-guardduty"
  }
}

# Inspector V2
resource "aws_inspector2_enabler" "main" {
  count           = var.enable_inspector ? 1 : 0
  account_ids     = [data.aws_caller_identity.current.account_id]
  resource_types  = ["ECR", "EC2"]
}

# CloudTrail
resource "aws_cloudtrail" "main" {
  count                         = var.enable_cloudtrail ? 1 : 0
  name                          = "${var.project_name}-${var.environment}-cloudtrail"
  s3_bucket_name               = aws_s3_bucket.cloudtrail[0].bucket
  include_global_service_events = true
  is_multi_region_trail        = true
  enable_logging               = true

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::*/*"]
    }
  }

  insight_selector {
    insight_type = "ApiCallRateInsight"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-cloudtrail"
  }
}

# S3 Bucket for CloudTrail
resource "aws_s3_bucket" "cloudtrail" {
  count         = var.enable_cloudtrail ? 1 : 0
  bucket        = "${var.project_name}-${var.environment}-cloudtrail-${random_id.cloudtrail_suffix.hex}"
  force_destroy = var.environment != "prod"

  tags = {
    Name = "${var.project_name}-${var.environment}-cloudtrail"
  }
}

resource "random_id" "cloudtrail_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  count  = var.enable_cloudtrail ? 1 : 0
  bucket = aws_s3_bucket.cloudtrail[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail[0].arn
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = "arn:aws:cloudtrail:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:trail/${var.project_name}-${var.environment}-cloudtrail"
          }
        }
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail[0].arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"  = "bucket-owner-full-control"
            "AWS:SourceArn" = "arn:aws:cloudtrail:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:trail/${var.project_name}-${var.environment}-cloudtrail"
          }
        }
      }
    ]
  })
}

# Secrets Manager Secret for Application Configuration
resource "aws_secretsmanager_secret" "app_config" {
  name                    = "${var.project_name}/${var.environment}/app-config"
  description             = "Application configuration for ${var.project_name}-${var.environment}"
  kms_key_id             = aws_kms_key.security.arn
  recovery_window_in_days = var.environment == "prod" ? 30 : 0

  tags = {
    Name = "${var.project_name}-${var.environment}-app-config"
  }
}

resource "aws_secretsmanager_secret_version" "app_config" {
  secret_id = aws_secretsmanager_secret.app_config.id
  secret_string = jsonencode({
    database_connection_string = var.database_connection_string
    api_keys                  = var.api_keys
    encryption_key            = var.encryption_key
  })
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
