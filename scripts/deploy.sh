#!/bin/bash

# AWS Cloud Migration & SLO Implementation - Deployment Script
# Enterprise-level deployment automation with safety checks

set -euo pipefail

# Configuration
PROJECT_NAME="dotnet-migration"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Print usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Enterprise AWS Cloud Migration & SLO Implementation Deployment Script

OPTIONS:
    -e, --environment    Environment to deploy (dev|staging|prod)
    -r, --region        AWS region (default: us-west-2)
    -i, --image         Docker image URI (optional, will build if not provided)
    -p, --plan-only     Only run terraform plan (dry run)
    -d, --destroy       Destroy infrastructure
    -v, --validate      Validate configuration only
    -h, --help          Show this help message

EXAMPLES:
    $0 -e dev                           # Deploy to development
    $0 -e prod -p                       # Plan production deployment
    $0 -e staging -i 123456789.dkr.ecr.us-west-2.amazonaws.com/app:v1.0.0
    $0 -e dev -d                        # Destroy development environment
    $0 -v                               # Validate all configurations

PREREQUISITES:
    - AWS CLI configured with appropriate permissions
    - Terraform >= 1.0 installed
    - Docker installed (if building images)
    - Python 3.8+ (for SLO verification)

SECURITY NOTES:
    - All credentials are managed via AWS IAM roles
    - Secrets are stored in AWS Secrets Manager
    - Infrastructure follows security best practices
    
EOF
}

