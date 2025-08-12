# Staging Environment Configuration
project_name = "dotnet-migration"
environment  = "staging"
aws_region   = "us-west-2"
owner        = "platform-team"
cost_center  = "engineering"

# Network Configuration
vpc_cidr = "10.2.0.0/16"
private_subnet_cidrs = ["10.2.1.0/24", "10.2.2.0/24", "10.2.3.0/24"]
public_subnet_cidrs  = ["10.2.101.0/24", "10.2.102.0/24", "10.2.103.0/24"]

# ECS Configuration
app_name      = "dotnet-app"
app_image     = "your-ecr-repo/dotnet-app:staging"  # Replace with your ECR repository
app_port      = 80
desired_count = 2
cpu           = 512
memory        = 1024

# Auto Scaling Configuration
min_capacity              = 1
max_capacity              = 10
target_cpu_utilization    = 70
target_memory_utilization = 80

# Monitoring Configuration
enable_synthetics    = true
synthetics_frequency = 2  # Every 2 minutes for staging
alert_email         = "staging-alerts@company.com"

# Security Configuration
enable_waf    = true
enable_shield = false

# Database Configuration
enable_rds         = true
db_engine          = "sqlserver-ex"
db_instance_class  = "db.t3.medium"

# Backup and Recovery
backup_retention_days      = 14
enable_cross_region_backup = false

# Security - Moderate for staging
allowed_cidr_blocks = ["10.0.0.0/8", "172.16.0.0/12"]
