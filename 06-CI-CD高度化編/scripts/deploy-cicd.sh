#!/bin/bash

# CI/CD Infrastructure Deployment Script
# Usage: ./deploy-cicd.sh [OPTIONS] COMMAND
# Commands: deploy-all, deploy-pipeline, deploy-testing, deploy-monitoring, deploy-optimization, status, cleanup

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="${PROJECT_ROOT}/parameters/my-config.json"

# Default values
AWS_REGION="${AWS_REGION:-ap-northeast-1}"
APPLICATION_NAME="${APPLICATION_NAME:-my-web-app}"
ENVIRONMENT="${ENVIRONMENT:-production}"

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

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI not found. Please install AWS CLI."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured. Please run 'aws configure'."
        exit 1
    fi
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_warning "Docker not found. Some features may not work."
    fi
    
    # Check GitHub CLI
    if ! command -v gh &> /dev/null; then
        log_warning "GitHub CLI not found. GitHub integration will be limited."
    fi
    
    log_success "Prerequisites check completed"
}

# Load configuration
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        log_info "Loading configuration from $CONFIG_FILE"
        
        # Extract values from JSON config
        APPLICATION_NAME=$(jq -r '.ApplicationName // "my-web-app"' "$CONFIG_FILE")
        ENVIRONMENT=$(jq -r '.Environment // "production"' "$CONFIG_FILE")
        AWS_REGION=$(jq -r '.Region // "ap-northeast-1"' "$CONFIG_FILE")
        
        export APPLICATION_NAME ENVIRONMENT AWS_REGION
        
        log_info "Configuration: App=$APPLICATION_NAME, Env=$ENVIRONMENT, Region=$AWS_REGION"
    else
        log_warning "Configuration file not found: $CONFIG_FILE"
        log_info "Using default values: App=$APPLICATION_NAME, Env=$ENVIRONMENT, Region=$AWS_REGION"
    fi
}

# Create parameter files from config
create_parameter_files() {
    local template_dir="$1"
    local params_file="$2"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Configuration file not found: $CONFIG_FILE"
        return 1
    fi
    
    # Generate parameters JSON for CloudFormation
    cat > "$params_file" << EOF
[
  {
    "ParameterKey": "ApplicationName",
    "ParameterValue": "$APPLICATION_NAME"
  },
  {
    "ParameterKey": "Environment",
    "ParameterValue": "$ENVIRONMENT"
  }
]
EOF
    
    # Add additional parameters from config
    jq -r '.Parameters // {} | to_entries[] | {ParameterKey: .key, ParameterValue: .value}' "$CONFIG_FILE" | \
    jq -s '.' >> "$params_file.tmp" && mv "$params_file.tmp" "$params_file" 2>/dev/null || true
    
    log_info "Parameters file created: $params_file"
}

# Deploy CloudFormation stack
deploy_stack() {
    local stack_name="$1"
    local template_file="$2"
    local parameters_file="$3"
    local capabilities="${4:-CAPABILITY_IAM}"
    
    log_info "Deploying stack: $stack_name"
    
    # Check if stack exists
    if aws cloudformation describe-stacks --stack-name "$stack_name" &> /dev/null; then
        log_info "Stack $stack_name exists, updating..."
        aws cloudformation update-stack \
            --stack-name "$stack_name" \
            --template-body "file://$template_file" \
            --parameters "file://$parameters_file" \
            --capabilities "$capabilities" \
            --region "$AWS_REGION"
    else
        log_info "Creating new stack: $stack_name"
        aws cloudformation create-stack \
            --stack-name "$stack_name" \
            --template-body "file://$template_file" \
            --parameters "file://$parameters_file" \
            --capabilities "$capabilities" \
            --region "$AWS_REGION"
    fi
    
    log_info "Waiting for stack operation to complete..."
    aws cloudformation wait stack-update-complete --stack-name "$stack_name" --region "$AWS_REGION" 2>/dev/null || \
    aws cloudformation wait stack-create-complete --stack-name "$stack_name" --region "$AWS_REGION"
    
    log_success "Stack $stack_name deployed successfully"
}

