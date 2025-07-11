#!/bin/bash

# =============================================================================
# AWS CloudFormation デプロイメントスクリプト
# 環境別（dev/staging/prod）のインフラストラクチャを自動デプロイ
# =============================================================================

set -euo pipefail

# 色設定
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ログ関数
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

# 使用法表示
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

OPTIONS:
    -e, --environment   Environment (dev/staging/prod)
    -p, --project       Project name (default: aws-practice)
    -r, --region        AWS region (default: ap-northeast-1)
    -t, --template      Template file path
    -s, --stack         Stack name
    -v, --validate      Validate template only
    -d, --dry-run       Dry run mode
    -h, --help          Show this help message

EXAMPLES:
    # Dev環境にデプロイ
    $0 -e dev -t cloudformation/main-stack.yaml -s my-stack

    # Staging環境にドライランでデプロイ
    $0 -e staging -t cloudformation/main-stack.yaml -s my-stack -d

    # テンプレートの検証のみ
    $0 -t cloudformation/main-stack.yaml -v

EOF
}

# パラメータの初期化
ENVIRONMENT=""
PROJECT_NAME="aws-practice"
AWS_REGION="ap-northeast-1"
TEMPLATE_FILE=""
STACK_NAME=""
VALIDATE_ONLY=false
DRY_RUN=false
PARAMETERS_FILE=""

# パラメータ解析
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -p|--project)
            PROJECT_NAME="$2"
            shift 2
            ;;
        -r|--region)
            AWS_REGION="$2"
            shift 2
            ;;
        -t|--template)
            TEMPLATE_FILE="$2"
            shift 2
            ;;
        -s|--stack)
            STACK_NAME="$2"
            shift 2
            ;;
        -v|--validate)
            VALIDATE_ONLY=true
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
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

# 必須パラメータチェック
if [[ -z "$TEMPLATE_FILE" ]]; then
    log_error "Template file is required"
    usage
    exit 1
fi

if [[ ! -f "$TEMPLATE_FILE" ]]; then
    log_error "Template file not found: $TEMPLATE_FILE"
    exit 1
fi

# 環境チェック
if [[ -n "$ENVIRONMENT" ]]; then
    if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
        log_error "Invalid environment: $ENVIRONMENT. Must be dev, staging, or prod"
        exit 1
    fi
fi

# スタック名の設定
if [[ -z "$STACK_NAME" && -n "$ENVIRONMENT" ]]; then
    STACK_NAME="${PROJECT_NAME}-${ENVIRONMENT}"
fi

# AWS CLI の確認
if ! command -v aws &> /dev/null; then
    log_error "AWS CLI is not installed"
    exit 1
fi

# AWS認証情報の確認
if ! aws sts get-caller-identity &> /dev/null; then
    log_error "AWS credentials not configured"
    exit 1
fi

# テンプレートの検証
validate_template() {
    log_info "Validating CloudFormation template..."
    
    if aws cloudformation validate-template \
        --template-body file://"$TEMPLATE_FILE" \
        --region "$AWS_REGION" &> /dev/null; then
        log_success "Template validation passed"
    else
        log_error "Template validation failed"
        exit 1
    fi
}

# パラメータファイルの確認
check_parameters() {
    local param_file="parameters/${ENVIRONMENT}.json"
    
    if [[ -f "$param_file" ]]; then
        PARAMETERS_FILE="$param_file"
        log_info "Using parameters file: $param_file"
    else
        log_warning "No parameters file found: $param_file"
    fi
}

# スタックの存在確認
stack_exists() {
    aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$AWS_REGION" &> /dev/null
}

# スタックの作成
create_stack() {
    log_info "Creating stack: $STACK_NAME"
    
    local cmd="aws cloudformation create-stack"
    cmd+=" --stack-name $STACK_NAME"
    cmd+=" --template-body file://$TEMPLATE_FILE"
    cmd+=" --region $AWS_REGION"
    cmd+=" --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM"
    
    if [[ -n "$PARAMETERS_FILE" ]]; then
        cmd+=" --parameters file://$PARAMETERS_FILE"
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "DRY RUN: Would execute: $cmd"
        return 0
    fi
    
    if eval "$cmd"; then
        log_success "Stack creation initiated"
        wait_for_stack_complete "CREATE_COMPLETE"
    else
        log_error "Stack creation failed"
        exit 1
    fi
}

