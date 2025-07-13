#!/bin/bash

# Enterprise Data Platform Deployment Script
# エンタープライズデータプラットフォーム統合デプロイメント

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/../config"
CONFIG_FILE="${CONFIG_DIR}/enterprise_data_platform_config.json"
LOG_FILE="/tmp/enterprise_platform_deploy_$(date +%Y%m%d_%H%M%S).log"

# Default values
ENVIRONMENT="dev"
REGION="us-east-1"
STACK_PREFIX="enterprise-data-platform"
DEPLOY_ALL=false
SKIP_TESTS=false
DRY_RUN=false

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

print_section() {
    echo -e "\n${BLUE}========================================${NC}" | tee -a "$LOG_FILE"
    echo -e "${BLUE}$1${NC}" | tee -a "$LOG_FILE"
    echo -e "${BLUE}========================================${NC}\n" | tee -a "$LOG_FILE"
}

usage() {
    cat << EOF
Usage: $0 [OPTIONS] [COMMAND]

Enterprise Data Platform Deployment Script

OPTIONS:
    -e, --environment ENV    Environment (dev, staging, prod) [default: dev]
    -r, --region REGION      AWS Region [default: us-east-1]
    -p, --prefix PREFIX      Stack name prefix [default: enterprise-data-platform]
    -c, --config FILE        Configuration file [default: config/enterprise_data_platform_config.json]
    -a, --all               Deploy all components
    -n, --dry-run           Show what would be deployed without executing
    -s, --skip-tests        Skip validation tests
    -h, --help              Show this help message

COMMANDS:
    infrastructure          Deploy infrastructure components (S3, VPC, IAM)
    kinesis                Deploy Kinesis streaming infrastructure
    etl                    Deploy ETL pipeline (Glue, Step Functions)
    analytics              Deploy analytics infrastructure (QuickSight)
    monitoring             Deploy monitoring infrastructure (CloudWatch)
    data-generators        Deploy data generation tools
    all                    Deploy all components (same as --all)
    validate               Validate deployment
    destroy                Destroy all resources (use with caution)

EXAMPLES:
    # Deploy complete platform for production
    $0 --environment prod --all

    # Deploy only Kinesis components for development
    $0 --environment dev kinesis

    # Dry run for staging environment
    $0 --environment staging --dry-run all

    # Deploy with custom configuration
    $0 --config my-config.json --environment prod all

EOF
}

check_prerequisites() {
    print_section "Checking Prerequisites"
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured"
        exit 1
    fi
    
    # Check jq
    if ! command -v jq &> /dev/null; then
        print_error "jq is not installed"
        exit 1
    fi
    
    # Check Python
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 is not installed"
        exit 1
    fi
    
    # Check configuration file
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_error "Configuration file not found: $CONFIG_FILE"
        exit 1
    fi
    
    # Validate JSON configuration
    if ! jq empty "$CONFIG_FILE" &> /dev/null; then
        print_error "Invalid JSON in configuration file: $CONFIG_FILE"
        exit 1
    fi
    
    print_status "All prerequisites satisfied"
}

setup_environment() {
    print_section "Setting Up Environment"
    
    # Export environment variables
    export AWS_REGION="$REGION"
    export ENVIRONMENT="$ENVIRONMENT"
    export STACK_PREFIX="$STACK_PREFIX"
    
    # Create temporary directories
    export TEMP_DIR="/tmp/enterprise_platform_$$"
    mkdir -p "$TEMP_DIR"
    
    # Extract configuration values
    export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    export PROJECT_NAME=$(jq -r '.data_platform.name' "$CONFIG_FILE")
    
    print_status "Environment: $ENVIRONMENT"
    print_status "Region: $REGION"
    print_status "AWS Account: $AWS_ACCOUNT_ID"
    print_status "Project: $PROJECT_NAME"
    
    # Validate region
    if ! aws ec2 describe-regions --region-names "$REGION" &> /dev/null; then
        print_error "Invalid AWS region: $REGION"
        exit 1
    fi
}

