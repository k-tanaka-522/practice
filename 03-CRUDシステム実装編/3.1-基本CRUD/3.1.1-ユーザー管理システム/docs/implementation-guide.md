# AWS Cognito認証システム 実装ガイド

## 目次

1. [概要](#概要)
2. [アーキテクチャ](#アーキテクチャ)
3. [前提条件](#前提条件)
4. [実装手順](#実装手順)
5. [動作確認](#動作確認)
6. [トラブルシューティング](#トラブルシューティング)

## 概要

このガイドでは、AWS Cognitoを使用したセキュアな認証システムを構築します。以下の機能を実装します：

- ユーザー登録（サインアップ）
- メール検証
- ログイン/ログアウト
- パスワードリセット
- 多要素認証（MFA）
- ユーザープロファイル管理

## アーキテクチャ

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Frontend      │────▶│  API Gateway    │────▶│    Lambda       │
│  (React/Vue)    │     │  + Authorizer   │     │   Functions     │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                                │                         │
                                ▼                         ▼
                        ┌─────────────────┐     ┌─────────────────┐
                        │    Cognito      │     │   DynamoDB      │
                        │   User Pool     │     │   (User Data)   │
                        └─────────────────┘     └─────────────────┘
```

## 前提条件

### 必要なツール

```bash
# AWS CLI のバージョン確認
aws --version
# aws-cli/2.13.0 以上が必要

# Node.js のバージョン確認
node --version
# v18.0.0 以上が必要

# Python のバージョン確認（オプション）
python3 --version
# Python 3.9 以上が推奨
```

### AWS アカウントの準備

1. AWS アカウントを作成
2. IAM ユーザーを作成し、以下の権限を付与：
   - CloudFormation フルアクセス
   - Cognito フルアクセス
   - API Gateway フルアクセス
   - Lambda フルアクセス
   - DynamoDB フルアクセス
   - IAM ロール作成権限

### AWS CLI の設定

```bash
# AWS認証情報の設定
aws configure
# AWS Access Key ID: [アクセスキー]
# AWS Secret Access Key: [シークレットキー]
# Default region name: ap-northeast-1
# Default output format: json

# 設定の確認
aws sts get-caller-identity
```

## 実装手順

### Step 1: プロジェクトのセットアップ

```bash
# プロジェクトディレクトリに移動
cd /path/to/03-CRUDシステム実装編/3.1-基本CRUD/3.1.1-ユーザー管理システム

# ディレクトリ構造の確認
tree -L 2
# cloudformation/
# ├── api-gateway-auth.yaml
# ├── cognito-user-pool.yaml
# └── master-stack.yaml
# docs/
# ├── implementation-guide.md
# └── security-best-practices.md
```

### Step 2: パラメータファイルの作成

```bash
# パラメータファイルの作成
cat > cloudformation/parameters.json << EOF
{
  "Parameters": {
    "EnvironmentName": "dev",
    "ProjectName": "crud-system",
    "SESVerifiedEmail": "noreply@example.com",
    "EnableMFA": "OPTIONAL"
  }
}
EOF
```

### Step 3: Cognito User Pool のデプロイ

```bash
# スタックの作成
aws cloudformation create-stack \
  --stack-name crud-system-dev-cognito \
  --template-body file://cloudformation/cognito-user-pool.yaml \
  --parameters file://cloudformation/parameters.json \
  --capabilities CAPABILITY_NAMED_IAM

# スタックの状態確認
aws cloudformation describe-stacks \
  --stack-name crud-system-dev-cognito \
  --query 'Stacks[0].StackStatus' \
  --output text

# 作成完了まで待機（約5-10分）
aws cloudformation wait stack-create-complete \
  --stack-name crud-system-dev-cognito
```

#### 🎓 学習ポイント: Cognito User Pool

**Cognito User Pool とは？**
- ユーザーディレクトリサービス
- 認証・認可の機能を提供
- サインアップ、サインイン、パスワードリセットなどの機能

**主要な設定項目：**

```yaml
# パスワードポリシー
PasswordPolicy:
  MinimumLength: 12          # セキュリティ強化
  RequireUppercase: true     # 大文字必須
  RequireNumbers: true       # 数字必須

# MFA設定
MfaConfiguration: OPTIONAL   # 任意設定
EnabledMfas:
  - SOFTWARE_TOKEN_MFA      # TOTP認証

# Lambda トリガー
LambdaConfig:
  PreSignUp: !GetAtt PreSignUpLambda.Arn
  PostConfirmation: !GetAtt PostConfirmationLambda.Arn
```

### Step 4: API Gateway と Lambda のデプロイ

```bash
# User Pool ID を取得
USER_POOL_ID=$(aws cloudformation describe-stacks \
  --stack-name crud-system-dev-cognito \
  --query 'Stacks[0].Outputs[?OutputKey==`UserPoolId`].OutputValue' \
  --output text)

# Web App Client ID を取得
WEB_APP_CLIENT_ID=$(aws cloudformation describe-stacks \
  --stack-name crud-system-dev-cognito \
  --query 'Stacks[0].Outputs[?OutputKey==`WebAppClientId`].OutputValue' \
  --output text)

# API スタックのデプロイ
aws cloudformation create-stack \
  --stack-name crud-system-dev-api \
  --template-body file://cloudformation/api-gateway-auth.yaml \
  --parameters \
    ParameterKey=UserPoolId,ParameterValue=$USER_POOL_ID \
    ParameterKey=WebAppClientId,ParameterValue=$WEB_APP_CLIENT_ID \
  --capabilities CAPABILITY_NAMED_IAM

# デプロイ完了まで待機
aws cloudformation wait stack-create-complete \
  --stack-name crud-system-dev-api
```

#### 🎓 学習ポイント: API Gateway と Lambda

**API Gateway の役割：**
- RESTful API のエンドポイント提供
- リクエストの認証・認可
- レート制限とスロットリング

**Lambda 関数の構成：**

1. **SignUpFunction**: ユーザー登録
2. **SignInFunction**: ログイン処理
3. **VerifyEmailFunction**: メール検証
4. **RefreshTokenFunction**: トークン更新
5. **UserProfileFunction**: プロファイル管理

### Step 5: リソースの確認

```bash
# 作成されたリソースの確認
echo "=== Cognito User Pool ==="
echo "User Pool ID: $USER_POOL_ID"
echo "Web App Client ID: $WEB_APP_CLIENT_ID"

echo -e "\n=== API Endpoints ==="
API_ENDPOINT=$(aws cloudformation describe-stacks \
  --stack-name crud-system-dev-api \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiEndpoint`].OutputValue' \
  --output text)
echo "API Base URL: $API_ENDPOINT"

echo -e "\n=== DynamoDB Tables ==="
aws dynamodb list-tables --query 'TableNames[?contains(@, `crud-system-dev`)]'
```

## 動作確認

### 1. ユーザー登録のテスト

```bash
# サインアップエンドポイントのテスト
curl -X POST ${API_ENDPOINT}/auth/signup \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "Test123!@#$",
    "name": "Test User"
  }'

# 期待されるレスポンス
# {
#   "message": "User registered successfully",
#   "userSub": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
#   "userConfirmed": false
# }
```

### 2. メール検証

```bash
# メールで受信した検証コードを使用
curl -X POST ${API_ENDPOINT}/auth/verify \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "code": "123456"
  }'
```

### 3. ログイン

```bash
# ログインテスト
curl -X POST ${API_ENDPOINT}/auth/signin \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "Test123!@#$"
  }'

# レスポンスからトークンを取得
# {
#   "authenticationResult": {
#     "AccessToken": "eyJra...",
#     "IdToken": "eyJra...",
#     "RefreshToken": "eyJra..."
#   }
# }
```

### 4. 認証付きAPIの呼び出し

```bash
# プロファイル取得（認証が必要）
ACCESS_TOKEN="<上記で取得したAccessToken>"

curl -X GET ${API_ENDPOINT}/profile \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

## AWS コンソールでの確認

### Cognito User Pool の確認

1. AWS コンソールにログイン
2. Cognito サービスに移動
3. 作成した User Pool を選択
4. 確認すべき項目：
   - ユーザー一覧
   - アプリケーションクライアント設定
   - Lambda トリガー設定
   - セキュリティ設定

### API Gateway の確認

1. API Gateway サービスに移動
2. 作成した API を選択
3. 確認すべき項目：
   - リソース構造
   - 各メソッドの設定
   - Cognito Authorizer の設定
   - ステージ設定

### DynamoDB の確認

1. DynamoDB サービスに移動
2. テーブル一覧から確認
3. 確認すべき項目：
   - user-profiles テーブル
   - login-history テーブル
   - データの暗号化設定

## セキュリティのベストプラクティス

### 1. トークンの管理

```javascript
// フロントエンドでの実装例
class TokenManager {
  static setTokens(tokens) {
    // アクセストークンはメモリに保存
    this.accessToken = tokens.AccessToken;
    
    // リフレッシュトークンは HttpOnly Cookie に保存
    // または Secure な localStorage
    localStorage.setItem('refreshToken', tokens.RefreshToken);
  }
  
  static getAccessToken() {
    return this.accessToken;
  }
  
  static async refreshToken() {
    const refreshToken = localStorage.getItem('refreshToken');
    const response = await fetch('/auth/refresh', {
      method: 'POST',
      body: JSON.stringify({ refreshToken })
    });
    const data = await response.json();
    this.setTokens(data.authenticationResult);
  }
}
```

### 2. HTTPS の使用

- 本番環境では必ず HTTPS を使用
- CloudFront を使用して SSL/TLS 証明書を管理

### 3. CORS の設定

```yaml
# 本番環境での CORS 設定
Access-Control-Allow-Origin: https://yourdomain.com
Access-Control-Allow-Credentials: true
```

## トラブルシューティング

### よくあるエラーと対処法

#### 1. "User is not confirmed" エラー

```bash
# 原因: メール検証が完了していない
# 対処法: 検証メールを確認し、検証コードを送信

# 検証メールの再送信
aws cognito-idp resend-confirmation-code \
  --client-id $WEB_APP_CLIENT_ID \
  --username test@example.com
```

#### 2. "Invalid UserPoolId" エラー

```bash
# 原因: User Pool ID が正しくない
# 対処法: CloudFormation の出力を確認

aws cloudformation describe-stacks \
  --stack-name crud-system-dev-cognito \
  --query 'Stacks[0].Outputs[?OutputKey==`UserPoolId`].OutputValue'
```

#### 3. Lambda 関数のタイムアウト

```bash
# ログの確認
aws logs tail /aws/lambda/crud-system-dev-signup --follow

# タイムアウト値の調整が必要な場合は CloudFormation を更新
```

### ログの確認方法

```bash
# CloudWatch Logs グループ一覧
aws logs describe-log-groups \
  --log-group-name-prefix "/aws/lambda/crud-system-dev"

# 特定の Lambda 関数のログを確認
aws logs filter-log-events \
  --log-group-name "/aws/lambda/crud-system-dev-signup" \
  --start-time $(date -u -d '1 hour ago' +%s)000
```

## クリーンアップ

```bash
# リソースの削除（逆順で実行）
aws cloudformation delete-stack --stack-name crud-system-dev-api
aws cloudformation wait stack-delete-complete --stack-name crud-system-dev-api

aws cloudformation delete-stack --stack-name crud-system-dev-cognito
aws cloudformation wait stack-delete-complete --stack-name crud-system-dev-cognito
```

## 次のステップ

1. **フロントエンドの実装**
   - React/Vue.js での認証UI作成
   - AWS Amplify の活用

2. **高度な機能の追加**
   - ソーシャルログイン（Google, Facebook）
   - カスタム認証フロー
   - アクセス制御の細分化

3. **監視とアラート**
   - CloudWatch ダッシュボードの設定
   - セキュリティアラートの設定

## まとめ

このガイドでは、AWS Cognito を使用した認証システムの基本的な実装方法を学びました。CloudFormation を使用することで、インフラストラクチャをコードとして管理し、再現可能な環境を構築できます。

セキュリティは継続的な取り組みが必要です。定期的にセキュリティ設定を見直し、最新のベストプラクティスに従ってシステムを更新してください。