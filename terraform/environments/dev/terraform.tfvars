# Development Environment Configuration
project_name = "dotnet-migration"
environment  = "dev"
aws_region   = "us-west-2"
owner        = "platform-team"
cost_center  = "engineering"

# Network Configuration
vpc_cidr = "10.0.0.0/16"
private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

# ECS Configuration
app_name      = "dotnet-app"
app_image     = "mcr.microsoft.com/dotnet/samples:aspnetapp"
app_port      = 80
desired_count = 1
cpu           = 256
memory        = 512

# Auto Scaling Configuration
min_capacity              = 1
max_capacity              = 5
target_cpu_utilization    = 70
target_memory_utilization = 80

# Monitoring Configuration
enable_synthetics    = true
synthetics_frequency = 5  # Every 5 minutes for dev
alert_email         = "dev-team@company.com"

# Security Configuration
enable_waf    = false  # Disabled for dev to reduce costs
enable_shield = false

# Database Configuration
enable_rds         = false  # Use managed database service for dev
db_engine          = "sqlserver-ex"
db_instance_class  = "db.t3.micro"

# Cost Optimization
backup_retention_days      = 7   # Shorter retention for dev
enable_cross_region_backup = false

# Security - Less restrictive for development
allowed_cidr_blocks = ["0.0.0.0/0"]