deploy_infrastructure() {
    print_section "Deploying Infrastructure Components"
    
    local stack_name="${STACK_PREFIX}-infrastructure-${ENVIRONMENT}"
    local template_file="${SCRIPT_DIR}/../cloudformation/infrastructure.yaml"
    
    if [[ ! -f "$template_file" ]]; then
        print_warning "Infrastructure template not found: $template_file"
        return 0
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_status "DRY RUN: Would deploy infrastructure stack: $stack_name"
        return 0
    fi
    
    print_status "Deploying infrastructure stack: $stack_name"
    
    aws cloudformation deploy \
        --template-file "$template_file" \
        --stack-name "$stack_name" \
        --parameter-overrides \
            EnvironmentName="$ENVIRONMENT" \
            ProjectName="$PROJECT_NAME" \
        --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
        --region "$REGION" \
        --tags \
            Environment="$ENVIRONMENT" \
            Project="$PROJECT_NAME" \
            DeployedBy="$(aws sts get-caller-identity --query Arn --output text)" \
            DeployedAt="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        || {
            print_error "Failed to deploy infrastructure stack"
            return 1
        }
    
    print_status "Infrastructure deployment completed"
}

deploy_kinesis() {
    print_section "Deploying Kinesis Streaming Infrastructure"
    
    local stack_name="${STACK_PREFIX}-kinesis-${ENVIRONMENT}"
    local template_file="${SCRIPT_DIR}/../4.1-データ収集と保存/4.1.1-Kinesisストリーミング/cloudformation/kinesis-streaming.yaml"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_status "DRY RUN: Would deploy Kinesis stack: $stack_name"
        return 0
    fi
    
    # Extract Kinesis configuration
    local shard_count=$(jq -r '.kinesis_streaming.shard_count' "$CONFIG_FILE")
    local retention_hours=$(jq -r '.kinesis_streaming.retention_hours' "$CONFIG_FILE")
    
    print_status "Deploying Kinesis stack: $stack_name"
    print_status "Shard count: $shard_count, Retention: ${retention_hours}h"
    
    aws cloudformation deploy \
        --template-file "$template_file" \
        --stack-name "$stack_name" \
        --parameter-overrides \
            EnvironmentName="$ENVIRONMENT" \
            ProjectName="$PROJECT_NAME" \
            ShardCount="$shard_count" \
            RetentionHours="$retention_hours" \
        --capabilities CAPABILITY_IAM \
        --region "$REGION" \
        --tags \
            Environment="$ENVIRONMENT" \
            Project="$PROJECT_NAME" \
            Component="Kinesis" \
        || {
            print_error "Failed to deploy Kinesis stack"
            return 1
        }
    
    # Deploy data generator
    deploy_data_generator "kinesis"
    
    print_status "Kinesis deployment completed"
}

deploy_etl() {
    print_section "Deploying ETL Pipeline Infrastructure"
    
    local stack_name="${STACK_PREFIX}-etl-${ENVIRONMENT}"
    local template_file="${SCRIPT_DIR}/../4.1-データ収集と保存/4.1.2-ETLパイプライン/cloudformation/etl-pipeline.yaml"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_status "DRY RUN: Would deploy ETL stack: $stack_name"
        return 0
    fi
    
    # Extract ETL configuration
    local raw_bucket=$(jq -r '.etl_pipeline.raw_bucket' "$CONFIG_FILE")
    local processed_bucket=$(jq -r '.etl_pipeline.processed_bucket' "$CONFIG_FILE")
    local curated_bucket=$(jq -r '.etl_pipeline.curated_bucket' "$CONFIG_FILE")
    local database_name=$(jq -r '.etl_pipeline.database_name' "$CONFIG_FILE")
    
    print_status "Deploying ETL stack: $stack_name"
    print_status "Raw bucket: $raw_bucket"
    print_status "Processed bucket: $processed_bucket"
    print_status "Curated bucket: $curated_bucket"
    
    aws cloudformation deploy \
        --template-file "$template_file" \
        --stack-name "$stack_name" \
        --parameter-overrides \
            EnvironmentName="$ENVIRONMENT" \
            ProjectName="$PROJECT_NAME" \
            GlueWorkerType="G.2X" \
            MaxWorkers="20" \
            DataRetentionDays="90" \
        --capabilities CAPABILITY_IAM \
        --region "$REGION" \
        --tags \
            Environment="$ENVIRONMENT" \
            Project="$PROJECT_NAME" \
            Component="ETL" \
        || {
            print_error "Failed to deploy ETL stack"
            return 1
        }
    
    # Upload ETL scripts
    upload_etl_scripts
    
    print_status "ETL deployment completed"
}