# Deploy pipeline infrastructure
deploy_pipeline() {
    log_info "Deploying CI/CD pipeline infrastructure..."
    
    local stack_name="${APPLICATION_NAME}-${ENVIRONMENT}-pipeline"
    local template_file="${PROJECT_ROOT}/6.1-自動化パイプライン/6.1.1-マルチステージビルド/cloudformation/codepipeline-multistage.yaml"
    local params_file="/tmp/${stack_name}-params.json"
    
    create_parameter_files "$template_file" "$params_file"
    
    # Add pipeline-specific parameters
    jq '. += [
        {"ParameterKey": "GitHubRepo", "ParameterValue": "'${GITHUB_REPO:-"user/repo"}'"},
        {"ParameterKey": "GitHubToken", "ParameterValue": "'${GITHUB_TOKEN:-"dummy"}'"},
        {"ParameterKey": "NotificationEmail", "ParameterValue": "'${NOTIFICATION_EMAIL:-"admin@example.com"}'"} 
    ]' "$params_file" > "$params_file.tmp" && mv "$params_file.tmp" "$params_file"
    
    deploy_stack "$stack_name" "$template_file" "$params_file" "CAPABILITY_NAMED_IAM"
    
    # Get pipeline URL
    local pipeline_url=$(aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --query 'Stacks[0].Outputs[?OutputKey==`PipelineUrl`].OutputValue' \
        --output text \
        --region "$AWS_REGION")
    
    log_success "Pipeline deployed: $pipeline_url"
}

# Deploy testing infrastructure
deploy_testing() {
    log_info "Deploying testing infrastructure..."
    
    local stack_name="${APPLICATION_NAME}-${ENVIRONMENT}-testing"
    local template_file="${PROJECT_ROOT}/6.1-自動化パイプライン/6.1.2-テスト自動化/cloudformation/test-automation.yaml"
    local params_file="/tmp/${stack_name}-params.json"
    
    create_parameter_files "$template_file" "$params_file"
    deploy_stack "$stack_name" "$template_file" "$params_file"
    
    log_success "Testing infrastructure deployed"
}

# Deploy Blue/Green deployment
deploy_blue_green() {
    log_info "Deploying Blue/Green deployment infrastructure..."
    
    local stack_name="${APPLICATION_NAME}-${ENVIRONMENT}-blue-green"
    local template_file="${PROJECT_ROOT}/6.2-高度なデプロイ戦略/6.2.1-BlueGreenデプロイ/cloudformation/blue-green-ecs.yaml"
    local params_file="/tmp/${stack_name}-params.json"
    
    # Get VPC and subnet info from existing web application stack
    local web_stack_name="${APPLICATION_NAME}-web-stack"
    local vpc_id=$(aws cloudformation describe-stacks \
        --stack-name "$web_stack_name" \
        --query 'Stacks[0].Outputs[?OutputKey==`VpcId`].OutputValue' \
        --output text \
        --region "$AWS_REGION" 2>/dev/null || echo "")
    
    if [[ -z "$vpc_id" ]]; then
        log_error "VPC ID not found. Please deploy the web application stack first."
        return 1
    fi
    
    create_parameter_files "$template_file" "$params_file"
    
    # Add Blue/Green specific parameters
    jq '. += [
        {"ParameterKey": "VpcId", "ParameterValue": "'$vpc_id'"},
        {"ParameterKey": "NotificationEmail", "ParameterValue": "'${NOTIFICATION_EMAIL:-"admin@example.com"}'"} 
    ]' "$params_file" > "$params_file.tmp" && mv "$params_file.tmp" "$params_file"
    
    deploy_stack "$stack_name" "$template_file" "$params_file" "CAPABILITY_NAMED_IAM"
    
    log_success "Blue/Green deployment infrastructure deployed"
}

# Deploy monitoring infrastructure
deploy_monitoring() {
    log_info "Deploying monitoring and APM infrastructure..."
    
    local stack_name="${APPLICATION_NAME}-${ENVIRONMENT}-monitoring"
    local template_file="${PROJECT_ROOT}/6.3-モニタリングと最適化/6.3.1-APM実装/cloudformation/comprehensive-monitoring.yaml"
    local params_file="/tmp/${stack_name}-params.json"
    
    create_parameter_files "$template_file" "$params_file"
    
    # Add monitoring-specific parameters
    jq '. += [
        {"ParameterKey": "AlertEmail", "ParameterValue": "'${ALERT_EMAIL:-"admin@example.com"}'"},
        {"ParameterKey": "SlackWebhookUrl", "ParameterValue": "'${SLACK_WEBHOOK_URL:-""}'"},
        {"ParameterKey": "PagerDutyRoutingKey", "ParameterValue": "'${PAGERDUTY_ROUTING_KEY:-""}'"} 
    ]' "$params_file" > "$params_file.tmp" && mv "$params_file.tmp" "$params_file"
    
    deploy_stack "$stack_name" "$template_file" "$params_file"
    
    # Get dashboard URL
    local dashboard_url=$(aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --query 'Stacks[0].Outputs[?OutputKey==`DashboardURL`].OutputValue' \
        --output text \
        --region "$AWS_REGION")
    
    log_success "Monitoring infrastructure deployed"
    log_info "Dashboard URL: $dashboard_url"
}

