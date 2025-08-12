# Production Environment Configuration
project_name = "dotnet-migration"
environment  = "prod"
aws_region   = "us-west-2"
owner        = "platform-team"
cost_center  = "engineering"

# Network Configuration
vpc_cidr = "10.1.0.0/16"
private_subnet_cidrs = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
public_subnet_cidrs  = ["10.1.101.0/24", "10.1.102.0/24", "10.1.103.0/24"]

# ECS Configuration
app_name      = "dotnet-app"
app_image     = "your-ecr-repo/dotnet-app:latest"  # Replace with your ECR repository
app_port      = 80
desired_count = 3
cpu           = 1024
memory        = 2048

# Auto Scaling Configuration
min_capacity              = 2
max_capacity              = 20
target_cpu_utilization    = 60
target_memory_utilization = 70

# Monitoring Configuration
enable_synthetics    = true
synthetics_frequency = 1  # Every minute for production
alert_email         = "alerts@company.com"

# Security Configuration
enable_waf    = true
enable_shield = true  # Enable Shield Advanced for production

# Database Configuration
enable_rds         = true
db_engine          = "sqlserver-se"
db_instance_class  = "db.r5.large"

# Backup and Recovery
backup_retention_days      = 30
enable_cross_region_backup = true

# Security - Restrictive for production
allowed_cidr_blocks = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]  # Private networks only