# スタックの更新
update_stack() {
    log_info "Updating stack: $STACK_NAME"
    
    local cmd="aws cloudformation update-stack"
    cmd+=" --stack-name $STACK_NAME"
    cmd+=" --template-body file://$TEMPLATE_FILE"
    cmd+=" --region $AWS_REGION"
    cmd+=" --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM"
    
    if [[ -n "$PARAMETERS_FILE" ]]; then
        cmd+=" --parameters file://$PARAMETERS_FILE"
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "DRY RUN: Would execute: $cmd"
        return 0
    fi
    
    if eval "$cmd" 2>/dev/null; then
        log_success "Stack update initiated"
        wait_for_stack_complete "UPDATE_COMPLETE"
    else
        local error_message=$(aws cloudformation update-stack \
            --stack-name "$STACK_NAME" \
            --template-body file://"$TEMPLATE_FILE" \
            --region "$AWS_REGION" \
            --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
            2>&1 || true)
        
        if [[ "$error_message" == *"No updates are to be performed"* ]]; then
            log_info "No updates required for stack: $STACK_NAME"
        else
            log_error "Stack update failed: $error_message"
            exit 1
        fi
    fi
}

# スタック完了待機
wait_for_stack_complete() {
    local expected_status="$1"
    
    log_info "Waiting for stack operation to complete..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "DRY RUN: Would wait for stack status: $expected_status"
        return 0
    fi
    
    while true; do
        local status=$(aws cloudformation describe-stacks \
            --stack-name "$STACK_NAME" \
            --region "$AWS_REGION" \
            --query 'Stacks[0].StackStatus' \
            --output text 2>/dev/null || echo "UNKNOWN")
        
        case "$status" in
            *COMPLETE)
                if [[ "$status" == "$expected_status" ]]; then
                    log_success "Stack operation completed successfully: $status"
                    return 0
                else
                    log_error "Stack operation failed: $status"
                    exit 1
                fi
                ;;
            *FAILED|*ROLLBACK*)
                log_error "Stack operation failed: $status"
                show_stack_events
                exit 1
                ;;
            *IN_PROGRESS)
                log_info "Stack status: $status"
                sleep 30
                ;;
            *)
                log_error "Unknown stack status: $status"
                exit 1
                ;;
        esac
    done
}

# スタックイベントの表示
show_stack_events() {
    log_info "Recent stack events:"
    aws cloudformation describe-stack-events \
        --stack-name "$STACK_NAME" \
        --region "$AWS_REGION" \
        --query 'StackEvents[?ResourceStatus!=`null`].[Timestamp,ResourceStatus,ResourceType,LogicalResourceId,ResourceStatusReason]' \
        --output table \
        --max-items 10
}

# スタック出力の表示
show_stack_outputs() {
    log_info "Stack outputs:"
    aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$AWS_REGION" \
        --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue,Description]' \
        --output table 2>/dev/null || log_warning "No outputs found"
}

# メイン処理
main() {
    log_info "Starting deployment process..."
    log_info "Environment: ${ENVIRONMENT:-'not specified'}"
    log_info "Project: $PROJECT_NAME"
    log_info "Region: $AWS_REGION"
    log_info "Template: $TEMPLATE_FILE"
    log_info "Stack: ${STACK_NAME:-'not specified'}"
    
    # テンプレート検証
    validate_template
    
    # 検証のみの場合は終了
    if [[ "$VALIDATE_ONLY" == true ]]; then
        log_success "Template validation completed"
        exit 0
    fi
    
    # スタック名が必要
    if [[ -z "$STACK_NAME" ]]; then
        log_error "Stack name is required for deployment"
        exit 1
    fi
    
    # パラメータファイルの確認
    if [[ -n "$ENVIRONMENT" ]]; then
        check_parameters
    fi
    
    # スタックの作成または更新
    if stack_exists; then
        update_stack
    else
        create_stack
    fi
    
    # 出力の表示
    show_stack_outputs
    
    log_success "Deployment completed successfully!"
}

# スクリプト実行
main "$@"