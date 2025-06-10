#!/bin/bash

###########################################
# CRUD システム デプロイスクリプト
# AWS Cognito + API Gateway + Lambda + DynamoDB
###########################################

set -e  # エラー発生時にスクリプトを終了

# カラー定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 設定変数
PROJECT_NAME="crud-system"
DEFAULT_ENVIRONMENT="dev"
DEFAULT_REGION="ap-northeast-1"
DEFAULT_EMAIL="noreply@example.com"

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

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

# ヘルプ表示
show_help() {
    cat << EOF
CRUD システム デプロイスクリプト

使用法:
    ./deploy-crud-system.sh [OPTIONS] COMMAND

コマンド:
    deploy          全システムをデプロイ
    deploy-auth     認証システムのみデプロイ
    deploy-crud     CRUD APIのみデプロイ
    status          デプロイ状況確認
    test            APIテスト実行
    cleanup         全リソース削除
    help            このヘルプを表示

オプション:
    -e, --environment ENV   環境名 (default: dev)
    -r, --region REGION     AWSリージョン (default: ap-northeast-1)
    -p, --project PROJECT   プロジェクト名 (default: crud-system)
    -m, --email EMAIL       SES検証済みメール (default: noreply@example.com)
    -v, --verbose           詳細ログ出力
    -h, --help              ヘルプ表示

例:
    ./deploy-crud-system.sh deploy
    ./deploy-crud-system.sh -e prod -r us-west-2 deploy
    ./deploy-crud-system.sh test
    ./deploy-crud-system.sh cleanup

EOF
}

# 引数解析
ENVIRONMENT="$DEFAULT_ENVIRONMENT"
REGION="$DEFAULT_REGION"
EMAIL="$DEFAULT_EMAIL"
VERBOSE=false
COMMAND=""

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
        -p|--project)
            PROJECT_NAME="$2"
            shift 2
            ;;
        -m|--email)
            EMAIL="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        deploy|deploy-auth|deploy-crud|status|test|cleanup|help)
            COMMAND="$1"
            shift
            ;;
        *)
            log_error "不明なオプション: $1"
            show_help
            exit 1
            ;;
    esac
done

# コマンドが指定されていない場合はヘルプを表示
if [ -z "$COMMAND" ]; then
    show_help
    exit 1
fi

# 詳細ログ設定
if [ "$VERBOSE" = true ]; then
    set -x
fi

# スタック名の設定
AUTH_STACK_NAME="${PROJECT_NAME}-${ENVIRONMENT}-auth"
CRUD_STACK_NAME="${PROJECT_NAME}-${ENVIRONMENT}-crud-api"

# 前提条件チェック
check_prerequisites() {
    log_step "前提条件をチェック中..."
    
    # AWS CLI の確認
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI がインストールされていません"
        exit 1
    fi
    
    # jq の確認
    if ! command -v jq &> /dev/null; then
        log_error "jq がインストールされていません"
        exit 1
    fi
    
    # AWS認証情報の確認
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS認証情報が設定されていません"
        exit 1
    fi
    
    # リージョンの設定
    export AWS_DEFAULT_REGION="$REGION"
    
    log_success "前提条件チェック完了"
}

# CloudFormationテンプレートの存在確認
check_templates() {
    log_step "CloudFormationテンプレートをチェック中..."
    
    AUTH_TEMPLATE="03-CRUDシステム実装編/3.1-基本CRUD/3.1.1-ユーザー管理システム/cloudformation/cognito-user-pool.yaml"
    CRUD_TEMPLATE="03-CRUDシステム実装編/3.1-基本CRUD/3.1.2-データ操作API/cloudformation/crud-api.yaml"
    
    if [ ! -f "$AUTH_TEMPLATE" ]; then
        log_error "認証システムテンプレートが見つかりません: $AUTH_TEMPLATE"
        exit 1
    fi
    
    if [ ! -f "$CRUD_TEMPLATE" ]; then
        log_error "CRUD APIテンプレートが見つかりません: $CRUD_TEMPLATE"
        exit 1
    fi
    
    log_success "テンプレートチェック完了"
}

# スタックの状態確認
check_stack_status() {
    local stack_name="$1"
    aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --query 'Stacks[0].StackStatus' \
        --output text 2>/dev/null || echo "NOT_EXISTS"
}

