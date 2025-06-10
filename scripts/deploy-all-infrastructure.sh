#!/bin/bash

###########################################
# 全学習コンテンツ統合デプロイスクリプト
# AWS AI駆動開発学習プロジェクト
###########################################

set -e

# カラー定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# 設定変数
PROJECT_NAME="ai-driven-dev"
DEFAULT_ENVIRONMENT="dev"
DEFAULT_REGION="ap-northeast-1"
ORGANIZATION_NAME="MyOrg"

# ログ関数
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${PURPLE}[STEP]${NC} $1"; }

# ヘルプ表示
show_help() {
    cat << EOF
AWS AI駆動開発学習プロジェクト 統合デプロイスクリプト

使用法:
    ./deploy-all-infrastructure.sh [OPTIONS] COMMAND

コマンド:
    deploy-foundation    基礎インフラ（IAM、VPC、セキュリティ）
    deploy-web           Web三層アーキテクチャ
    deploy-crud          CRUDシステム
    deploy-data          データ分析基盤
    deploy-ai-ml         AI/ML統合システム
    deploy-cicd          CI/CD高度化
    deploy-claude        Claude Code & Bedrock
    deploy-all           全システムを順次デプロイ
    status               全システムの状況確認
    test                 統合テスト実行
    cleanup              全リソース削除
    help                 このヘルプを表示

オプション:
    -e, --environment ENV   環境名 (default: dev)
    -r, --region REGION     AWSリージョン (default: ap-northeast-1)
    -o, --org NAME          組織名 (default: MyOrg)
    -v, --verbose           詳細ログ出力
    -h, --help              ヘルプ表示

例:
    ./deploy-all-infrastructure.sh deploy-foundation
    ./deploy-all-infrastructure.sh -e prod deploy-all
    ./deploy-all-infrastructure.sh status
    ./deploy-all-infrastructure.sh cleanup

EOF
}

# 引数解析
ENVIRONMENT="$DEFAULT_ENVIRONMENT"
REGION="$DEFAULT_REGION"
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
        -o|--org)
            ORGANIZATION_NAME="$2"
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
        deploy-foundation|deploy-web|deploy-crud|deploy-data|deploy-ai-ml|deploy-cicd|deploy-claude|deploy-all|status|test|cleanup|help)
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

if [ -z "$COMMAND" ]; then
    show_help
    exit 1
fi

if [ "$VERBOSE" = true ]; then
    set -x
fi

export AWS_DEFAULT_REGION="$REGION"

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
    
    log_success "前提条件チェック完了"
}

# スタックの状態確認
check_stack_status() {
    local stack_name="$1"
    aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --query 'Stacks[0].StackStatus' \
        --output text 2>/dev/null || echo "NOT_EXISTS"
}

