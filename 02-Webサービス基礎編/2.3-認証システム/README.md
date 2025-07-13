# 2.3 認証システム

## 🎯 学習目標

**Cognito User Pool を使った認証システムの実装**を通じて、安全なWebアプリケーションのユーザー管理基礎を習得します。

### このセクションで学ぶこと

1. **Cognito User Pool**: ユーザー管理サービスの基本概念
2. **JWT トークン**: 認証トークンの仕組みと使い方
3. **サインアップ・サインイン**: ユーザー登録とログイン機能
4. **API認証**: API Gateway と Cognito の連携
5. **セキュリティ設定**: パスワードポリシー、MFA設定

## ⏰ 所要時間
**約3時間**

```
設計・準備     [45分] → 認証設計とCognito理解
実装・デプロイ  [90分] → User Pool + API連携構築
テスト・確認   [45分] → 認証フローのテストと確認
```

## 📋 前提条件

- 2.2-API基盤構築の完了
- JWTトークンの基本概念理解
- JavaScript/Cognito SDKの基本操作

## 🏗️ 構築するアーキテクチャ

```
┌─────────────────────────────────────────────────────────────────┐
│                    Frontend Application                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │   Login     │  │   Signup    │  │ Protected   │             │
│  │    Page     │  │    Page     │  │    Pages    │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
└─────────────┬───────────────┬───────────────┬───────────────────┘
              │               │               │
              ▼               ▼               ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Cognito User Pool                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │   Sign Up   │  │   Sign In   │  │    JWT      │             │
│  │   Process   │  │   Process   │  │  Validation │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
└─────────────────────────────────────┬───────────────────────────┘
                                      │ JWT Token
                                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                     API Gateway                                │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │   Cognito   │  │ Protected   │  │   Public    │             │
│  │ Authorizer  │  │    APIs     │  │    APIs     │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
└─────────────────────────────────────┬───────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Lambda Functions                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │   User      │  │  Protected  │  │   Admin     │             │
│  │  Profile    │  │   Data      │  │ Functions   │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
└─────────────────────────────────────────────────────────────────┘
```

## 📦 実装する機能

### 1. Cognito User Pool設定

- **ユーザー登録**: メール/パスワード認証
- **パスワードポリシー**: 安全性要件の設定
- **メール確認**: サインアップ時のメール認証
- **User Pool Client**: フロントエンド用設定

### 2. 認証API

- **POST /auth/signup**: ユーザー登録
- **POST /auth/signin**: ユーザーログイン
- **POST /auth/confirm**: メール確認
- **GET /auth/profile**: ユーザープロフィール取得

### 3. 保護されたAPI

- **GET /protected/data**: 認証必須のデータ取得
- **POST /protected/update**: 認証必須のデータ更新

## 🛠️ 実装手順

### Step 1: Cognito User Pool作成

```bash
# 作業ディレクトリに移動
cd 2.3-認証システム

# CloudFormationテンプレートの確認
ls cloudformation/
```

### Step 2: 認証システムのデプロイ

```bash
# S3にテンプレートをアップロード
aws s3 cp cloudformation/templates/ s3://your-cf-bucket/auth-system/ --recursive

# 認証システムスタックのデプロイ
aws cloudformation create-stack \
  --stack-name auth-system \
  --template-body file://cloudformation/main-stack.yaml \
  --parameters ParameterKey=Environment,ParameterValue=dev \
               ParameterKey=CFBucket,ParameterValue=your-cf-bucket \
               ParameterKey=ApiStackName,ParameterValue=api-foundation \
  --capabilities CAPABILITY_IAM
```

### Step 3: Cognito設定の確認

```bash
# User Pool ID の取得
aws cloudformation describe-stacks \
  --stack-name auth-system \
  --query 'Stacks[0].Outputs[?OutputKey==`UserPoolId`].OutputValue' \
  --output text

# User Pool Client ID の取得
aws cloudformation describe-stacks \
  --stack-name auth-system \
  --query 'Stacks[0].Outputs[?OutputKey==`UserPoolClientId`].OutputValue' \
  --output text
```

### Step 4: 認証テスト

```bash
# ユーザー登録のテスト
curl -X POST https://your-api-url/dev/auth/signup \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "TempPassword123!",
    "name": "Test User"
  }'

# ログインのテスト
curl -X POST https://your-api-url/dev/auth/signin \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "TempPassword123!"
  }'
```

## 🔐 JWT トークンの理解

### JWT構造

```
Header.Payload.Signature

例:
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.
eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.
SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c
```

### Payloadの内容

```json
{
  "sub": "user-uuid",
  "email": "user@example.com",
  "email_verified": true,
  "iss": "https://cognito-idp.region.amazonaws.com/userPoolId",
  "aud": "clientId",
  "exp": 1516239022,
  "iat": 1516239022,
  "auth_time": 1516239022
}
```

## 🧪 認証フローのテスト

### 1. ユーザー登録フロー

