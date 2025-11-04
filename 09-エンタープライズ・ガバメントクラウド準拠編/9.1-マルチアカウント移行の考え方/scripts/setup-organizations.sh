#!/bin/bash

###############################################################################
# AWS Organizations セットアップスクリプト
#
# このスクリプトは以下を実行します:
# 1. AWS Organizations の有効化
# 2. Organizational Units (OU) の作成
# 3. Service Control Policies (SCP) の作成と適用
###############################################################################

set -e

# 色付き出力用
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ログ関数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 前提条件チェック
check_prerequisites() {
    log_info "前提条件をチェック中..."

    # AWS CLI のインストール確認
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI がインストールされていません"
        exit 1
    fi

    # AWS認証確認
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS認証が設定されていません"
        exit 1
    fi

    log_info "前提条件OK"
}

# Organizations の有効化または確認
setup_organizations() {
    log_info "AWS Organizations をセットアップ中..."

    # すでに有効化されているか確認
    if aws organizations describe-organization &> /dev/null; then
        log_warn "AWS Organizations はすでに有効化されています"
    else
        log_info "AWS Organizations を有効化中..."
        aws organizations create-organization --feature-set ALL
        log_info "AWS Organizations を有効化しました"
    fi

    # 組織情報の表示
    aws organizations describe-organization
}

# Organizational Units (OU) の作成
create_organizational_units() {
    log_info "Organizational Units (OU) を作成中..."

    # ルートIDの取得
    ROOT_ID=$(aws organizations list-roots --query 'Roots[0].Id' --output text)
    log_info "Root ID: $ROOT_ID"

    # Security OU の作成
    if SECURITY_OU_ID=$(aws organizations list-organizational-units-for-parent \
        --parent-id $ROOT_ID \
        --query 'OrganizationalUnits[?Name==`Security`].Id' \
        --output text) && [ -n "$SECURITY_OU_ID" ]; then
        log_warn "Security OU はすでに存在します: $SECURITY_OU_ID"
    else
        SECURITY_OU_ID=$(aws organizations create-organizational-unit \
            --parent-id $ROOT_ID \
            --name Security \
            --query 'OrganizationalUnit.Id' \
            --output text)
        log_info "Security OU を作成しました: $SECURITY_OU_ID"
    fi

    # Production OU の作成
    if PROD_OU_ID=$(aws organizations list-organizational-units-for-parent \
        --parent-id $ROOT_ID \
        --query 'OrganizationalUnits[?Name==`Production`].Id' \
        --output text) && [ -n "$PROD_OU_ID" ]; then
        log_warn "Production OU はすでに存在します: $PROD_OU_ID"
    else
        PROD_OU_ID=$(aws organizations create-organizational-unit \
            --parent-id $ROOT_ID \
            --name Production \
            --query 'OrganizationalUnit.Id' \
            --output text)
        log_info "Production OU を作成しました: $PROD_OU_ID"
    fi

    # Non-Production OU の作成
    if NONPROD_OU_ID=$(aws organizations list-organizational-units-for-parent \
        --parent-id $ROOT_ID \
        --query 'OrganizationalUnits[?Name==`Non-Production`].Id' \
        --output text) && [ -n "$NONPROD_OU_ID" ]; then
        log_warn "Non-Production OU はすでに存在します: $NONPROD_OU_ID"
    else
        NONPROD_OU_ID=$(aws organizations create-organizational-unit \
            --parent-id $ROOT_ID \
            --name Non-Production \
            --query 'OrganizationalUnit.Id' \
            --output text)
        log_info "Non-Production OU を作成しました: $NONPROD_OU_ID"
    fi

    # OU IDを環境変数として保存
    echo "export SECURITY_OU_ID=$SECURITY_OU_ID" > ou-ids.env
    echo "export PROD_OU_ID=$PROD_OU_ID" >> ou-ids.env
    echo "export NONPROD_OU_ID=$NONPROD_OU_ID" >> ou-ids.env

    log_info "OU IDを ou-ids.env に保存しました"
}