# スタック完了まで待機
wait_for_stack() {
    local stack_name="$1"
    local operation="$2"
    
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

# 基礎インフラストラクチャーのデプロイ
deploy_foundation() {
    log_step "基礎インフラストラクチャーをデプロイ中..."
    
    # IAM基盤
    local iam_stack="${PROJECT_NAME}-${ENVIRONMENT}-iam-foundation"
    local iam_template="01-基礎インフラストラクチャー編/1.1-AWS環境セットアップ/1.1.1-アカウント設定とIAM/cloudformation/master-stack.yaml"
    
    if [ -f "$iam_template" ]; then
        local status=$(check_stack_status "$iam_stack")
        if [ "$status" = "NOT_EXISTS" ]; then
            log_info "IAM基盤スタックを作成中..."
            aws cloudformation create-stack \
                --stack-name "$iam_stack" \
                --template-body "file://$iam_template" \
                --parameters \
                    "ParameterKey=EnvironmentName,ParameterValue=$ENVIRONMENT" \
                    "ParameterKey=OrganizationName,ParameterValue=$ORGANIZATION_NAME" \
                --capabilities CAPABILITY_NAMED_IAM \
                --tags "Key=Environment,Value=$ENVIRONMENT" "Key=Project,Value=$PROJECT_NAME"
            
            wait_for_stack "$iam_stack" "create"
        else
            log_info "IAM基盤スタックは既に存在します: $status"
        fi
    else
        log_warning "IAMテンプレートが見つかりません: $iam_template"
    fi
    
    # VPCネットワーク
    local vpc_stack="${PROJECT_NAME}-${ENVIRONMENT}-vpc-network"
    local vpc_template="01-基礎インフラストラクチャー編/1.1-AWS環境セットアップ/1.1.2-VPCとネットワーク基礎/cloudformation/vpc-network.yaml"
    
    if [ -f "$vpc_template" ]; then
        local status=$(check_stack_status "$vpc_stack")
        if [ "$status" = "NOT_EXISTS" ]; then
            log_info "VPCネットワークスタックを作成中..."
            aws cloudformation create-stack \
                --stack-name "$vpc_stack" \
                --template-body "file://$vpc_template" \
                --parameters \
                    "ParameterKey=EnvironmentName,ParameterValue=$ENVIRONMENT" \
                    "ParameterKey=ProjectName,ParameterValue=$PROJECT_NAME" \
                --tags "Key=Environment,Value=$ENVIRONMENT" "Key=Project,Value=$PROJECT_NAME"
            
            wait_for_stack "$vpc_stack" "create"
        else
            log_info "VPCネットワークスタックは既に存在します: $status"
        fi
    else
        log_warning "VPCテンプレートが見つかりません: $vpc_template"
    fi
    
    log_success "基礎インフラストラクチャーのデプロイ完了"
}

# Web三層アーキテクチャのデプロイ
deploy_web() {
    log_step "Web三層アーキテクチャをデプロイ中..."
    
    # 静的サイトホスティング
    local static_stack="${PROJECT_NAME}-${ENVIRONMENT}-static-hosting"
    local static_template="02-Web三層アーキテクチャ編/2.1-プレゼンテーション層/2.1.1-静的サイトホスティング/cloudformation/static-hosting.yaml"
    
    if [ -f "$static_template" ]; then
        local status=$(check_stack_status "$static_stack")
        if [ "$status" = "NOT_EXISTS" ]; then
            aws cloudformation create-stack \
                --stack-name "$static_stack" \
                --template-body "file://$static_template" \
                --parameters \
                    "ParameterKey=EnvironmentName,ParameterValue=$ENVIRONMENT" \
                    "ParameterKey=ProjectName,ParameterValue=$PROJECT_NAME" \
                --tags "Key=Environment,Value=$ENVIRONMENT" "Key=Project,Value=$PROJECT_NAME"
            
            wait_for_stack "$static_stack" "create"
        fi
    fi
    
    log_success "Web三層アーキテクチャのデプロイ完了"
}

# CRUDシステムのデプロイ
deploy_crud() {
    log_step "CRUDシステムをデプロイ中..."
    
    # 認証システム
    local auth_stack="${PROJECT_NAME}-${ENVIRONMENT}-auth"
    local auth_template="03-CRUDシステム実装編/3.1-基本CRUD/3.1.1-ユーザー管理システム/cloudformation/master-stack.yaml"
    
    if [ -f "$auth_template" ]; then
        local status=$(check_stack_status "$auth_stack")
        if [ "$status" = "NOT_EXISTS" ]; then
            aws cloudformation create-stack \
                --stack-name "$auth_stack" \
                --template-body "file://$auth_template" \
                --parameters \
                    "ParameterKey=EnvironmentName,ParameterValue=$ENVIRONMENT" \
                    "ParameterKey=ProjectName,ParameterValue=$PROJECT_NAME" \
                --capabilities CAPABILITY_NAMED_IAM \
                --tags "Key=Environment,Value=$ENVIRONMENT" "Key=Project,Value=$PROJECT_NAME"
            
            wait_for_stack "$auth_stack" "create"
        fi
    fi
    
    log_success "CRUDシステムのデプロイ完了"
}

# データ分析基盤のデプロイ
deploy_data() {
    log_step "データ分析基盤をデプロイ中..."
    
    # Kinesisストリーミング
    local kinesis_stack="${PROJECT_NAME}-${ENVIRONMENT}-kinesis"
    local kinesis_template="04-データ分析基盤編/4.1-データ収集と保存/4.1.1-Kinesisストリーミング/cloudformation/kinesis-streaming.yaml"
    
    if [ -f "$kinesis_template" ]; then
        local status=$(check_stack_status "$kinesis_stack")
        if [ "$status" = "NOT_EXISTS" ]; then
            aws cloudformation create-stack \
                --stack-name "$kinesis_stack" \
                --template-body "file://$kinesis_template" \
                --parameters \
                    "ParameterKey=EnvironmentName,ParameterValue=$ENVIRONMENT" \
                    "ParameterKey=ProjectName,ParameterValue=$PROJECT_NAME" \
                --capabilities CAPABILITY_IAM \
                --tags "Key=Environment,Value=$ENVIRONMENT" "Key=Project,Value=$PROJECT_NAME"
            
            wait_for_stack "$kinesis_stack" "create"
        fi
    fi
    
    log_success "データ分析基盤のデプロイ完了"
}

# AI/ML統合システムのデプロイ
deploy_ai_ml() {
    log_step "AI/ML統合システムをデプロイ中..."
    
    # Bedrockセットアップ
    local bedrock_stack="${PROJECT_NAME}-${ENVIRONMENT}-bedrock"
    local bedrock_template="05-AI-ML統合編/5.1-Bedrock基礎/5.1.1-Bedrockセットアップ/cloudformation/bedrock-setup.yaml"
    
    if [ -f "$bedrock_template" ]; then
        local status=$(check_stack_status "$bedrock_stack")
        if [ "$status" = "NOT_EXISTS" ]; then
            aws cloudformation create-stack \
                --stack-name "$bedrock_stack" \
                --template-body "file://$bedrock_template" \
                --parameters \
                    "ParameterKey=EnvironmentName,ParameterValue=$ENVIRONMENT" \
                    "ParameterKey=ProjectName,ParameterValue=$PROJECT_NAME" \
                --capabilities CAPABILITY_IAM \
                --tags "Key=Environment,Value=$ENVIRONMENT" "Key=Project,Value=$PROJECT_NAME"
            
            wait_for_stack "$bedrock_stack" "create"
        fi
    fi
    
    log_success "AI/ML統合システムのデプロイ完了"
}

# CI/CD高度化のデプロイ
deploy_cicd() {
    log_step "CI/CD高度化をデプロイ中..."
    
    # マルチステージビルド
    local cicd_stack="${PROJECT_NAME}-${ENVIRONMENT}-cicd"
    local cicd_template="06-CI-CD高度化編/6.1-自動化パイプライン/6.1.1-マルチステージビルド/cloudformation/multi-stage-pipeline.yaml"
    
    if [ -f "$cicd_template" ]; then
        local status=$(check_stack_status "$cicd_stack")
        if [ "$status" = "NOT_EXISTS" ]; then
            aws cloudformation create-stack \
                --stack-name "$cicd_stack" \
                --template-body "file://$cicd_template" \
                --parameters \
                    "ParameterKey=EnvironmentName,ParameterValue=$ENVIRONMENT" \
                    "ParameterKey=ProjectName,ParameterValue=$PROJECT_NAME" \
                --capabilities CAPABILITY_IAM \
                --tags "Key=Environment,Value=$ENVIRONMENT" "Key=Project,Value=$PROJECT_NAME"
            
            wait_for_stack "$cicd_stack" "create"
        fi
    fi
    
    log_success "CI/CD高度化のデプロイ完了"
}

# Claude Code & Bedrockのデプロイ
deploy_claude() {
    log_step "Claude Code & Bedrockをデプロイ中..."
    
    # Claude Code IAM設定
    local claude_stack="${PROJECT_NAME}-${ENVIRONMENT}-claude-code"
    local claude_template="07-Claude-Code-Bedrock-AI駆動開発編/7.1-Claude-Code基礎/7.1.1-環境セットアップとBedrock連携/cloudformation/claude-code-iam.yaml"
    
    if [ -f "$claude_template" ]; then
        local status=$(check_stack_status "$claude_stack")
        if [ "$status" = "NOT_EXISTS" ]; then
            aws cloudformation create-stack \
                --stack-name "$claude_stack" \
                --template-body "file://$claude_template" \
                --parameters \
                    "ParameterKey=EnvironmentName,ParameterValue=$ENVIRONMENT" \
                    "ParameterKey=ProjectName,ParameterValue=$PROJECT_NAME" \
                --capabilities CAPABILITY_NAMED_IAM \
                --tags "Key=Environment,Value=$ENVIRONMENT" "Key=Project,Value=$PROJECT_NAME"
            
            wait_for_stack "$claude_stack" "create"
        fi
    fi
    
    log_success "Claude Code & Bedrockのデプロイ完了"
}

# 全システムデプロイ
deploy_all() {
    log_step "全システムを順次デプロイ中..."
    
    deploy_foundation
    sleep 30  # 依存関係を考慮した待機
    
    deploy_web
    sleep 30
    
    deploy_crud
    sleep 30
    
    deploy_data
    sleep 30
    
    deploy_ai_ml
    sleep 30
    
    deploy_cicd
    sleep 30
    
    deploy_claude
    
    log_success "全システムのデプロイ完了"
}

# 全システム状況確認
show_status() {
    log_step "全システム状況を確認中..."
    
    echo -e "\n${CYAN}=== デプロイ状況 ===${NC}"
    
    local stacks=(
        "${PROJECT_NAME}-${ENVIRONMENT}-iam-foundation:IAM基盤"
        "${PROJECT_NAME}-${ENVIRONMENT}-vpc-network:VPCネットワーク"
        "${PROJECT_NAME}-${ENVIRONMENT}-static-hosting:静的サイト"
        "${PROJECT_NAME}-${ENVIRONMENT}-auth:認証システム"
        "${PROJECT_NAME}-${ENVIRONMENT}-kinesis:データ基盤"
        "${PROJECT_NAME}-${ENVIRONMENT}-bedrock:AI/ML基盤"
        "${PROJECT_NAME}-${ENVIRONMENT}-cicd:CI/CD"
        "${PROJECT_NAME}-${ENVIRONMENT}-claude-code:Claude Code"
    )
    
    for stack_info in "${stacks[@]}"; do
        IFS=':' read -r stack_name description <<< "$stack_info"
        local status=$(check_stack_status "$stack_name")
        echo -e "${description}: ${status}"
    done
    
    echo ""
}

# 統合テスト実行
run_tests() {
    log_step "統合テストを実行中..."
    
    # 基本的なヘルスチェック
    echo -e "\n${CYAN}=== ヘルスチェック ===${NC}"
    
    # IAMチェック
    if aws iam get-account-summary &> /dev/null; then
        log_success "IAM: OK"
    else
        log_warning "IAM: エラー"
    fi
    
    # VPCチェック
    local vpc_count=$(aws ec2 describe-vpcs --query 'length(Vpcs)' --output text)
    echo -e "VPC数: ${vpc_count}"
    
    # S3チェック
    local bucket_count=$(aws s3 ls | wc -l)
    echo -e "S3バケット数: ${bucket_count}"
    
    log_success "統合テスト完了"
}

# 全リソース削除
cleanup() {
    log_step "全リソースを削除中..."
    
    echo -e "${RED}警告: 全てのリソースが削除されます。データは復旧できません。${NC}"
    read -p "本当に削除しますか? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        log_info "削除をキャンセルしました"
        exit 0
    fi
    
    local stacks=(
        "${PROJECT_NAME}-${ENVIRONMENT}-claude-code"
        "${PROJECT_NAME}-${ENVIRONMENT}-cicd"
        "${PROJECT_NAME}-${ENVIRONMENT}-bedrock"
        "${PROJECT_NAME}-${ENVIRONMENT}-kinesis"
        "${PROJECT_NAME}-${ENVIRONMENT}-auth"
        "${PROJECT_NAME}-${ENVIRONMENT}-static-hosting"
        "${PROJECT_NAME}-${ENVIRONMENT}-vpc-network"
        "${PROJECT_NAME}-${ENVIRONMENT}-iam-foundation"
    )
    
    for stack_name in "${stacks[@]}"; do
        local status=$(check_stack_status "$stack_name")
        if [ "$status" != "NOT_EXISTS" ]; then
            log_info "スタック $stack_name を削除中..."
            aws cloudformation delete-stack --stack-name "$stack_name"
            aws cloudformation wait stack-delete-complete --stack-name "$stack_name" &
        fi
    done
    
    wait
    log_success "全リソースの削除完了"
}

# メイン処理
main() {
    echo -e "${PURPLE}"
    echo "=========================================="
    echo "  AWS AI駆動開発学習プロジェクト"
    echo "  統合デプロイスクリプト"
    echo "=========================================="
    echo -e "${NC}"
    echo -e "プロジェクト: ${PROJECT_NAME}"
    echo -e "環境: ${ENVIRONMENT}"
    echo -e "リージョン: ${REGION}"
    echo -e "組織: ${ORGANIZATION_NAME}"
    echo -e "コマンド: ${COMMAND}"
    echo ""
    
    check_prerequisites
    
    case "$COMMAND" in
        deploy-foundation)
            deploy_foundation
            ;;
        deploy-web)
            deploy_web
            ;;
        deploy-crud)
            deploy_crud
            ;;
        deploy-data)
            deploy_data
            ;;
        deploy-ai-ml)
            deploy_ai_ml
            ;;
        deploy-cicd)
            deploy_cicd
            ;;
        deploy-claude)
            deploy_claude
            ;;
        deploy-all)
            deploy_all
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