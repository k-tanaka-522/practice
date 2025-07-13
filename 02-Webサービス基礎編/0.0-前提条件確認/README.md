# 0.0 前提条件確認

## 🎯 このステップの目的

**01-基礎インフラストラクチャー編の完了確認**と、Webサービス構築に必要な環境の準備を行います。

## 📋 前提条件チェックリスト

### ✅ 必須要件

#### 1. 01-基礎インフラストラクチャー編の完了
```bash
# VPCが存在することを確認
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=*aws-practice*" --query 'Vpcs[0].VpcId'

# 期待する結果: VPC IDが表示される
```

#### 2. AWS CLI設定確認
```bash
# AWS認証情報確認
aws sts get-caller-identity

# 期待する結果: Account ID、User ARN等が表示される
```

#### 3. 必要な権限確認
```bash
# S3バケット作成権限
aws s3 mb s3://test-permission-check-$(date +%s) --region ap-northeast-1

# すぐに削除
aws s3 rb s3://test-permission-check-* --region ap-northeast-1
```

### ✅ 推奨要件

#### 1. Node.js環境（React開発用）
```bash
# Node.js バージョン確認（推奨: 18.x以上）
node --version

# npm バージョン確認
npm --version
```

#### 2. Git環境
```bash
# Git バージョン確認
git --version

# GitHubアカウント設定確認
git config --global user.name
git config --global user.email
```

#### 3. テキストエディタ/IDE
- **推奨**: Visual Studio Code
- **必須プラグイン**: AWS Toolkit, CloudFormation Linter

## 🚀 環境セットアップ

### 1. Node.js インストール（未インストールの場合）

#### macOS
```bash
# Homebrewを使用
brew install node

# またはnodenvを使用
brew install nodenv
nodenv install 18.19.0
nodenv global 18.19.0
```

#### Windows
```bash
# Chocolateyを使用
choco install nodejs

# または公式サイトからダウンロード
# https://nodejs.org/
```

#### Linux (Ubuntu/Debian)
```bash
# Node.js 18.x LTSをインストール
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs
```

### 2. 開発用ツールのインストール
```bash
# AWS CDK（オプション - 高度な機能で使用）
npm install -g aws-cdk

# Serverless Framework（オプション）
npm install -g serverless

# Create React App（React開発用）
npm install -g create-react-app
```

## 🧪 動作確認テスト

### 1. AWS サービスアクセステスト
```bash
# S3バケット一覧取得
aws s3 ls

# CloudFormationスタック一覧
aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE

# API Gateway一覧（空でも正常）
aws apigateway get-rest-apis
```

### 2. Node.js 動作確認
```bash
# 簡単なReactアプリ作成テスト
npx create-react-app test-app
cd test-app
npm start

# ブラウザで http://localhost:3000 が開けばOK
# テスト後は削除
cd ..
rm -rf test-app
```

## 🔧 トラブルシューティング

### よくある問題と解決方法

#### 1. AWS CLI認証エラー
```bash
# 認証情報の再設定
aws configure

# 設定内容の確認
aws configure list
```

#### 2. Node.js バージョン問題
```bash
# Node.js バージョン確認
node --version

# 18.x未満の場合はアップデート
# macOS: brew upgrade node
# Windows: 公式サイトから再ダウンロード
```

#### 3. 権限不足エラー
```bash
# IAMユーザーの権限確認
aws iam get-user

# 必要な権限:
# - AmazonS3FullAccess
# - AmazonAPIGatewayFullAccess
# - AWSLambda_FullAccess
# - AmazonCognitoPowerUser
# - AmazonDynamoDBFullAccess
```

## 📊 確認完了チェック

以下が全て✅になったら次のステップに進めます：

- [ ] 01-基礎インフラストラクチャー編完了
- [ ] AWS CLI正常動作
- [ ] 必要な権限確認済み
- [ ] Node.js 18.x以上インストール済み
- [ ] テキストエディタ準備完了
- [ ] Git設定完了
- [ ] AWS サービスアクセステスト成功

## 🚀 次のステップ

**全ての前提条件が整ったら、静的サイト構築から始めましょう！**

👉 **[2.1 静的サイト構築](../2.1-静的サイト構築/README.md)** に進む

---

**💡 ヒント**: 環境構築で困ったら、各ツールの公式ドキュメントを参照するか、GitHub Discussionsで質問してください。