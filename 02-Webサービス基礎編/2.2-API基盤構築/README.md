# 2.2 API基盤構築

## 🎯 学習目標

**API Gateway + Lambda を使った基本的なREST APIの構築**を通じて、サーバーレスアーキテクチャの基礎を習得します。

### このセクションで学ぶこと

1. **API Gatewayの基本**: REST API、リソース、メソッドの設定
2. **Lambda関数の作成**: Node.js/Pythonでの基本的なAPI処理
3. **CORS設定**: フロントエンドとの連携準備
4. **エラーハンドリング**:適切なHTTPステータスコードとレスポンス
5. **デプロイとテスト**: API の動作確認とデバッグ手法

## ⏰ 所要時間
**約3時間**

```
設計・準備     [30分] → API設計とCloudFormation理解
実装・デプロイ  [90分] → API Gateway + Lambda構築
テスト・確認   [60分] → 動作確認とトラブルシューティング
```

## 📋 前提条件

- 01-基礎インフラストラクチャー編の完了
- 2.1-静的サイト構築の完了
- 基本的なJavaScript/Pythonの知識

## 🏗️ 構築するアーキテクチャ

```
┌─────────────────────────────────────────────────────────────────┐
│                   Frontend (S3 + CloudFront)                   │
│                        Static Website                          │
└─────────────────────────┬───────────────────────────────────────┘
                          │ HTTPS
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                     API Gateway                                │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │    GET      │  │    POST     │  │   OPTIONS   │             │
│  │ /api/hello  │  │ /api/data   │  │  (CORS)     │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
└─────────────────┬───────────────┬───────────────┬───────────────┘
                  │               │               │
                  ▼               ▼               ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Lambda Functions                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │   Hello     │  │    Data     │  │   CORS      │             │
│  │  Function   │  │  Function   │  │  Handler    │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      CloudWatch Logs                           │
│                    API実行ログとメトリクス                        │
└─────────────────────────────────────────────────────────────────┘
```

## 📦 実装する機能

### 1. 基本API エンドポイント