# Service Control Policy (SCP) の作成
create_service_control_policies() {
    log_info "Service Control Policies (SCP) を作成中..."

    # リージョン制限ポリシーの作成
    cat > /tmp/region-restriction-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyAllOutsideApprovedRegions",
      "Effect": "Deny",
      "NotAction": [
        "a4b:*",
        "acm:*",
        "aws-marketplace-management:*",
        "aws-marketplace:*",
        "aws-portal:*",
        "budgets:*",
        "ce:*",
        "chime:*",
        "cloudfront:*",
        "config:*",
        "cur:*",
        "directconnect:*",
        "ec2:DescribeRegions",
        "ec2:DescribeTransitGateways",
        "ec2:DescribeVpnGateways",
        "fms:*",
        "globalaccelerator:*",
        "health:*",
        "iam:*",
        "importexport:*",
        "kms:*",
        "mobileanalytics:*",
        "networkmanager:*",
        "organizations:*",
        "pricing:*",
        "route53:*",
        "route53domains:*",
        "s3:GetAccountPublic*",
        "s3:ListAllMyBuckets",
        "s3:PutAccountPublic*",
        "shield:*",
        "sts:*",
        "support:*",
        "trustedadvisor:*",
        "waf-regional:*",
        "waf:*",
        "wafv2:*",
        "wellarchitected:*"
      ],
      "Resource": "*",
      "Condition": {
        "StringNotEquals": {
          "aws:RequestedRegion": [
            "ap-northeast-1",
            "us-east-1"
          ]
        }
      }
    }
  ]
}
EOF

    # SCPの作成または確認
    if POLICY_ID=$(aws organizations list-policies \
        --filter SERVICE_CONTROL_POLICY \
        --query 'Policies[?Name==`RegionRestriction`].Id' \
        --output text) && [ -n "$POLICY_ID" ]; then
        log_warn "RegionRestriction ポリシーはすでに存在します: $POLICY_ID"
    else
        POLICY_ID=$(aws organizations create-policy \
            --content file:///tmp/region-restriction-policy.json \
            --description "Allow only Tokyo and N.Virginia regions" \
            --name RegionRestriction \
            --type SERVICE_CONTROL_POLICY \
            --query 'Policy.PolicySummary.Id' \
            --output text)
        log_info "RegionRestriction ポリシーを作成しました: $POLICY_ID"
    fi

    # Production OUにポリシーを適用（ou-ids.envから読み込み）
    if [ -f ou-ids.env ]; then
        source ou-ids.env

        # すでに適用されているか確認
        if aws organizations list-policies-for-target \
            --target-id $PROD_OU_ID \
            --filter SERVICE_CONTROL_POLICY \
            --query 'Policies[?Name==`RegionRestriction`]' | grep -q "RegionRestriction"; then
            log_warn "ポリシーはすでに Production OU に適用されています"
        else
            aws organizations attach-policy \
                --policy-id $POLICY_ID \
                --target-id $PROD_OU_ID
            log_info "ポリシーを Production OU に適用しました"
        fi
    else
        log_error "ou-ids.env が見つかりません"
        exit 1
    fi

    # 一時ファイルの削除
    rm -f /tmp/region-restriction-policy.json
}

# 設定の確認と表示
display_configuration() {
    log_info "=== Organizations 構成 ==="

    echo ""
    echo "組織情報:"
    aws organizations describe-organization

    echo ""
    echo "アカウント一覧:"
    aws organizations list-accounts --output table

    echo ""
    echo "Organizational Units:"
    ROOT_ID=$(aws organizations list-roots --query 'Roots[0].Id' --output text)
    aws organizations list-organizational-units-for-parent \
        --parent-id $ROOT_ID \
        --output table

    echo ""
    echo "Service Control Policies:"
    aws organizations list-policies \
        --filter SERVICE_CONTROL_POLICY \
        --output table

    log_info "=== セットアップ完了 ==="
}

# メイン処理
main() {
    log_info "AWS Organizations セットアップを開始します"

    check_prerequisites
    setup_organizations
    create_organizational_units
    create_service_control_policies
    display_configuration

    log_info "すべての処理が完了しました！"
    log_info "次のステップ: 9.2-共通系アカウントとネットワーク統合 に進んでください"
}

# スクリプト実行
main "$@"