deploy_analytics() {
    print_section "Deploying Analytics Infrastructure"
    
    local stack_name="${STACK_PREFIX}-analytics-${ENVIRONMENT}"
    local template_file="${SCRIPT_DIR}/../4.2-可視化と分析/4.2.1-QuickSightダッシュボード/cloudformation/quicksight-dashboard.yaml"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_status "DRY RUN: Would deploy Analytics stack: $stack_name"
        return 0
    fi
    
    # Extract QuickSight configuration
    local edition=$(jq -r '.quicksight_dashboards.edition' "$CONFIG_FILE")
    local admin_email=$(jq -r '.quicksight_dashboards.admin_email // "admin@example.com"' "$CONFIG_FILE")
    local data_lake_bucket=$(jq -r '.etl_pipeline.curated_bucket' "$CONFIG_FILE")
    
    print_status "Deploying Analytics stack: $stack_name"
    print_status "QuickSight edition: $edition"
    print_status "Data lake bucket: $data_lake_bucket"
    
    aws cloudformation deploy \
        --template-file "$template_file" \
        --stack-name "$stack_name" \
        --parameter-overrides \
            EnvironmentName="$ENVIRONMENT" \
            ProjectName="$PROJECT_NAME" \
            QuickSightEdition="$edition" \
            AdminUserEmail="$admin_email" \
            DataLakeS3Bucket="$data_lake_bucket" \
        --capabilities CAPABILITY_IAM \
        --region "$REGION" \
        --tags \
            Environment="$ENVIRONMENT" \
            Project="$PROJECT_NAME" \
            Component="Analytics" \
        || {
            print_error "Failed to deploy Analytics stack"
            return 1
        }
    
    # Setup automated dashboards
    setup_automated_dashboards
    
    print_status "Analytics deployment completed"
}

deploy_monitoring() {
    print_section "Deploying Monitoring Infrastructure"
    
    local stack_name="${STACK_PREFIX}-monitoring-${ENVIRONMENT}"
    local template_file="${SCRIPT_DIR}/../4.2-可視化と分析/4.2.2-CloudWatchメトリクス/cloudformation/cloudwatch-metrics.yaml"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_status "DRY RUN: Would deploy Monitoring stack: $stack_name"
        return 0
    fi
    
    print_status "Deploying Monitoring stack: $stack_name"
    
    aws cloudformation deploy \
        --template-file "$template_file" \
        --stack-name "$stack_name" \
        --parameter-overrides \
            EnvironmentName="$ENVIRONMENT" \
            ProjectName="$PROJECT_NAME" \
            ApplicationName="$PROJECT_NAME" \
            AlertEmail="admin@example.com" \
            MonitoringLevel="advanced" \
        --capabilities CAPABILITY_IAM \
        --region "$REGION" \
        --tags \
            Environment="$ENVIRONMENT" \
            Project="$PROJECT_NAME" \
            Component="Monitoring" \
        || {
            print_error "Failed to deploy Monitoring stack"
            return 1
        }
    
    # Setup advanced monitoring
    setup_advanced_monitoring
    
    print_status "Monitoring deployment completed"
}

deploy_data_generator() {
    local component="$1"
    print_status "Deploying data generator for $component"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_status "DRY RUN: Would deploy data generator for $component"
        return 0
    fi
    
    case "$component" in
        "kinesis")
            local generator_script="${SCRIPT_DIR}/../4.1-データ収集と保存/4.1.1-Kinesisストリーミング/scripts/advanced_data_generator.py"
            local stream_name=$(jq -r '.kinesis_streaming.stream_name' "$CONFIG_FILE")
            
            if [[ -f "$generator_script" ]]; then
                print_status "Installing data generator dependencies"
                pip3 install boto3 faker numpy pandas --quiet
                
                print_status "Data generator ready for stream: $stream_name"
                print_status "Run: python3 $generator_script --stream-name $stream_name --events-per-second 10"
            fi
            ;;
    esac
}

upload_etl_scripts() {
    print_status "Uploading ETL scripts"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_status "DRY RUN: Would upload ETL scripts"
        return 0
    fi
    
    local scripts_bucket=$(jq -r '.etl_pipeline.scripts_bucket' "$CONFIG_FILE")
    local etl_script="${SCRIPT_DIR}/../4.1-データ収集と保存/4.1.2-ETLパイプライン/scripts/enterprise_etl_job.py"
    
    if [[ -f "$etl_script" ]]; then
        # Create bucket if it doesn't exist
        if ! aws s3 ls "s3://$scripts_bucket" &> /dev/null; then
            aws s3 mb "s3://$scripts_bucket" --region "$REGION"
        fi
        
        # Upload ETL script
        aws s3 cp "$etl_script" "s3://$scripts_bucket/scripts/" --region "$REGION"
        print_status "ETL script uploaded to s3://$scripts_bucket/scripts/"
    fi
}