# スタックが完了状態になるまで待機
wait_for_stack() {
    local stack_name="$1"
    local operation="$2"  # create or update
    
    log_info "スタック $stack_name の$operation完了を待機中..."
    
    if [ "$operation" = "create" ]; then
        aws cloudformation wait stack-create-complete --stack-name "$stack_name"
    else
        aws cloudformation wait stack-update-complete --stack-name "$stack_name"
    fi
    
    local status=$(check_stack_status "$stack_name")
    if [[ "$status" == *"COMPLETE" ]]; then
        log_success "スタック $stack_name の$operation完了"
    else
        log_error "スタック $stack_name の$operationに失敗: $status"
        exit 1
    fi
}

# 認証システムのデプロイ
deploy_auth() {
    log_step "認証システムをデプロイ中..."
    
    local auth_template="03-CRUDシステム実装編/3.1-基本CRUD/3.1.1-ユーザー管理システム/cloudformation/cognito-user-pool.yaml"
    local status=$(check_stack_status "$AUTH_STACK_NAME")
    
    local parameters=(
        "ParameterKey=EnvironmentName,ParameterValue=$ENVIRONMENT"
        "ParameterKey=ProjectName,ParameterValue=$PROJECT_NAME"
        "ParameterKey=SESVerifiedEmail,ParameterValue=$EMAIL"
        "ParameterKey=EnableMFA,ParameterValue=OPTIONAL"
    )
    
    if [ "$status" = "NOT_EXISTS" ]; then
        log_info "認証スタックを作成中..."
        aws cloudformation create-stack \
            --stack-name "$AUTH_STACK_NAME" \
            --template-body "file://$auth_template" \
            --parameters "${parameters[@]}" \
            --capabilities CAPABILITY_NAMED_IAM \
            --tags "Key=Environment,Value=$ENVIRONMENT" "Key=Project,Value=$PROJECT_NAME"
        
        wait_for_stack "$AUTH_STACK_NAME" "create"
    else
        log_info "認証スタックを更新中..."
        aws cloudformation update-stack \
            --stack-name "$AUTH_STACK_NAME" \
            --template-body "file://$auth_template" \
            --parameters "${parameters[@]}" \
            --capabilities CAPABILITY_NAMED_IAM \
            --tags "Key=Environment,Value=$ENVIRONMENT" "Key=Project,Value=$PROJECT_NAME" 2>/dev/null || {
                local exit_code=$?
                if [ $exit_code -eq 255 ]; then
                    log_info "スタックに変更がありません"
                else
                    log_error "スタック更新に失敗"
                    exit 1
                fi
            }
        
        if [ $exit_code -ne 255 ]; then
            wait_for_stack "$AUTH_STACK_NAME" "update"
        fi
    fi
    
    log_success "認証システムのデプロイ完了"
}

# CRUD APIのデプロイ
deploy_crud() {
    log_step "CRUD APIをデプロイ中..."
    
    # 認証システムからパラメータを取得
    local user_pool_id=$(aws cloudformation describe-stacks \
        --stack-name "$AUTH_STACK_NAME" \
        --query 'Stacks[0].Outputs[?OutputKey==`UserPoolId`].OutputValue' \
        --output text)
    
    local user_pool_arn=$(aws cloudformation describe-stacks \
        --stack-name "$AUTH_STACK_NAME" \
        --query 'Stacks[0].Outputs[?OutputKey==`UserPoolArn`].OutputValue' \
        --output text)
    
    if [ -z "$user_pool_id" ] || [ -z "$user_pool_arn" ]; then
        log_error "認証システムから必要なパラメータを取得できません"
        exit 1
    fi
    
    local crud_template="03-CRUDシステム実装編/3.1-基本CRUD/3.1.2-データ操作API/cloudformation/crud-api.yaml"
    local status=$(check_stack_status "$CRUD_STACK_NAME")
    
    local parameters=(
        "ParameterKey=EnvironmentName,ParameterValue=$ENVIRONMENT"
        "ParameterKey=ProjectName,ParameterValue=$PROJECT_NAME"
        "ParameterKey=UserPoolId,ParameterValue=$user_pool_id"
        "ParameterKey=UserPoolArn,ParameterValue=$user_pool_arn"
    )
    
    if [ "$status" = "NOT_EXISTS" ]; then
        log_info "CRUD APIスタックを作成中..."
        aws cloudformation create-stack \
            --stack-name "$CRUD_STACK_NAME" \
            --template-body "file://$crud_template" \
            --parameters "${parameters[@]}" \
            --capabilities CAPABILITY_NAMED_IAM \
            --tags "Key=Environment,Value=$ENVIRONMENT" "Key=Project,Value=$PROJECT_NAME"
        
        wait_for_stack "$CRUD_STACK_NAME" "create"
    else
        log_info "CRUD APIスタックを更新中..."
        aws cloudformation update-stack \
            --stack-name "$CRUD_STACK_NAME" \
            --template-body "file://$crud_template" \
            --parameters "${parameters[@]}" \
            --capabilities CAPABILITY_NAMED_IAM \
            --tags "Key=Environment,Value=$ENVIRONMENT" "Key=Project,Value=$PROJECT_NAME" 2>/dev/null || {
                local exit_code=$?
                if [ $exit_code -eq 255 ]; then
                    log_info "スタックに変更がありません"
                else
                    log_error "スタック更新に失敗"
                    exit 1
                fi
            }
        
        if [ $exit_code -ne 255 ]; then
            wait_for_stack "$CRUD_STACK_NAME" "update"
        fi
    fi
    
    log_success "CRUD APIのデプロイ完了"
}

