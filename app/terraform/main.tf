provider "aws" {
  region = var.region
}

# VPC and Networking (Security: Isolated subnets)
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.13.0"

  name = "ecs-vpc"
  cidr = "10.0.0.0/16"
  azs  = ["${var.region}a", "${var.region}b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]
  enable_nat_gateway = true
  single_nat_gateway = true  # Cost optimization: Single NAT
}

# ECR for Docker image (Platform: Managed repo)
resource "aws_ecr_repository" "repo" {
  name = "dotnet-ecs-demo"
}

# ECS Cluster
resource "aws_ecs_cluster" "cluster" {
  name = "migration-demo-cluster"
}

# Task Definition (Optimized: Fargate for serverless)
resource "aws_ecs_task_definition" "task" {
  family                   = "dotnet-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"  # Optimized: Small CPU for demo (cost reduction)
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([{
    name      = "dotnet-container"
    image     = "${aws_ecr_repository.repo.repository_url}:latest"
    essential = true
    portMappings = [{ containerPort = 80, hostPort = 80 }]
  }])
}

# ECS Service with Auto-Scaling (SRE: Reliability, Cost: Scale to 0 when idle)
resource "aws_ecs_service" "service" {
  name            = "dotnet-service"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = module.vpc.private_subnets
    security_groups = [aws_security_group.ecs_sg.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.tg.arn
    container_name   = "dotnet-container"
    container_port   = 80
  }
}

# ALB for Public Access
resource "aws_lb" "alb" {
  name               = "ecs-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = module.vpc.public_subnets
}

resource "aws_lb_target_group" "tg" {
  name     = "ecs-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
  target_type = "ip"
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

# Auto-Scaling (Cost: Reduce instances based on CPU)
resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = 2
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.cluster.name}/${aws_ecs_service.service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "ecs_policy" {
  name               = "scale-on-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 50  # Scale at 50% CPU (optimization)
  }
}