```javascript
// SDK使用例 (JavaScript)
import { CognitoIdentityProviderClient, SignUpCommand } from "@aws-sdk/client-cognito-identity-provider";

const client = new CognitoIdentityProviderClient({ region: "us-east-1" });

const signUp = async (email, password, name) => {
  const command = new SignUpCommand({
    ClientId: "your-user-pool-client-id",
    Username: email,
    Password: password,
    UserAttributes: [
      {
        Name: "email",
        Value: email
      },
      {
        Name: "name",
        Value: name
      }
    ]
  });

  try {
    const response = await client.send(command);
    console.log("Sign up successful:", response);
    return response;
  } catch (error) {
    console.error("Sign up error:", error);
    throw error;
  }
};
```

### 2. ログインフロー

```javascript
import { CognitoIdentityProviderClient, InitiateAuthCommand } from "@aws-sdk/client-cognito-identity-provider";

const signIn = async (email, password) => {
  const command = new InitiateAuthCommand({
    ClientId: "your-user-pool-client-id",
    AuthFlow: "USER_PASSWORD_AUTH",
    AuthParameters: {
      USERNAME: email,
      PASSWORD: password
    }
  });

  try {
    const response = await client.send(command);
    const accessToken = response.AuthenticationResult.AccessToken;
    const idToken = response.AuthenticationResult.IdToken;
    
    // トークンをローカルストレージに保存
    localStorage.setItem('accessToken', accessToken);
    localStorage.setItem('idToken', idToken);
    
    return response;
  } catch (error) {
    console.error("Sign in error:", error);
    throw error;
  }
};
```

### 3. 保護されたAPIの呼び出し

```javascript
const callProtectedAPI = async () => {
  const accessToken = localStorage.getItem('accessToken');
  
  if (!accessToken) {
    throw new Error('No access token found');
  }

  const response = await fetch('https://your-api-url/dev/protected/data', {
    method: 'GET',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json'
    }
  });

  if (!response.ok) {
    throw new Error('API call failed');
  }

  return response.json();
};
```

## 📁 ファイル構成

```
2.3-認証システム/
├── README.md
├── cloudformation/
│   ├── main-stack.yaml
│   └── templates/
│       ├── cognito-user-pool.yaml
│       ├── api-authorizer.yaml
│       └── lambda-auth/
│           ├── signup/
│           │   ├── index.js
│           │   └── package.json
│           ├── signin/
│           │   ├── index.js
│           │   └── package.json
│           └── profile/
│               ├── index.js
│               └── package.json
├── frontend-examples/
│   ├── auth-service.js
│   ├── login-form.html
│   └── signup-form.html
├── tests/
│   ├── auth-flow-test.js
│   └── protected-api-test.http
└── docs/
    ├── jwt-guide.md
    └── security-best-practices.md
```

## 🔧 Lambda関数サンプルコード

### Sign Up Function

```javascript
import { CognitoIdentityProviderClient, SignUpCommand } from "@aws-sdk/client-cognito-identity-provider";

const client = new CognitoIdentityProviderClient({ region: process.env.AWS_REGION });

exports.handler = async (event) => {
    console.log('Event:', JSON.stringify(event, null, 2));
    
    try {
        const body = JSON.parse(event.body || '{}');
        const { email, password, name } = body;
        
        // バリデーション
        if (!email || !password || !name) {
            return {
                statusCode: 400,
                headers: {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                body: JSON.stringify({
                    error: 'Email, password, and name are required'
                })
            };
        }
        
        const command = new SignUpCommand({
            ClientId: process.env.USER_POOL_CLIENT_ID,
            Username: email,
            Password: password,
            UserAttributes: [
                { Name: 'email', Value: email },
                { Name: 'name', Value: name }
            ]
        });
        
        const result = await client.send(command);
        
        return {
            statusCode: 200,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({
                success: true,
                message: 'User signed up successfully',
                userSub: result.UserSub,
                codeDeliveryDetails: result.CodeDeliveryDetails
            })
        };
        
    } catch (error) {
        console.error('Error:', error);
        
        return {
            statusCode: 400,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({
                error: error.message || 'Sign up failed'
            })
        };
    }
};
```

### Sign In Function

```javascript
import { CognitoIdentityProviderClient, InitiateAuthCommand } from "@aws-sdk/client-cognito-identity-provider";

const client = new CognitoIdentityProviderClient({ region: process.env.AWS_REGION });

exports.handler = async (event) => {
    console.log('Event:', JSON.stringify(event, null, 2));
    
    try {
        const body = JSON.parse(event.body || '{}');
        const { email, password } = body;
        
        if (!email || !password) {
            return {
                statusCode: 400,
                headers: {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                body: JSON.stringify({
                    error: 'Email and password are required'
                })
            };
        }
        
        const command = new InitiateAuthCommand({
            ClientId: process.env.USER_POOL_CLIENT_ID,
            AuthFlow: 'USER_PASSWORD_AUTH',
            AuthParameters: {
                USERNAME: email,
                PASSWORD: password
            }
        });
        
        const result = await client.send(command);
        
        return {
            statusCode: 200,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({
                success: true,
                message: 'User signed in successfully',
                tokens: {
                    accessToken: result.AuthenticationResult.AccessToken,
                    idToken: result.AuthenticationResult.IdToken,
                    refreshToken: result.AuthenticationResult.RefreshToken,
                    expiresIn: result.AuthenticationResult.ExpiresIn
                }
            })
        };
        
    } catch (error) {
        console.error('Error:', error);
        
        return {
            statusCode: 401,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({
                error: error.message || 'Sign in failed'
            })
        };
    }
};
```