setup_automated_dashboards() {
    print_status "Setting up automated dashboards"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_status "DRY RUN: Would setup automated dashboards"
        return 0
    fi
    
    local dashboard_script="${SCRIPT_DIR}/../4.2-可視化と分析/4.2.1-QuickSightダッシュボード/scripts/dashboard_automation.py"
    
    if [[ -f "$dashboard_script" ]]; then
        print_status "Installing dashboard automation dependencies"
        pip3 install boto3 --quiet
        
        print_status "Dashboard automation ready"
        print_status "Run: python3 $dashboard_script --account-id $AWS_ACCOUNT_ID --config-file $CONFIG_FILE create"
    fi
}

setup_advanced_monitoring() {
    print_status "Setting up advanced monitoring"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_status "DRY RUN: Would setup advanced monitoring"
        return 0
    fi
    
    local monitoring_script="${SCRIPT_DIR}/../4.2-可視化と分析/4.2.2-CloudWatchメトリクス/scripts/advanced_monitoring.py"
    
    if [[ -f "$monitoring_script" ]]; then
        print_status "Installing monitoring dependencies"
        pip3 install boto3 numpy pandas --quiet
        
        print_status "Advanced monitoring ready"
        print_status "Run: python3 $monitoring_script --config-file $CONFIG_FILE setup"
    fi
}

validate_deployment() {
    print_section "Validating Deployment"
    
    local validation_errors=0
    
    # Check CloudFormation stacks
    local stacks=(
        "${STACK_PREFIX}-infrastructure-${ENVIRONMENT}"
        "${STACK_PREFIX}-kinesis-${ENVIRONMENT}"
        "${STACK_PREFIX}-etl-${ENVIRONMENT}"
        "${STACK_PREFIX}-analytics-${ENVIRONMENT}"
        "${STACK_PREFIX}-monitoring-${ENVIRONMENT}"
    )
    
    for stack in "${stacks[@]}"; do
        if aws cloudformation describe-stacks --stack-name "$stack" --region "$REGION" &> /dev/null; then
            local status=$(aws cloudformation describe-stacks --stack-name "$stack" --region "$REGION" --query 'Stacks[0].StackStatus' --output text)
            if [[ "$status" == "CREATE_COMPLETE" || "$status" == "UPDATE_COMPLETE" ]]; then
                print_status "✓ Stack $stack: $status"
            else
                print_error "✗ Stack $stack: $status"
                ((validation_errors++))
            fi
        else
            print_warning "? Stack $stack: Not found (may not be deployed)"
        fi
    done
    
    # Check S3 buckets
    local buckets=(
        "$(jq -r '.etl_pipeline.raw_bucket' "$CONFIG_FILE")"
        "$(jq -r '.etl_pipeline.processed_bucket' "$CONFIG_FILE")"
        "$(jq -r '.etl_pipeline.curated_bucket' "$CONFIG_FILE")"
    )
    
    for bucket in "${buckets[@]}"; do
        if aws s3 ls "s3://$bucket" &> /dev/null; then
            print_status "✓ Bucket s3://$bucket: Accessible"
        else
            print_error "✗ Bucket s3://$bucket: Not accessible"
            ((validation_errors++))
        fi
    done
    
    # Check Kinesis stream
    local stream_name=$(jq -r '.kinesis_streaming.stream_name' "$CONFIG_FILE")
    if aws kinesis describe-stream --stream-name "$stream_name" --region "$REGION" &> /dev/null; then
        local status=$(aws kinesis describe-stream --stream-name "$stream_name" --region "$REGION" --query 'StreamDescription.StreamStatus' --output text)
        if [[ "$status" == "ACTIVE" ]]; then
            print_status "✓ Kinesis stream $stream_name: $status"
        else
            print_error "✗ Kinesis stream $stream_name: $status"
            ((validation_errors++))
        fi
    else
        print_error "✗ Kinesis stream $stream_name: Not found"
        ((validation_errors++))
    fi
    
    if [[ "$validation_errors" -eq 0 ]]; then
        print_status "✓ All validation checks passed"
        return 0
    else
        print_error "✗ $validation_errors validation errors found"
        return 1
    fi
}

