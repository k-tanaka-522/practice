# CRUDシステム実装編

## 概要

このディレクトリでは、AWS上でサーバーレスCRUDシステムを実装します。認証からデータ操作まで、エンタープライズレベルのアプリケーションに必要な機能を段階的に学習できます。

## 学習目標

- 🔐 **認証・認可システム**の実装
- 📊 **CRUD操作**の基本概念と実装
- 🏗️ **サーバーレスアーキテクチャ**の設計
- 🛡️ **セキュリティベストプラクティス**の適用
- 📈 **スケーラブルなAPI**の構築

## アーキテクチャ概要

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Frontend      │────▶│  API Gateway    │────▶│    Lambda       │
│  (React/Vue)    │     │  + Authorizer   │     │   Functions     │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                                │                         │
                                ▼                         ▼
                        ┌─────────────────┐     ┌─────────────────┐
                        │    Cognito      │     │   DynamoDB      │
                        │   User Pool     │     │   Tables        │
                        └─────────────────┘     └─────────────────┘
```

## ディレクトリ構成

```
03-CRUDシステム実装編/
├── README.md                          # このファイル
├── 3.1-基本CRUD/
│   ├── 3.1.1-ユーザー管理システム/      # 認証・ユーザー管理
│   │   ├── cloudformation/
│   │   │   ├── cognito-user-pool.yaml
│   │   │   ├── api-gateway-auth.yaml
│   │   │   └── master-stack.yaml
│   │   └── docs/
│   │       ├── implementation-guide.md
│   │       └── security-best-practices.md
│   └── 3.1.2-データ操作API/            # CRUD操作API
│       ├── cloudformation/
│       │   └── crud-api.yaml
│       └── docs/
│           └── crud-implementation-guide.md
└── 3.2-高度なCRUD/                    # 高度な機能
    ├── 3.2.1-ファイルアップロード/
    └── 3.2.2-リアルタイム更新/
```

## 🚀 クイックスタート

### 前提条件

1. **AWS CLI** がインストール・設定済み
2. **適切なIAM権限** が設定済み
3. **Node.js 18+** がインストール済み
4. **jq** がインストール済み

```bash
# AWS CLI の確認
aws --version
aws sts get-caller-identity

# 必要なツールの確認
node --version
jq --version
```

### 1. 簡単デプロイ（推奨）

```bash
# デプロイスクリプトを実行
./scripts/deploy-crud-system.sh deploy

# 特定の環境にデプロイ
./scripts/deploy-crud-system.sh -e prod -r us-west-2 deploy
```

### 2. 手動デプロイ

#### Step 1: 認証システムのデプロイ

```bash
cd 03-CRUDシステム実装編/3.1-基本CRUD/3.1.1-ユーザー管理システム

# Cognito User Pool をデプロイ
aws cloudformation create-stack \
  --stack-name crud-system-dev-auth \
  --template-body file://cloudformation/cognito-user-pool.yaml \
  --parameters \
    ParameterKey=EnvironmentName,ParameterValue=dev \
    ParameterKey=ProjectName,ParameterValue=crud-system \
  --capabilities CAPABILITY_NAMED_IAM

# デプロイ完了まで待機
aws cloudformation wait stack-create-complete \
  --stack-name crud-system-dev-auth
```

#### Step 2: CRUD APIのデプロイ

```bash
cd ../3.1.2-データ操作API

# User Pool情報を取得
USER_POOL_ID=$(aws cloudformation describe-stacks \
  --stack-name crud-system-dev-auth \
  --query 'Stacks[0].Outputs[?OutputKey==`UserPoolId`].OutputValue' \
  --output text)

USER_POOL_ARN=$(aws cloudformation describe-stacks \
  --stack-name crud-system-dev-auth \
  --query 'Stacks[0].Outputs[?OutputKey==`UserPoolArn`].OutputValue' \
  --output text)

# CRUD API をデプロイ
aws cloudformation create-stack \
  --stack-name crud-system-dev-crud-api \
  --template-body file://cloudformation/crud-api.yaml \
  --parameters \
    ParameterKey=UserPoolId,ParameterValue=$USER_POOL_ID \
    ParameterKey=UserPoolArn,ParameterValue=$USER_POOL_ARN \
  --capabilities CAPABILITY_NAMED_IAM
```

## 📚 学習コンテンツ

### 3.1.1 ユーザー管理システム

**学習内容:**
- AWS Cognitoによる認証システム構築
- パスワードポリシーとMFA設定
- Lambda Triggersの活用
- セキュリティベストプラクティス

**主要ファイル:**
- `cloudformation/cognito-user-pool.yaml` - Cognito設定
- `docs/implementation-guide.md` - 実装ガイド
- `docs/security-best-practices.md` - セキュリティガイド

### 3.1.2 データ操作API

**学習内容:**
- RESTful CRUD APIの設計・実装
- DynamoDBでのNoSQLデータモデリング
- API Gatewayの認可設定
- エラーハンドリングとページネーション

**主要ファイル:**
- `cloudformation/crud-api.yaml` - CRUD API設定
- `docs/crud-implementation-guide.md` - CRUD実装ガイド

## 🧪 動作確認・テスト

### 基本テスト

```bash
# デプロイ状況確認
./scripts/deploy-crud-system.sh status

