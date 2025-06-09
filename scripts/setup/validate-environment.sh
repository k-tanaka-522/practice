#!/bin/bash

# 環境検証スクリプト
# AI駆動開発学習プロジェクトの前提条件をチェックします

echo "==================================="
echo "環境検証スクリプト"
echo "==================================="
echo ""

# カラー定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# 検証結果を保存する変数
VALIDATION_PASSED=true

# 関数: コマンドの存在確認
check_command() {
    if command -v $1 &> /dev/null; then
        echo -e "${GREEN}✓${NC} $1 がインストールされています"
        if [ -n "$2" ]; then
            VERSION=$($2)
            echo "  バージョン: $VERSION"
        fi
    else
        echo -e "${RED}✗${NC} $1 がインストールされていません"
        VALIDATION_PASSED=false
    fi
}

# 関数: ファイルの存在確認
check_file() {
    if [ -f "$1" ]; then
        echo -e "${GREEN}✓${NC} $2 が見つかりました"
    else
        echo -e "${YELLOW}!${NC} $2 が見つかりません（オプション）"
    fi
}

echo "1. 必須ツールの確認"
echo "-------------------"

# AWS CLI
check_command "aws" "aws --version"

# Git
check_command "git" "git --version"

# Docker
check_command "docker" "docker --version"

# Node.js
check_command "node" "node --version"

# npm
check_command "npm" "npm --version"

# Python
check_command "python3" "python3 --version"

echo ""
echo "2. AWS設定の確認"
echo "----------------"

# AWS認証情報
if [ -f ~/.aws/credentials ] || [ -n "$AWS_ACCESS_KEY_ID" ]; then
    echo -e "${GREEN}✓${NC} AWS認証情報が設定されています"
    
    # デフォルトリージョンの確認
    REGION=$(aws configure get region)
    if [ -n "$REGION" ]; then
        echo "  デフォルトリージョン: $REGION"
    else
        echo -e "${YELLOW}!${NC} デフォルトリージョンが設定されていません"
        echo "  'aws configure' を実行して設定してください"
    fi
else
    echo -e "${RED}✗${NC} AWS認証情報が設定されていません"
    echo "  'aws configure' を実行して設定してください"
    VALIDATION_PASSED=false
fi

# AWS CLIの動作確認
echo ""
echo "AWS CLIの接続テスト..."
if aws sts get-caller-identity &> /dev/null; then
    echo -e "${GREEN}✓${NC} AWS APIへの接続に成功しました"
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    echo "  アカウントID: $ACCOUNT_ID"
else
    echo -e "${RED}✗${NC} AWS APIへの接続に失敗しました"
    echo "  AWS認証情報を確認してください"
    VALIDATION_PASSED=false
fi

echo ""
echo "3. プロジェクト構造の確認"
echo "----------------------"

# 重要なディレクトリの確認
DIRS=("scripts" "docs" ".github")
for dir in "${DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo -e "${GREEN}✓${NC} $dir/ ディレクトリが存在します"
    else
        echo -e "${YELLOW}!${NC} $dir/ ディレクトリが見つかりません"
    fi
done

echo ""
echo "4. オプションツールの確認"
echo "----------------------"

# jq (JSONパーサー)
check_command "jq" "jq --version"

# VS Code
check_command "code" "code --version"

echo ""
echo "==================================="
if [ "$VALIDATION_PASSED" = true ]; then
    echo -e "${GREEN}検証完了: すべての必須項目がクリアされました！${NC}"
    echo "プロジェクトを開始できます。"
else
    echo -e "${RED}検証失敗: いくつかの必須項目が不足しています。${NC}"
    echo "上記のエラーメッセージを確認して、必要なツールをインストールしてください。"
    exit 1
fi
echo "==================================="