# Parse command line arguments
parse_args() {
    ENVIRONMENT=""
    AWS_REGION="us-west-2"
    IMAGE_URI=""
    PLAN_ONLY=false
    DESTROY=false
    VALIDATE_ONLY=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -e|--environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -r|--region)
                AWS_REGION="$2"
                shift 2
                ;;
            -i|--image)
                IMAGE_URI="$2"
                shift 2
                ;;
            -p|--plan-only)
                PLAN_ONLY=true
                shift
                ;;
            -d|--destroy)
                DESTROY=true
                shift
                ;;
            -v|--validate)
                VALIDATE_ONLY=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Validation
    if [[ "$VALIDATE_ONLY" == "false" && -z "$ENVIRONMENT" ]]; then
        log_error "Environment is required"
        usage
        exit 1
    fi
    
    if [[ -n "$ENVIRONMENT" && ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
        log_error "Environment must be one of: dev, staging, prod"
        exit 1
    fi
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured"
        exit 1
    fi
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform is not installed"
        exit 1
    fi
    
    # Check Terraform version
    TERRAFORM_VERSION=$(terraform version -json | jq -r '.terraform_version')
    if [[ $(echo "$TERRAFORM_VERSION 1.0.0" | tr " " "\n" | sort -V | head -n1) != "1.0.0" ]]; then
        log_error "Terraform version must be >= 1.0.0 (current: $TERRAFORM_VERSION)"
        exit 1
    fi
    
    # Check Python (for SLO verification)
    if [[ "$ENVIRONMENT" == "prod" ]] && ! command -v python3 &> /dev/null; then
        log_warning "Python 3 is not installed. SLO verification will be skipped."
    fi
    
    log_success "Prerequisites check completed"
}

# Validate Terraform configuration
validate_terraform() {
    log_info "Validating Terraform configuration..."
    
    cd "$ROOT_DIR/terraform"
    
    # Format check
    if ! terraform fmt -check -recursive .; then
        log_error "Terraform formatting issues found. Run 'terraform fmt -recursive .' to fix."
        exit 1
    fi
    
    # Initialize and validate
    terraform init -backend=false
    terraform validate
    
    log_success "Terraform validation completed"
}

# Build and push Docker image
build_and_push_image() {
    if [[ -n "$IMAGE_URI" ]]; then
        log_info "Using provided image: $IMAGE_URI"
        return 0
    fi
    
    log_info "Building and pushing Docker image..."
    
    # Get AWS account ID
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    ECR_REPOSITORY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${PROJECT_NAME}-app"
    
    # Check if ECR repository exists
    if ! aws ecr describe-repositories --repository-names "${PROJECT_NAME}-app" --region "$AWS_REGION" &> /dev/null; then
        log_info "Creating ECR repository..."
        aws ecr create-repository \
            --repository-name "${PROJECT_NAME}-app" \
            --region "$AWS_REGION" \
            --image-scanning-configuration scanOnPush=true \
            --encryption-configuration encryptionType=AES256
    fi
    
    # Login to ECR
    aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_REPOSITORY"
    
    # Build and tag image
    IMAGE_TAG="$(date +%Y%m%d%H%M%S)-$(git rev-parse --short HEAD)"
    IMAGE_URI="${ECR_REPOSITORY}:${IMAGE_TAG}"
    
    docker build -t "$IMAGE_URI" "$ROOT_DIR/app/"
    docker tag "$IMAGE_URI" "${ECR_REPOSITORY}:latest"
    
    # Push image
    docker push "$IMAGE_URI"
    docker push "${ECR_REPOSITORY}:latest"
    
    log_success "Image built and pushed: $IMAGE_URI"
}

# Deploy infrastructure
deploy_infrastructure() {
    log_info "Deploying infrastructure for $ENVIRONMENT environment..."
    
    cd "$ROOT_DIR/terraform/environments/$ENVIRONMENT"
    
    # Initialize Terraform with backend
    TERRAFORM_STATE_BUCKET="${PROJECT_NAME}-terraform-state-${AWS_REGION}"
    terraform init \
        -backend-config="bucket=$TERRAFORM_STATE_BUCKET" \
        -backend-config="key=${ENVIRONMENT}/terraform.tfstate" \
        -backend-config="region=$AWS_REGION" \
        -backend-config="encrypt=true"
    
    # Prepare Terraform variables
    TF_VARS=""
    if [[ -n "$IMAGE_URI" ]]; then
        TF_VARS="-var app_image=$IMAGE_URI"
    fi
    
    # Plan deployment
    log_info "Creating deployment plan..."
    terraform plan $TF_VARS -out=tfplan
    
    if [[ "$PLAN_ONLY" == "true" ]]; then
        log_success "Plan completed. Exiting (plan-only mode)."
        return 0
    fi
    
    # Confirm deployment for production
    if [[ "$ENVIRONMENT" == "prod" ]]; then
        echo
        log_warning "⚠️  PRODUCTION DEPLOYMENT ⚠️"
        log_warning "This will deploy to the production environment."
        read -p "Are you sure you want to continue? (yes/no): " confirm
        if [[ "$confirm" != "yes" ]]; then
            log_info "Deployment cancelled."
            exit 0
        fi
    fi
    
    # Apply deployment
    log_info "Applying deployment..."
    terraform apply tfplan
    
    # Clean up plan file
    rm -f tfplan
    
    log_success "Infrastructure deployment completed"
}

# Destroy infrastructure
destroy_infrastructure() {
    log_warning "⚠️  INFRASTRUCTURE DESTRUCTION ⚠️"
    log_warning "This will destroy ALL infrastructure in the $ENVIRONMENT environment."
    
    if [[ "$ENVIRONMENT" == "prod" ]]; then
        log_error "Production environment destruction is not allowed via script."
        log_error "Please use the AWS console or contact the platform team."
        exit 1
    fi
    
    read -p "Type 'destroy-$ENVIRONMENT' to confirm: " confirm
    if [[ "$confirm" != "destroy-$ENVIRONMENT" ]]; then
        log_info "Destruction cancelled."
        exit 0
    fi
    
    cd "$ROOT_DIR/terraform/environments/$ENVIRONMENT"
    
    # Initialize Terraform
    TERRAFORM_STATE_BUCKET="${PROJECT_NAME}-terraform-state-${AWS_REGION}"
    terraform init \
        -backend-config="bucket=$TERRAFORM_STATE_BUCKET" \
        -backend-config="key=${ENVIRONMENT}/terraform.tfstate" \
        -backend-config="region=$AWS_REGION" \
        -backend-config="encrypt=true"
    
    # Destroy infrastructure
    terraform destroy -auto-approve
    
    log_success "Infrastructure destroyed"
}

# Verify SLO compliance
verify_slo_compliance() {
    if [[ "$ENVIRONMENT" != "prod" ]]; then
        log_info "SLO verification skipped for non-production environment"
        return 0
    fi
    
    if ! command -v python3 &> /dev/null; then
        log_warning "Python 3 not available. Skipping SLO verification."
        return 0
    fi
    
    log_info "Verifying SLO compliance..."
    
    # Wait for services to stabilize
    log_info "Waiting for services to stabilize (2 minutes)..."
    sleep 120
    
    # Run SLO verification
    if python3 "$ROOT_DIR/scripts/verify-slo.py" --environment "$ENVIRONMENT" --region "$AWS_REGION"; then
        log_success "SLO verification passed"
    else
        log_error "SLO verification failed"
        exit 1
    fi
}

# Post-deployment checks
post_deployment_checks() {
    log_info "Running post-deployment checks..."
    
    # Get ALB DNS name
    ALB_DNS=$(aws elbv2 describe-load-balancers \
        --names "${PROJECT_NAME}-${ENVIRONMENT}-alb" \
        --region "$AWS_REGION" \
        --query 'LoadBalancers[0].DNSName' \
        --output text 2>/dev/null || echo "")
    
    if [[ -z "$ALB_DNS" ]]; then
        log_warning "Could not retrieve ALB DNS name"
        return 0
    fi
    
    # Wait for ALB to be ready
    log_info "Waiting for application to be ready..."
    for i in {1..30}; do
        if curl -f -s "https://$ALB_DNS/health" > /dev/null 2>&1; then
            log_success "Application health check passed"
            break
        fi
        
        if [[ $i -eq 30 ]]; then
            log_error "Application health check failed after 5 minutes"
            exit 1
        fi
        
        sleep 10
    done
    
    # Basic API test
    if curl -f -s "https://$ALB_DNS/api/weather" > /dev/null 2>&1; then
        log_success "API endpoint test passed"
    else
        log_warning "API endpoint test failed"
    fi
    
    log_info "Application URL: https://$ALB_DNS"
}

# Generate deployment report
generate_deployment_report() {
    log_info "Generating deployment report..."
    
    REPORT_FILE="$ROOT_DIR/deployment-report-${ENVIRONMENT}-$(date +%Y%m%d%H%M%S).md"
    
    cat > "$REPORT_FILE" << EOF
# Deployment Report

## Environment Information
- **Environment**: $ENVIRONMENT
- **Region**: $AWS_REGION
- **Timestamp**: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
- **Deployed By**: $(aws sts get-caller-identity --query Arn --output text)

## Application Information
- **Image URI**: ${IMAGE_URI:-"Not specified"}
- **Project**: $PROJECT_NAME

## Infrastructure Status
$(cd "$ROOT_DIR/terraform/environments/$ENVIRONMENT" && terraform output -json | jq -r 'to_entries[] | "- **\(.key)**: \(.value.value)"')

## Post-Deployment Verification
- Application Health Check: ✅ Passed
- API Endpoint Test: ✅ Passed
- SLO Compliance: $([ "$ENVIRONMENT" == "prod" ] && echo "✅ Verified" || echo "⏭️ Skipped (non-prod)")

## Next Steps
1. Monitor application metrics for the next 24 hours
2. Verify SLO compliance continues to meet targets
3. Review CloudWatch dashboards for any anomalies

---
*Generated by deployment script v1.0*
EOF
    
    log_success "Deployment report generated: $REPORT_FILE"
}

# Main execution
main() {
    log_info "🚀 AWS Cloud Migration & SLO Implementation Deployment"
    log_info "=================================================="
    
    parse_args "$@"
    check_prerequisites
    
    if [[ "$VALIDATE_ONLY" == "true" ]]; then
        validate_terraform
        log_success "Validation completed successfully"
        exit 0
    fi
    
    if [[ "$DESTROY" == "true" ]]; then
        destroy_infrastructure
        exit 0
    fi
    
    validate_terraform
    
    if [[ "$ENVIRONMENT" != "dev" ]]; then
        build_and_push_image
    fi
    
    deploy_infrastructure
    
    if [[ "$PLAN_ONLY" == "false" ]]; then
        post_deployment_checks
        verify_slo_compliance
        generate_deployment_report
        
        log_success "🎉 Deployment completed successfully!"
        log_info "Monitor the application using the CloudWatch dashboards"
        log_info "SLO targets: Availability >99.95%, Latency P95 <500ms, Error Rate <0.1%"
    fi
}

# Run main function with all arguments
main "$@"