# 自動テスト実行
./scripts/deploy-crud-system.sh test
```

### 手動テスト

```bash
# エンドポイントURLを取得
AUTH_ENDPOINT=$(aws cloudformation describe-stacks \
  --stack-name crud-system-dev-auth \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiEndpoint`].OutputValue' \
  --output text)

CRUD_ENDPOINT=$(aws cloudformation describe-stacks \
  --stack-name crud-system-dev-crud-api \
  --query 'Stacks[0].Outputs[?OutputKey==`CrudApiEndpoint`].OutputValue' \
  --output text)

# 1. ユーザー登録
curl -X POST ${AUTH_ENDPOINT}/auth/signup \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "Test123!@#$",
    "name": "Test User"
  }'

# 2. メール検証（メールで受信したコードを使用）
curl -X POST ${AUTH_ENDPOINT}/auth/verify \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "code": "123456"
  }'

# 3. ログイン
TOKEN=$(curl -X POST ${AUTH_ENDPOINT}/auth/signin \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "Test123!@#$"
  }' | jq -r '.authenticationResult.IdToken')

# 4. アイテム作成
curl -X POST ${CRUD_ENDPOINT}/items \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "テストアイテム",
    "description": "これはテスト用のアイテムです",
    "itemType": "task",
    "tags": ["test", "sample"]
  }'

# 5. アイテム一覧取得
curl -X GET ${CRUD_ENDPOINT}/items \
  -H "Authorization: Bearer $TOKEN"
```

## 📊 監視・ログ

### CloudWatchダッシュボード

デプロイ後、以下のメトリクスを監視できます：

- **認証API**: ログイン成功/失敗率
- **CRUD API**: API呼び出し数、エラー率、レスポンス時間
- **Lambda**: 実行時間、エラー数、スロットリング
- **DynamoDB**: 読み取り/書き込み容量、エラー

### ログ確認

```bash
# Lambda関数のログ確認
aws logs filter-log-events \
  --log-group-name "/aws/lambda/crud-system-dev-signup" \
  --start-time $(date -u -d '1 hour ago' +%s)000

# API Gatewayのログ確認
aws logs filter-log-events \
  --log-group-name "/aws/apigateway/crud-system-dev-auth-api"
```

## 🛠️ トラブルシューティング

### よくある問題

#### 1. 認証エラー (401 Unauthorized)

```bash
# トークンの有効期限確認
echo $TOKEN | cut -d. -f2 | base64 -d | jq .exp

# 新しいトークンを取得
curl -X POST ${AUTH_ENDPOINT}/auth/refresh \
  -H "Content-Type: application/json" \
  -d "{\"refreshToken\": \"$REFRESH_TOKEN\"}"
```

#### 2. Lambda関数のタイムアウト

```bash
# CloudWatchログで詳細確認
aws logs tail /aws/lambda/crud-system-dev-create-item --follow
```

#### 3. DynamoDBの容量不足

```bash
# テーブル設定確認
aws dynamodb describe-table --table-name crud-system-dev-items
```

### デバッグコマンド

```bash
# スタック状態の詳細確認
aws cloudformation describe-stack-events \
  --stack-name crud-system-dev-auth

# リソース一覧表示
aws cloudformation list-stack-resources \
  --stack-name crud-system-dev-crud-api
```

## 🔧 カスタマイズ

### 環境別設定

```bash
# 本番環境へのデプロイ
./scripts/deploy-crud-system.sh \
  -e prod \
  -r us-east-1 \
  -m "prod-noreply@yourcompany.com" \
  deploy
```

### パフォーマンス調整

```yaml
# Lambda関数のメモリサイズ調整
MemorySize: 512  # 256MB → 512MB

# DynamoDB の読み取り/書き込み容量調整
BillingMode: PROVISIONED
ProvisionedThroughput:
  ReadCapacityUnits: 5
  WriteCapacityUnits: 5
```

## 🧹 クリーンアップ

```bash
# 全リソースを削除
./scripts/deploy-crud-system.sh cleanup

# 手動削除
aws cloudformation delete-stack --stack-name crud-system-dev-crud-api
aws cloudformation delete-stack --stack-name crud-system-dev-auth
```

## 📈 次のステップ

1. **3.2-高度なCRUD** セクションで以下を学習：
   - ファイルアップロード機能
   - リアルタイム更新（WebSocket）
   - バッチ処理とETL

2. **フロントエンド連携**:
   - React/Vue.js での認証UI実装
   - AWS Amplify の活用

3. **DevOps/CI/CD**:
   - GitHub Actions でのデプロイ自動化
   - 複数環境管理

## 📞 サポート

問題が発生した場合は、以下を確認してください：

1. [実装ガイド](3.1-基本CRUD/3.1.1-ユーザー管理システム/docs/implementation-guide.md)
2. [セキュリティベストプラクティス](3.1-基本CRUD/3.1.1-ユーザー管理システム/docs/security-best-practices.md)
3. [CRUD実装ガイド](3.1-基本CRUD/3.1.2-データ操作API/docs/crud-implementation-guide.md)

---

## 🎯 学習チェックリスト

- [ ] AWS Cognitoの基本概念を理解
- [ ] User Pool とApp Client の違いを理解
- [ ] Lambda Triggers の仕組みを理解
- [ ] API GatewayでのCognito認証を理解
- [ ] DynamoDBのパーティションキー設計を理解
- [ ] RESTful APIの設計原則を理解
- [ ] CRUD操作の実装パターンを理解
- [ ] エラーハンドリングのベストプラクティスを理解
- [ ] セキュリティ設定の重要性を理解
- [ ] 監視とログの活用方法を理解

**完了したらNext: [高度なCRUD機能](3.2-高度なCRUD/README.md)へ進んでください！**