# デプロイ状況確認
show_status() {
    log_step "デプロイ状況を確認中..."
    
    echo -e "\n${CYAN}=== スタック状況 ===${NC}"
    
    # 認証スタックの状況
    local auth_status=$(check_stack_status "$AUTH_STACK_NAME")
    echo -e "認証システム ($AUTH_STACK_NAME): ${auth_status}"
    
    # CRUD APIスタックの状況
    local crud_status=$(check_stack_status "$CRUD_STACK_NAME")
    echo -e "CRUD API ($CRUD_STACK_NAME): ${crud_status}"
    
    # エンドポイント情報の表示
    if [[ "$auth_status" == *"COMPLETE" ]]; then
        echo -e "\n${CYAN}=== 認証システム情報 ===${NC}"
        
        local auth_endpoint=$(aws cloudformation describe-stacks \
            --stack-name "$AUTH_STACK_NAME" \
            --query 'Stacks[0].Outputs[?OutputKey==`SignInUrl`].OutputValue' \
            --output text 2>/dev/null || echo "N/A")
        echo -e "ログインURL: ${auth_endpoint}"
        
        local user_pool_id=$(aws cloudformation describe-stacks \
            --stack-name "$AUTH_STACK_NAME" \
            --query 'Stacks[0].Outputs[?OutputKey==`UserPoolId`].OutputValue' \
            --output text 2>/dev/null || echo "N/A")
        echo -e "User Pool ID: ${user_pool_id}"
    fi
    
    if [[ "$crud_status" == *"COMPLETE" ]]; then
        echo -e "\n${CYAN}=== CRUD API情報 ===${NC}"
        
        local crud_endpoint=$(aws cloudformation describe-stacks \
            --stack-name "$CRUD_STACK_NAME" \
            --query 'Stacks[0].Outputs[?OutputKey==`CrudApiEndpoint`].OutputValue' \
            --output text 2>/dev/null || echo "N/A")
        echo -e "CRUD API URL: ${crud_endpoint}"
        
        local items_table=$(aws cloudformation describe-stacks \
            --stack-name "$CRUD_STACK_NAME" \
            --query 'Stacks[0].Outputs[?OutputKey==`ItemsTableName`].OutputValue' \
            --output text 2>/dev/null || echo "N/A")
        echo -e "DynamoDBテーブル: ${items_table}"
    fi
    
    echo ""
}

