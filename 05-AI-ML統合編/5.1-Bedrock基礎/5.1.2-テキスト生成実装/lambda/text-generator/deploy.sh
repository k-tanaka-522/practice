#!/bin/bash

# Amazon Bedrock Text Generation Service Deployment Script
# ========================================================
# 
# This script automates the deployment of the text generation Lambda functions
# including dependency packaging, optimization, and CloudFormation stack updates.
#
# Usage:
#   ./deploy.sh [environment] [region]
#
# Example:
#   ./deploy.sh dev us-east-1
#   ./deploy.sh prod ap-northeast-1
#
# Author: Claude AI Assistant
# License: MIT

set -e  # Exit on any error

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="text-generation"
DEFAULT_ENVIRONMENT="dev"
DEFAULT_REGION="us-east-1"

# Parameters
ENVIRONMENT="${1:-$DEFAULT_ENVIRONMENT}"
REGION="${2:-$DEFAULT_REGION}"
STACK_NAME="${PROJECT_NAME}-${ENVIRONMENT}"

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
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check if Python 3.9+ is available
    if ! command -v python3.9 &> /dev/null; then
        if ! command -v python3 &> /dev/null; then
            log_error "Python 3.9+ is required but not found."
            exit 1
        fi
        PYTHON_CMD="python3"
    else
        PYTHON_CMD="python3.9"
    fi
    
    # Check if pip is available
    if ! command -v pip3 &> /dev/null; then
        log_error "pip3 is not installed. Please install it first."
        exit 1
    fi
    
    # Check if zip is available
    if ! command -v zip &> /dev/null; then
        log_error "zip command is not available. Please install it first."
        exit 1
    fi
    
    # Verify AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured or invalid."
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Validate environment
validate_environment() {
    log_info "Validating environment: $ENVIRONMENT"
    
    case $ENVIRONMENT in
        dev|staging|prod)
            log_success "Environment '$ENVIRONMENT' is valid"
            ;;
        *)
            log_error "Invalid environment '$ENVIRONMENT'. Use: dev, staging, or prod"
            exit 1
            ;;
    esac
}