# Deploy cost optimization
deploy_optimization() {
    log_info "Deploying cost optimization infrastructure..."
    
    local stack_name="${APPLICATION_NAME}-${ENVIRONMENT}-cost-optimization"
    local template_file="${PROJECT_ROOT}/6.3-モニタリングと最適化/6.3.2-コスト最適化/cloudformation/cost-optimization.yaml"
    local params_file="/tmp/${stack_name}-params.json"
    
    create_parameter_files "$template_file" "$params_file"
    
    # Add cost optimization parameters
    jq '. += [
        {"ParameterKey": "MonthlyBudget", "ParameterValue": "'${MONTHLY_BUDGET:-"500"}'"},
        {"ParameterKey": "AlertEmail", "ParameterValue": "'${ALERT_EMAIL:-"admin@example.com"}'"} 
    ]' "$params_file" > "$params_file.tmp" && mv "$params_file.tmp" "$params_file"
    
    deploy_stack "$stack_name" "$template_file" "$params_file"
    
    log_success "Cost optimization infrastructure deployed"
}

# Deploy all infrastructure
deploy_all() {
    log_info "Starting complete CI/CD infrastructure deployment..."
    
    check_prerequisites
    load_config
    
    # Deploy in dependency order
    deploy_pipeline
    deploy_testing
    deploy_blue_green
    deploy_monitoring
    deploy_optimization
    
    log_success "All CI/CD infrastructure deployed successfully!"
    
    # Display summary
    show_deployment_summary
}

# Show deployment status
show_status() {
    log_info "Checking CI/CD infrastructure status..."
    
    local stacks=(
        "${APPLICATION_NAME}-${ENVIRONMENT}-pipeline"
        "${APPLICATION_NAME}-${ENVIRONMENT}-testing"
        "${APPLICATION_NAME}-${ENVIRONMENT}-blue-green"
        "${APPLICATION_NAME}-${ENVIRONMENT}-monitoring"
        "${APPLICATION_NAME}-${ENVIRONMENT}-cost-optimization"
    )
    
    echo
    printf "%-40s %-20s %-15s\n" "Stack Name" "Status" "Last Updated"
    printf "%-40s %-20s %-15s\n" "----------" "------" "------------"
    
    for stack in "${stacks[@]}"; do
        local status=$(aws cloudformation describe-stacks \
            --stack-name "$stack" \
            --query 'Stacks[0].StackStatus' \
            --output text \
            --region "$AWS_REGION" 2>/dev/null || echo "NOT_FOUND")
        
        local last_updated=""
        if [[ "$status" != "NOT_FOUND" ]]; then
            last_updated=$(aws cloudformation describe-stacks \
                --stack-name "$stack" \
                --query 'Stacks[0].LastUpdatedTime' \
                --output text \
                --region "$AWS_REGION" 2>/dev/null || echo "N/A")
        fi
        
        printf "%-40s %-20s %-15s\n" "$stack" "$status" "${last_updated:0:10}"
    done
    echo
}