# APIテスト実行
run_tests() {
    log_step "APIテストを実行中..."
    
    # エンドポイントの取得
    local auth_endpoint=$(aws cloudformation describe-stacks \
        --stack-name "$AUTH_STACK_NAME" \
        --query 'Stacks[0].Outputs[?OutputKey==`ApiEndpoint`].OutputValue' \
        --output text 2>/dev/null)
    
    local crud_endpoint=$(aws cloudformation describe-stacks \
        --stack-name "$CRUD_STACK_NAME" \
        --query 'Stacks[0].Outputs[?OutputKey==`CrudApiEndpoint`].OutputValue' \
        --output text 2>/dev/null)
    
    if [ -z "$auth_endpoint" ] || [ -z "$crud_endpoint" ]; then
        log_error "エンドポイントを取得できません。システムがデプロイされているか確認してください。"
        exit 1
    fi
    
    echo -e "\n${CYAN}=== APIテスト ===${NC}"
    echo -e "認証エンドポイント: ${auth_endpoint}"
    echo -e "CRUD エンドポイント: ${crud_endpoint}"
    
    # ヘルスチェック（認証不要のエンドポイントで確認）
    log_info "認証APIのヘルスチェック..."
    local auth_health_response=$(curl -s -o /dev/null -w "%{http_code}" "${auth_endpoint}/auth/signup" -X OPTIONS)
    if [ "$auth_health_response" = "200" ]; then
        log_success "認証API: OK"
    else
        log_warning "認証API: 応答コード $auth_health_response"
    fi
    
    log_info "CRUD APIのヘルスチェック..."
    local crud_health_response=$(curl -s -o /dev/null -w "%{http_code}" "${crud_endpoint}/items" -X OPTIONS)
    if [ "$crud_health_response" = "200" ]; then
        log_success "CRUD API: OK"
    else
        log_warning "CRUD API: 応答コード $crud_health_response"
    fi
    
    echo -e "\n${YELLOW}手動テスト用コマンド:${NC}"
    echo -e "1. ユーザー登録:"
    echo -e "   curl -X POST ${auth_endpoint}/auth/signup -H 'Content-Type: application/json' -d '{\"email\":\"test@example.com\",\"password\":\"Test123!@#\$\",\"name\":\"Test User\"}'"
    
    echo -e "\n2. ログイン:"
    echo -e "   curl -X POST ${auth_endpoint}/auth/signin -H 'Content-Type: application/json' -d '{\"email\":\"test@example.com\",\"password\":\"Test123!@#\$\"}'"
    
    echo -e "\n3. アイテム作成 (認証トークンが必要):"
    echo -e "   curl -X POST ${crud_endpoint}/items -H 'Authorization: Bearer \$TOKEN' -H 'Content-Type: application/json' -d '{\"title\":\"Test Item\",\"itemType\":\"task\"}'"
}

# リソース削除
cleanup() {
    log_step "リソースを削除中..."
    
    echo -e "${RED}警告: 全てのリソースが削除されます。データは復旧できません。${NC}"
    read -p "本当に削除しますか? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        log_info "削除をキャンセルしました"
        exit 0
    fi
    
    # CRUD APIスタックの削除
    local crud_status=$(check_stack_status "$CRUD_STACK_NAME")
    if [ "$crud_status" != "NOT_EXISTS" ]; then
        log_info "CRUD APIスタックを削除中..."
        aws cloudformation delete-stack --stack-name "$CRUD_STACK_NAME"
        aws cloudformation wait stack-delete-complete --stack-name "$CRUD_STACK_NAME"
        log_success "CRUD APIスタックの削除完了"
    fi
    
    # 認証スタックの削除
    local auth_status=$(check_stack_status "$AUTH_STACK_NAME")
    if [ "$auth_status" != "NOT_EXISTS" ]; then
        log_info "認証スタックを削除中..."
        aws cloudformation delete-stack --stack-name "$AUTH_STACK_NAME"
        aws cloudformation wait stack-delete-complete --stack-name "$AUTH_STACK_NAME"
        log_success "認証スタックの削除完了"
    fi
    
    log_success "全てのリソースの削除完了"
}

# メイン処理
main() {
    echo -e "${PURPLE}"
    echo "========================================"
    echo "  CRUD システム デプロイスクリプト"
    echo "========================================"
    echo -e "${NC}"
    echo -e "プロジェクト: ${PROJECT_NAME}"
    echo -e "環境: ${ENVIRONMENT}"
    echo -e "リージョン: ${REGION}"
    echo -e "コマンド: ${COMMAND}"
    echo ""
    
    check_prerequisites
    
    case "$COMMAND" in
        deploy)
            check_templates
            deploy_auth
            deploy_crud
            show_status
            run_tests
            ;;
        deploy-auth)
            check_templates
            deploy_auth
            show_status
            ;;
        deploy-crud)
            check_templates
            deploy_crud
            show_status
            ;;
        status)
            show_status
            ;;
        test)
            run_tests
            ;;
        cleanup)
            cleanup
            ;;
        help)
            show_help
            ;;
        *)
            log_error "不明なコマンド: $COMMAND"
            show_help
            exit 1
            ;;
    esac
}

# スクリプト実行
main "$@"