# Clean previous builds
clean_build() {
    log_info "Cleaning previous builds..."
    
    rm -rf "${SCRIPT_DIR}/build"
    rm -rf "${SCRIPT_DIR}/dist"
    rm -rf "${SCRIPT_DIR}/__pycache__"
    rm -rf "${SCRIPT_DIR}/.pytest_cache"
    rm -f "${SCRIPT_DIR}"/*.zip
    
    log_success "Build directory cleaned"
}

# Create build directories
create_build_dirs() {
    log_info "Creating build directories..."
    
    mkdir -p "${SCRIPT_DIR}/build/main"
    mkdir -p "${SCRIPT_DIR}/build/async"
    mkdir -p "${SCRIPT_DIR}/dist"
    
    log_success "Build directories created"
}

# Install dependencies
install_dependencies() {
    log_info "Installing dependencies..."
    
    # Create virtual environment for dependency resolution
    $PYTHON_CMD -m venv "${SCRIPT_DIR}/build/venv"
    source "${SCRIPT_DIR}/build/venv/bin/activate"
    
    # Upgrade pip
    pip install --upgrade pip
    
    # Install production dependencies only
    pip install --target "${SCRIPT_DIR}/build/main" \
        boto3 \
        botocore \
        jsonschema \
        pydantic \
        bleach \
        validators \
        cachetools \
        structlog \
        python-dateutil \
        pytz \
        cryptography \
        tenacity \
        backoff
    
    # Install same dependencies for async processor
    pip install --target "${SCRIPT_DIR}/build/async" \
        boto3 \
        botocore \
        jsonschema \
        pydantic \
        bleach \
        validators \
        cachetools \
        structlog \
        python-dateutil \
        pytz \
        cryptography \
        tenacity \
        backoff
    
    deactivate
    
    log_success "Dependencies installed"
}

# Copy source files
copy_source_files() {
    log_info "Copying source files..."
    
    # Copy main Lambda function
    cp "${SCRIPT_DIR}/app.py" "${SCRIPT_DIR}/build/main/"
    
    # Copy async processor
    cp "${SCRIPT_DIR}/async_processor.py" "${SCRIPT_DIR}/build/async/"
    cp "${SCRIPT_DIR}/app.py" "${SCRIPT_DIR}/build/async/"  # async_processor imports from app
    
    log_success "Source files copied"
}

# Optimize build
optimize_build() {
    log_info "Optimizing build..."
    
    # Remove unnecessary files to reduce package size
    find "${SCRIPT_DIR}/build" -name "*.pyc" -delete
    find "${SCRIPT_DIR}/build" -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
    find "${SCRIPT_DIR}/build" -name "*.dist-info" -type d -exec rm -rf {} + 2>/dev/null || true
    find "${SCRIPT_DIR}/build" -name "tests" -type d -exec rm -rf {} + 2>/dev/null || true
    find "${SCRIPT_DIR}/build" -name "test_*" -delete 2>/dev/null || true
    
    # Remove large unnecessary files
    find "${SCRIPT_DIR}/build" -name "*.so" -size +10M -delete 2>/dev/null || true
    
    log_success "Build optimized"
}

# Create deployment packages
create_packages() {
    log_info "Creating deployment packages..."
    
    # Create main Lambda package
    cd "${SCRIPT_DIR}/build/main"
    zip -r "../../dist/text-generation-main.zip" . -q
    
    # Create async processor package
    cd "${SCRIPT_DIR}/build/async"
    zip -r "../../dist/text-generation-async.zip" . -q
    
    cd "${SCRIPT_DIR}"
    
    # Get package sizes
    MAIN_SIZE=$(stat -c%s "${SCRIPT_DIR}/dist/text-generation-main.zip" 2>/dev/null || stat -f%z "${SCRIPT_DIR}/dist/text-generation-main.zip")
    ASYNC_SIZE=$(stat -c%s "${SCRIPT_DIR}/dist/text-generation-async.zip" 2>/dev/null || stat -f%z "${SCRIPT_DIR}/dist/text-generation-async.zip")
    
    log_success "Packages created:"
    log_info "  Main function: $(echo "scale=2; $MAIN_SIZE/1024/1024" | bc 2>/dev/null || echo $((MAIN_SIZE/1024/1024)))MB"
    log_info "  Async function: $(echo "scale=2; $ASYNC_SIZE/1024/1024" | bc 2>/dev/null || echo $((ASYNC_SIZE/1024/1024)))MB"
    
    # Check size limits
    if [ $MAIN_SIZE -gt 262144000 ]; then  # 250MB limit
        log_warning "Main package size exceeds Lambda limit (250MB)"
    fi
    
    if [ $ASYNC_SIZE -gt 262144000 ]; then  # 250MB limit
        log_warning "Async package size exceeds Lambda limit (250MB)"
    fi
}

# Upload packages to S3
upload_packages() {
    log_info "Uploading packages to S3..."
    
    # Check if deployment bucket exists
    DEPLOYMENT_BUCKET="${PROJECT_NAME}-${ENVIRONMENT}-deployments-$(aws sts get-caller-identity --query Account --output text)"
    
    # Create bucket if it doesn't exist
    if ! aws s3 ls "s3://${DEPLOYMENT_BUCKET}" &> /dev/null; then
        log_info "Creating deployment bucket: $DEPLOYMENT_BUCKET"
        aws s3 mb "s3://${DEPLOYMENT_BUCKET}" --region "$REGION"
        
        # Enable versioning
        aws s3api put-bucket-versioning \
            --bucket "$DEPLOYMENT_BUCKET" \
            --versioning-configuration Status=Enabled
    fi
    
    # Upload packages with versioning
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    
    aws s3 cp "${SCRIPT_DIR}/dist/text-generation-main.zip" \
        "s3://${DEPLOYMENT_BUCKET}/lambda/${TIMESTAMP}/text-generation-main.zip" \
        --region "$REGION"
    
    aws s3 cp "${SCRIPT_DIR}/dist/text-generation-async.zip" \
        "s3://${DEPLOYMENT_BUCKET}/lambda/${TIMESTAMP}/text-generation-async.zip" \
        --region "$REGION"
    
    # Store S3 paths for CloudFormation
    export MAIN_LAMBDA_S3_KEY="lambda/${TIMESTAMP}/text-generation-main.zip"
    export ASYNC_LAMBDA_S3_KEY="lambda/${TIMESTAMP}/text-generation-async.zip"
    export DEPLOYMENT_BUCKET_NAME="$DEPLOYMENT_BUCKET"
    
    log_success "Packages uploaded to S3"
}

# Update CloudFormation stack
update_stack() {
    log_info "Updating CloudFormation stack: $STACK_NAME"
    
    # Check if stack exists
    if aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" &> /dev/null; then
        OPERATION="update-stack"
        log_info "Stack exists, updating..."
    else
        OPERATION="create-stack"
        log_info "Stack doesn't exist, creating..."
    fi
    
    # Prepare parameters
    PARAMETERS="EnvironmentName=$ENVIRONMENT"
    PARAMETERS="$PARAMETERS,DeploymentBucket=$DEPLOYMENT_BUCKET_NAME"
    PARAMETERS="$PARAMETERS,MainLambdaS3Key=$MAIN_LAMBDA_S3_KEY"
    PARAMETERS="$PARAMETERS,AsyncLambdaS3Key=$ASYNC_LAMBDA_S3_KEY"
    
    # CloudFormation template path
    TEMPLATE_PATH="${SCRIPT_DIR}/../../cloudformation/text-generation.yaml"
    
    if [ ! -f "$TEMPLATE_PATH" ]; then
        log_error "CloudFormation template not found: $TEMPLATE_PATH"
        exit 1
    fi
    
    # Execute CloudFormation operation
    aws cloudformation "$OPERATION" \
        --stack-name "$STACK_NAME" \
        --template-body "file://$TEMPLATE_PATH" \
        --parameters "$PARAMETERS" \
        --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
        --region "$REGION" \
        --tags "Key=Environment,Value=$ENVIRONMENT" "Key=Project,Value=$PROJECT_NAME"
    
    # Wait for operation to complete
    log_info "Waiting for CloudFormation operation to complete..."
    
    if [ "$OPERATION" = "create-stack" ]; then
        aws cloudformation wait stack-create-complete --stack-name "$STACK_NAME" --region "$REGION"
    else
        aws cloudformation wait stack-update-complete --stack-name "$STACK_NAME" --region "$REGION"
    fi
    
    log_success "CloudFormation stack operation completed"
}

# Get stack outputs
get_stack_outputs() {
    log_info "Getting stack outputs..."
    
    aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$REGION" \
        --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
        --output table
    
    log_success "Stack outputs retrieved"
}

# Run tests
run_tests() {
    log_info "Running tests..."
    
    # Basic validation tests
    if [ -f "${SCRIPT_DIR}/test_deployment.py" ]; then
        $PYTHON_CMD "${SCRIPT_DIR}/test_deployment.py"
        log_success "Tests passed"
    else
        log_warning "No tests found, skipping"
    fi
}

# Cleanup build artifacts
cleanup() {
    log_info "Cleaning up build artifacts..."
    
    rm -rf "${SCRIPT_DIR}/build"
    
    log_success "Cleanup completed"
}

# Main deployment function
deploy() {
    log_info "Starting deployment to $ENVIRONMENT environment in $REGION region"
    
    check_prerequisites
    validate_environment
    clean_build
    create_build_dirs
    install_dependencies
    copy_source_files
    optimize_build
    create_packages
    upload_packages
    update_stack
    get_stack_outputs
    run_tests
    cleanup
    
    log_success "Deployment completed successfully!"
    log_info "Stack name: $STACK_NAME"
    log_info "Region: $REGION"
    log_info "Environment: $ENVIRONMENT"
}

# Handle script interruption
trap 'log_error "Deployment interrupted"; cleanup; exit 1' INT TERM

# Show usage
show_usage() {
    echo "Usage: $0 [environment] [region]"
    echo ""
    echo "Parameters:"
    echo "  environment  Target environment (dev, staging, prod) [default: dev]"
    echo "  region       AWS region [default: us-east-1]"
    echo ""
    echo "Examples:"
    echo "  $0                    # Deploy to dev in us-east-1"
    echo "  $0 prod               # Deploy to prod in us-east-1"
    echo "  $0 staging eu-west-1  # Deploy to staging in eu-west-1"
    echo ""
    echo "Environment variables:"
    echo "  AWS_PROFILE          AWS profile to use"
    echo "  AWS_ACCESS_KEY_ID    AWS access key"
    echo "  AWS_SECRET_ACCESS_KEY AWS secret key"
}

# Parse command line arguments
case "${1:-}" in
    -h|--help)
        show_usage
        exit 0
        ;;
    "")
        # Use defaults
        ;;
    *)
        if [[ "$1" =~ ^- ]]; then
            log_error "Invalid option: $1"
            show_usage
            exit 1
        fi
        ;;
esac

# Run deployment
deploy