### Protected API Function

```javascript
exports.handler = async (event) => {
    console.log('Event:', JSON.stringify(event, null, 2));
    
    try {
        // Cognito Authorizer によってJWTが検証済み
        const userClaims = event.requestContext.authorizer.claims;
        
        const userData = {
            userId: userClaims.sub,
            email: userClaims.email,
            name: userClaims.name,
            emailVerified: userClaims.email_verified === 'true',
            authTime: new Date(userClaims.auth_time * 1000).toISOString()
        };
        
        return {
            statusCode: 200,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({
                success: true,
                message: 'Protected data accessed successfully',
                user: userData,
                data: {
                    protectedMessage: 'This is protected data',
                    timestamp: new Date().toISOString()
                }
            })
        };
        
    } catch (error) {
        console.error('Error:', error);
        
        return {
            statusCode: 500,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({
                error: 'Internal server error'
            })
        };
    }
};
```

## 🔒 セキュリティベストプラクティス

### 1. パスワードポリシー

```yaml
# CloudFormationでの設定例
PasswordPolicy:
  MinimumLength: 8
  RequireUppercase: true
  RequireLowercase: true
  RequireNumbers: true
  RequireSymbols: true
  TemporaryPasswordValidityDays: 7
```

### 2. トークン管理

- **AccessToken**: 短期間有効（1時間）、API認証用
- **IdToken**: ユーザー情報含有、フロントエンド用
- **RefreshToken**: 長期間有効（30日）、トークン更新用

### 3. CORS設定

```javascript
const corsHeaders = {
    'Access-Control-Allow-Origin': 'https://your-frontend-domain.com',
    'Access-Control-Allow-Headers': 'Content-Type,Authorization',
    'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
    'Access-Control-Allow-Credentials': 'true'
};
```

## 🧪 テストシナリオ

### 1. 正常系テスト

1. **新規ユーザー登録**
   - 有効なメール・パスワードで登録
   - 確認メールの受信確認
   - メール確認コードでアクティベート

2. **ログイン**
   - 正しい認証情報でログイン
   - JWTトークンの取得確認
   - トークンの有効性確認

3. **保護されたAPI**
   - 有効なトークンでアクセス成功
   - ユーザー情報の正確な取得

### 2. 異常系テスト

1. **不正な登録情報**
   - 弱いパスワード
   - 不正なメール形式
   - 重複メールアドレス

2. **不正なログイン**
   - 間違ったパスワード
   - 存在しないユーザー
   - 確認前のユーザー

3. **不正なAPI アクセス**
   - 無効なトークン
   - 期限切れトークン
   - トークンなしアクセス

## 💰 コスト試算

### 月間利用想定
- Cognito ユーザー: 100人
- 認証API: 1,000回/月
- 保護されたAPI: 5,000回/月

### 予想コスト
```
Cognito User Pool: $0.55 (MAU 50人まで無料)
API Gateway: $3.50
Lambda: $0.20 (無料枠内)
CloudWatch Logs: $1.00

合計: 約 $5.25/月
```

## 🚀 次のステップ

このセクションの完了後：

1. **認証フローの動作確認**: サインアップ〜ログイン〜API呼び出し
2. **セキュリティ設定の確認**: パスワードポリシー、JWT設定
3. **エラーハンドリングの確認**: 不正アクセス時の適切な応答

**次は 2.4-データベース基礎 で DynamoDB を使ったデータ永続化を学習します！**

## 🧹 リソースのクリーンアップ

学習完了後、以下のコマンドでリソースを削除：

```bash
# CloudFormationスタックの削除
aws cloudformation delete-stack --stack-name auth-system

# 削除完了の確認
aws cloudformation describe-stacks --stack-name auth-system
```

## 📚 参考資料

- [Cognito User Pool Developer Guide](https://docs.aws.amazon.com/cognito/latest/developerguide/)
- [JWT.io - JWT Introduction](https://jwt.io/introduction/)
- [API Gateway Lambda Authorizers](https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-lambda-authorizer-lambda-function-create.html)
- [Cognito Security Best Practices](https://docs.aws.amazon.com/cognito/latest/developerguide/security.html)

---

**🎯 目標**: 安全な認証システムをマスターし、データベースとの連携準備を整える！