destroy_resources() {
    print_section "Destroying Resources"
    
    print_warning "This will destroy ALL resources for environment: $ENVIRONMENT"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_status "DRY RUN: Would destroy all stacks"
        return 0
    fi
    
    read -p "Are you sure you want to continue? Type 'yes' to confirm: " confirm
    if [[ "$confirm" != "yes" ]]; then
        print_status "Destruction cancelled"
        return 0
    fi
    
    # Delete stacks in reverse order
    local stacks=(
        "${STACK_PREFIX}-monitoring-${ENVIRONMENT}"
        "${STACK_PREFIX}-analytics-${ENVIRONMENT}"
        "${STACK_PREFIX}-etl-${ENVIRONMENT}"
        "${STACK_PREFIX}-kinesis-${ENVIRONMENT}"
        "${STACK_PREFIX}-infrastructure-${ENVIRONMENT}"
    )
    
    for stack in "${stacks[@]}"; do
        if aws cloudformation describe-stacks --stack-name "$stack" --region "$REGION" &> /dev/null; then
            print_status "Deleting stack: $stack"
            aws cloudformation delete-stack --stack-name "$stack" --region "$REGION"
            
            print_status "Waiting for stack deletion: $stack"
            aws cloudformation wait stack-delete-complete --stack-name "$stack" --region "$REGION" || {
                print_warning "Stack deletion may have failed: $stack"
            }
        else
            print_status "Stack not found (already deleted): $stack"
        fi
    done
    
    print_status "Resource destruction completed"
}

cleanup() {
    if [[ -n "${TEMP_DIR:-}" && -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}

trap cleanup EXIT

main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -e|--environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -r|--region)
                REGION="$2"
                shift 2
                ;;
            -p|--prefix)
                STACK_PREFIX="$2"
                shift 2
                ;;
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -a|--all)
                DEPLOY_ALL=true
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -s|--skip-tests)
                SKIP_TESTS=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                break
                ;;
        esac
    done
    
    # Get command
    COMMAND="${1:-}"
    
    # Set deployment components based on command or --all flag
    if [[ "$DEPLOY_ALL" == "true" || "$COMMAND" == "all" ]]; then
        COMPONENTS=("infrastructure" "kinesis" "etl" "analytics" "monitoring")
    elif [[ -n "$COMMAND" ]]; then
        case "$COMMAND" in
            infrastructure|kinesis|etl|analytics|monitoring|data-generators)
                COMPONENTS=("$COMMAND")
                ;;
            validate)
                COMPONENTS=()
                ;;
            destroy)
                COMPONENTS=()
                ;;
            *)
                print_error "Unknown command: $COMMAND"
                usage
                exit 1
                ;;
        esac
    else
        print_error "No command specified"
        usage
        exit 1
    fi
    
    # Start deployment
    print_section "Enterprise Data Platform Deployment"
    print_status "Starting deployment at $(date)"
    print_status "Log file: $LOG_FILE"
    
    # Prerequisites check
    check_prerequisites
    
    # Environment setup
    setup_environment
    
    # Execute based on command
    case "$COMMAND" in
        validate)
            if [[ "$SKIP_TESTS" == "false" ]]; then
                validate_deployment
            fi
            ;;
        destroy)
            destroy_resources
            ;;
        *)
            # Deploy components
            local exit_code=0
            
            for component in "${COMPONENTS[@]}"; do
                case "$component" in
                    infrastructure)
                        deploy_infrastructure || ((exit_code++))
                        ;;
                    kinesis)
                        deploy_kinesis || ((exit_code++))
                        ;;
                    etl)
                        deploy_etl || ((exit_code++))
                        ;;
                    analytics)
                        deploy_analytics || ((exit_code++))
                        ;;
                    monitoring)
                        deploy_monitoring || ((exit_code++))
                        ;;
                    data-generators)
                        deploy_data_generator "kinesis" || ((exit_code++))
                        ;;
                esac
            done
            
            # Validation
            if [[ "$SKIP_TESTS" == "false" && "$exit_code" -eq 0 ]]; then
                validate_deployment || ((exit_code++))
            fi
            
            if [[ "$exit_code" -eq 0 ]]; then
                print_section "Deployment Completed Successfully"
                print_status "All components deployed successfully"
                print_status "Environment: $ENVIRONMENT"
                print_status "Region: $REGION"
                print_status "Log file: $LOG_FILE"
            else
                print_section "Deployment Completed with Errors"
                print_error "$exit_code components failed to deploy"
                exit 1
            fi
            ;;
    esac
}

# Execute main function
main "$@"