# Show deployment summary
show_deployment_summary() {
    log_info "Deployment Summary:"
    echo
    
    # Pipeline URL
    local pipeline_stack="${APPLICATION_NAME}-${ENVIRONMENT}-pipeline"
    local pipeline_url=$(aws cloudformation describe-stacks \
        --stack-name "$pipeline_stack" \
        --query 'Stacks[0].Outputs[?OutputKey==`PipelineUrl`].OutputValue' \
        --output text \
        --region "$AWS_REGION" 2>/dev/null || echo "Not available")
    
    # Dashboard URL
    local monitoring_stack="${APPLICATION_NAME}-${ENVIRONMENT}-monitoring"
    local dashboard_url=$(aws cloudformation describe-stacks \
        --stack-name "$monitoring_stack" \
        --query 'Stacks[0].Outputs[?OutputKey==`DashboardURL`].OutputValue' \
        --output text \
        --region "$AWS_REGION" 2>/dev/null || echo "Not available")
    
    # Load Balancer URL
    local blue_green_stack="${APPLICATION_NAME}-${ENVIRONMENT}-blue-green"
    local alb_url=$(aws cloudformation describe-stacks \
        --stack-name "$blue_green_stack" \
        --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerURL`].OutputValue' \
        --output text \
        --region "$AWS_REGION" 2>/dev/null || echo "Not available")
    
    echo "🚀 CI/CD Pipeline: $pipeline_url"
    echo "📊 Monitoring Dashboard: $dashboard_url"
    echo "🌐 Application URL: $alb_url"
    echo
    echo "Next steps:"
    echo "1. Configure GitHub repository secrets for CI/CD"
    echo "2. Push code to trigger the pipeline"
    echo "3. Monitor deployment in the dashboard"
    echo "4. Set up additional alerting as needed"
    echo
}

# Cleanup all resources
cleanup() {
    log_warning "This will delete ALL CI/CD infrastructure. Are you sure? (y/N)"
    read -r confirmation
    
    if [[ "$confirmation" != "y" && "$confirmation" != "Y" ]]; then
        log_info "Cleanup cancelled"
        return 0
    fi
    
    log_info "Cleaning up CI/CD infrastructure..."
    
    local stacks=(
        "${APPLICATION_NAME}-${ENVIRONMENT}-cost-optimization"
        "${APPLICATION_NAME}-${ENVIRONMENT}-monitoring"
        "${APPLICATION_NAME}-${ENVIRONMENT}-blue-green"
        "${APPLICATION_NAME}-${ENVIRONMENT}-testing"
        "${APPLICATION_NAME}-${ENVIRONMENT}-pipeline"
    )
    
    for stack in "${stacks[@]}"; do
        if aws cloudformation describe-stacks --stack-name "$stack" &> /dev/null; then
            log_info "Deleting stack: $stack"
            aws cloudformation delete-stack --stack-name "$stack" --region "$AWS_REGION"
        fi
    done
    
    log_info "Waiting for stack deletions to complete..."
    for stack in "${stacks[@]}"; do
        if aws cloudformation describe-stacks --stack-name "$stack" &> /dev/null; then
            aws cloudformation wait stack-delete-complete --stack-name "$stack" --region "$AWS_REGION"
        fi
    done
    
    log_success "Cleanup completed"
}

# Help function
show_help() {
    cat << EOF
CI/CD Infrastructure Deployment Script

Usage: $0 [OPTIONS] COMMAND

Commands:
  deploy-all          Deploy complete CI/CD infrastructure
  deploy-pipeline     Deploy CI/CD pipeline only
  deploy-testing      Deploy testing infrastructure only
  deploy-blue-green   Deploy Blue/Green deployment infrastructure
  deploy-monitoring   Deploy monitoring and APM infrastructure
  deploy-optimization Deploy cost optimization infrastructure
  status              Show deployment status
  cleanup             Delete all CI/CD infrastructure
  help                Show this help message

Options:
  --config FILE       Configuration file path (default: parameters/my-config.json)
  --region REGION     AWS region (default: ap-northeast-1)
  --app-name NAME     Application name (default: my-web-app)
  --environment ENV   Environment name (default: production)

Environment Variables:
  AWS_REGION              AWS region
  APPLICATION_NAME        Application name
  ENVIRONMENT            Environment name
  GITHUB_REPO            GitHub repository (user/repo)
  GITHUB_TOKEN           GitHub access token
  NOTIFICATION_EMAIL     Email for notifications
  ALERT_EMAIL            Email for alerts
  SLACK_WEBHOOK_URL      Slack webhook URL
  PAGERDUTY_ROUTING_KEY  PagerDuty routing key
  MONTHLY_BUDGET         Monthly budget for cost optimization

Examples:
  $0 deploy-all
  $0 --config custom-config.json deploy-pipeline
  $0 --app-name my-app --environment staging deploy-monitoring
  $0 status
  $0 cleanup

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --region)
            AWS_REGION="$2"
            shift 2
            ;;
        --app-name)
            APPLICATION_NAME="$2"
            shift 2
            ;;
        --environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        deploy-all)
            COMMAND="deploy-all"
            shift
            ;;
        deploy-pipeline)
            COMMAND="deploy-pipeline"
            shift
            ;;
        deploy-testing)
            COMMAND="deploy-testing"
            shift
            ;;
        deploy-blue-green)
            COMMAND="deploy-blue-green"
            shift
            ;;
        deploy-monitoring)
            COMMAND="deploy-monitoring"
            shift
            ;;
        deploy-optimization)
            COMMAND="deploy-optimization"
            shift
            ;;
        status)
            COMMAND="status"
            shift
            ;;
        cleanup)
            COMMAND="cleanup"
            shift
            ;;
        help)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Execute command
case "${COMMAND:-help}" in
    deploy-all)
        deploy_all
        ;;
    deploy-pipeline)
        check_prerequisites
        load_config
        deploy_pipeline
        ;;
    deploy-testing)
        check_prerequisites
        load_config
        deploy_testing
        ;;
    deploy-blue-green)
        check_prerequisites
        load_config
        deploy_blue_green
        ;;
    deploy-monitoring)
        check_prerequisites
        load_config
        deploy_monitoring
        ;;
    deploy-optimization)
        check_prerequisites
        load_config
        deploy_optimization
        ;;
    status)
        load_config
        show_status
        ;;
    cleanup)
        load_config
        cleanup
        ;;
    help)
        show_help
        ;;
    *)
        log_error "No command specified"
        show_help
        exit 1
        ;;
esac