- **GET /api/hello**: シンプルな Hello World API
- **POST /api/data**: データを受け取り処理するAPI
- **OPTIONS /***: CORS preflight対応

### 2. Lambda関数

- **helloFunction**: 基本的なレスポンス返却
- **dataFunction**: POSTデータの処理とバリデーション
- **corsFunction**: CORS ヘッダーの設定

### 3. API Gateway設定

- **REST API**: RESTful な設計
- **CORS設定**: フロントエンドからのアクセス許可
- **ステージ管理**: dev/prod環境の分離

## 🛠️ 実装手順

### Step 1: CloudFormation準備

```bash
# 作業ディレクトリに移動
cd 2.2-API基盤構築

# CloudFormationテンプレートの確認
ls cloudformation/
```

### Step 2: Lambda関数のデプロイ

```bash
# S3バケットにLambdaコードをアップロード
aws s3 cp cloudformation/templates/ s3://your-cf-bucket/api-foundation/ --recursive

# メインスタックのデプロイ
aws cloudformation create-stack \
  --stack-name api-foundation \
  --template-body file://cloudformation/main-stack.yaml \
  --parameters ParameterKey=Environment,ParameterValue=dev \
               ParameterKey=CFBucket,ParameterValue=your-cf-bucket \
  --capabilities CAPABILITY_IAM
```

### Step 3: API Gateway設定

```bash
# デプロイ完了の確認
aws cloudformation describe-stacks --stack-name api-foundation

# API Gateway URLの取得
aws cloudformation describe-stacks \
  --stack-name api-foundation \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiGatewayUrl`].OutputValue' \
  --output text
```

### Step 4: 動作テスト

```bash
# Hello API のテスト
curl -X GET https://your-api-id.execute-api.region.amazonaws.com/dev/hello

# Data API のテスト
curl -X POST https://your-api-id.execute-api.region.amazonaws.com/dev/data \
  -H "Content-Type: application/json" \
  -d '{"name": "test", "message": "Hello from API"}'
```

## 🧪 テストとデバッグ

### 1. API テストツール

**cURLでのテスト**:
```bash
# GET リクエスト
curl -X GET https://your-api-url/dev/hello

# POST リクエスト
curl -X POST https://your-api-url/dev/data \
  -H "Content-Type: application/json" \
  -d '{"key": "value"}'
```

**Postmanでのテスト**:
- Collection作成
- Environment設定
- 自動テスト設定

### 2. ログの確認

```bash
# Lambda関数のログ確認
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/"

# 最新のログストリーム確認
aws logs describe-log-streams \
  --log-group-name "/aws/lambda/api-foundation-HelloFunction" \
  --order-by LastEventTime --descending --max-items 1
```

### 3. よくある問題と解決策

| 問題 | 原因 | 解決策 |
|------|------|--------|
| CORS エラー | CORS設定未完了 | API Gateway でCORS有効化 |
| Lambda タイムアウト | 処理時間過多 | タイムアウト設定の調整 |
| 認証エラー | IAM権限不足 | Lambda実行ロールの確認 |
| レスポンス形式エラー | API Gateway統合設定 | プロキシ統合の設定確認 |

## 📁 ファイル構成

```
2.2-API基盤構築/
├── README.md
├── cloudformation/
│   ├── main-stack.yaml
│   └── templates/
│       ├── api-gateway.yaml
│       ├── lambda-functions.yaml
│       └── lambda-code/
│           ├── hello-function/
│           │   ├── index.js
│           │   └── package.json
│           └── data-function/
│               ├── index.js
│               └── package.json
├── tests/
│   ├── api-tests.http
│   └── postman-collection.json
└── docs/
    ├── api-specification.yaml
    └── troubleshooting.md
```

## 🔧 Lambda関数サンプルコード

### Hello Function (Node.js)

```javascript
exports.handler = async (event) => {
    console.log('Event:', JSON.stringify(event, null, 2));
    
    const response = {
        statusCode: 200,
        headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type',
            'Access-Control-Allow-Methods': 'GET, POST, OPTIONS'
        },
        body: JSON.stringify({
            message: 'Hello from Lambda!',
            timestamp: new Date().toISOString(),
            requestId: event.requestContext.requestId
        })
    };
    
    return response;
};
```

### Data Function (Node.js)

```javascript
exports.handler = async (event) => {
    console.log('Event:', JSON.stringify(event, null, 2));
    
    try {
        // リクエストボディの解析
        const body = JSON.parse(event.body || '{}');
        
        // 基本的なバリデーション
        if (!body.name) {
            return {
                statusCode: 400,
                headers: {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                body: JSON.stringify({
                    error: 'Name is required'
                })
            };
        }
        
        // データ処理
        const processedData = {
            id: Math.random().toString(36).substr(2, 9),
            name: body.name,
            message: body.message || 'No message provided',
            processedAt: new Date().toISOString()
        };
        
        return {
            statusCode: 200,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({
                success: true,
                data: processedData
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

## 🔍 API仕様書

### エンドポイント一覧

| メソッド | パス | 説明 | リクエスト | レスポンス |
|----------|------|------|------------|------------|
| GET | /hello | Hello World API | なし | `{"message": "Hello from Lambda!"}` |
| POST | /data | データ処理API | `{"name": "string", "message": "string"}` | `{"success": true, "data": {...}}` |
| OPTIONS | /* | CORS Preflight | なし | CORS ヘッダー |

### レスポンス形式

**成功レスポンス**:
```json
{
  "success": true,
  "data": {
    "id": "unique-id",
    "processedAt": "2024-01-01T12:00:00.000Z"
  }
}
```

**エラーレスポンス**:
```json
{
  "error": "Error message",
  "details": "Additional error details"
}
```

## 💰 コスト試算

### 月間利用想定
- API Gateway: 1,000リクエスト/月
- Lambda: 1,000実行/月（100ms実行時間）

### 予想コスト
```
API Gateway: $3.50 (1M リクエストまで)
Lambda: $0.20 (100万リクエスト/月まで無料)
CloudWatch Logs: $0.50

合計: 約 $4.20/月
```

## 🚀 次のステップ

このセクションの完了後：

1. **API の動作確認**: すべてのエンドポイントのテスト完了
2. **ログ確認**: CloudWatch Logsでの実行ログ確認
3. **パフォーマンス確認**: レスポンス時間とエラー率の確認

**次は 2.3-認証システム で Cognito User Pool による認証機能を追加します！**

## 🧹 リソースのクリーンアップ

学習完了後、以下のコマンドでリソースを削除：

```bash
# CloudFormationスタックの削除
aws cloudformation delete-stack --stack-name api-foundation

# 削除完了の確認
aws cloudformation describe-stacks --stack-name api-foundation
```

## 📚 参考資料

- [API Gateway Developer Guide](https://docs.aws.amazon.com/apigateway/)
- [Lambda Developer Guide](https://docs.aws.amazon.com/lambda/)
- [REST API Design Best Practices](https://docs.aws.amazon.com/apigateway/latest/developerguide/rest-api-develop.html)
- [CORS Configuration](https://docs.aws.amazon.com/apigateway/latest/developerguide/how-to-cors.html)

---

**🎯 目標**: REST API の基礎をマスターし、次の認証システムに進む準備を整える！