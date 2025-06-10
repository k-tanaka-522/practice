# CRUD API 実装ガイド

## 目次

1. [概要](#概要)
2. [CRUD操作の基礎](#crud操作の基礎)
3. [実装アーキテクチャ](#実装アーキテクチャ)
4. [実装手順](#実装手順)
5. [API仕様](#api仕様)
6. [テスト手順](#テスト手順)
7. [ベストプラクティス](#ベストプラクティス)

## 概要

このガイドでは、AWS上でサーバーレスCRUD APIを実装します。以下の技術を使用します：

- **API Gateway**: RESTful APIエンドポイント
- **Lambda**: ビジネスロジック処理
- **DynamoDB**: NoSQLデータストア
- **Cognito**: 認証・認可

## CRUD操作の基礎

### CRUDとは？

CRUD は、ほぼすべてのアプリケーションで必要となる基本的なデータ操作の頭文字です：

- **C**reate（作成）: 新しいデータを追加
- **R**ead（読み取り）: データを取得
- **U**pdate（更新）: 既存のデータを変更
- **D**elete（削除）: データを削除

### HTTPメソッドとの対応

| CRUD操作 | HTTPメソッド | 用途 |
|---------|------------|------|
| Create  | POST       | 新規リソース作成 |
| Read    | GET        | リソース取得 |
| Update  | PUT/PATCH  | リソース更新 |
| Delete  | DELETE     | リソース削除 |

## 実装アーキテクチャ

```
┌──────────────┐     ┌─────────────────┐     ┌──────────────┐
│   Client     │────▶│   API Gateway   │────▶│   Lambda     │
│ (Frontend)   │◀────│  + Authorizer   │◀────│  Functions   │
└──────────────┘     └─────────────────┘     └──────────────┘
                              │                       │
                              ▼                       ▼
                     ┌─────────────────┐     ┌──────────────┐
                     │    Cognito      │     │  DynamoDB    │
                     │   User Pool     │     │    Table     │
                     └─────────────────┘     └──────────────┘
```

### DynamoDBテーブル設計

```yaml
# プライマリキー
PartitionKey: userId (String)  # ユーザーID
SortKey: itemId (String)       # アイテムID

# グローバルセカンダリインデックス
GSI1:
  PartitionKey: userId
  SortKey: createdAt      # 作成日時でソート

GSI2:
  PartitionKey: userId
  SortKey: itemType       # タイプ別に取得
```

## 実装手順

### Step 1: 前提条件の確認

```bash
# 認証システムが既にデプロイされていることを確認
aws cloudformation describe-stacks \
  --stack-name crud-system-dev-cognito \
  --query 'Stacks[0].StackStatus'

# User Pool IDとARNを取得
USER_POOL_ID=$(aws cloudformation describe-stacks \
  --stack-name crud-system-dev-cognito \
  --query 'Stacks[0].Outputs[?OutputKey==`UserPoolId`].OutputValue' \
  --output text)

USER_POOL_ARN=$(aws cloudformation describe-stacks \
  --stack-name crud-system-dev-cognito \
  --query 'Stacks[0].Outputs[?OutputKey==`UserPoolArn`].OutputValue' \
  --output text)
```

### Step 2: CRUD APIのデプロイ

```bash
# CRUD APIスタックのデプロイ
aws cloudformation create-stack \
  --stack-name crud-system-dev-crud-api \
  --template-body file://cloudformation/crud-api.yaml \
  --parameters \
    ParameterKey=UserPoolId,ParameterValue=$USER_POOL_ID \
    ParameterKey=UserPoolArn,ParameterValue=$USER_POOL_ARN \
  --capabilities CAPABILITY_NAMED_IAM

# デプロイ完了まで待機
aws cloudformation wait stack-create-complete \
  --stack-name crud-system-dev-crud-api
```

### Step 3: APIエンドポイントの確認

```bash
# CRUD APIエンドポイントを取得
CRUD_API_ENDPOINT=$(aws cloudformation describe-stacks \
  --stack-name crud-system-dev-crud-api \
  --query 'Stacks[0].Outputs[?OutputKey==`CrudApiEndpoint`].OutputValue' \
  --output text)

echo "CRUD API Endpoint: $CRUD_API_ENDPOINT"
```

## API仕様

### 認証ヘッダー

すべてのAPIリクエストには認証トークンが必要です：

```bash
Authorization: Bearer <ID_TOKEN>
```

### 1. アイテム作成 (Create)

**エンドポイント**: `POST /items`

**リクエストボディ**:
```json
{
  "title": "サンプルアイテム",
  "description": "これはテストアイテムです",
  "itemType": "task",
  "status": "ACTIVE",
  "tags": ["sample", "test"],
  "metadata": {
    "priority": "high",
    "category": "development"
  }
}
```

**レスポンス** (201 Created):
```json
{
  "message": "Item created successfully",
  "item": {
    "userId": "user-123",
    "itemId": "550e8400-e29b-41d4-a716-446655440000",
    "title": "サンプルアイテム",
    "description": "これはテストアイテムです",
    "itemType": "task",
    "status": "ACTIVE",
    "tags": ["sample", "test"],
    "metadata": {
      "priority": "high",
      "category": "development"
    },
    "createdAt": "2024-01-20T10:00:00.000Z",
    "updatedAt": "2024-01-20T10:00:00.000Z",
    "createdBy": "user@example.com"
  }
}
```

### 2. アイテム一覧取得 (Read - List)

**エンドポイント**: `GET /items`

**クエリパラメータ**:
- `itemType`: アイテムタイプでフィルタリング
- `sortBy`: ソート基準 (`createdAt`)
- `order`: ソート順 (`asc` または `desc`)
- `limit`: 取得件数制限
- `nextToken`: ページネーショントークン

**例**:
```bash
GET /items?itemType=task&sortBy=createdAt&order=desc&limit=10
```

**レスポンス** (200 OK):
```json
{
  "items": [
    {
      "userId": "user-123",
      "itemId": "550e8400-e29b-41d4-a716-446655440000",
      "title": "サンプルアイテム",
      "itemType": "task",
      "status": "ACTIVE",
      "createdAt": "2024-01-20T10:00:00.000Z"
    }
  ],
  "count": 1,
  "nextToken": "eyJsYXN0S2V5IjogInZhbHVlIn0="
}
```

### 3. アイテム詳細取得 (Read - Single)

**エンドポイント**: `GET /items/{itemId}`

**レスポンス** (200 OK):
```json
{
  "userId": "user-123",
  "itemId": "550e8400-e29b-41d4-a716-446655440000",
  "title": "サンプルアイテム",
  "description": "これはテストアイテムです",
  "itemType": "task",
  "status": "ACTIVE",
  "tags": ["sample", "test"],
  "metadata": {
    "priority": "high",
    "category": "development"
  },
  "createdAt": "2024-01-20T10:00:00.000Z",
  "updatedAt": "2024-01-20T10:00:00.000Z",
  "createdBy": "user@example.com"
}
```

### 4. アイテム更新 (Update)

**エンドポイント**: `PUT /items/{itemId}`

**リクエストボディ**:
```json
{
  "title": "更新されたアイテム",
  "description": "説明を更新しました",
  "status": "COMPLETED",
  "tags": ["updated", "completed"]
}
```

**レスポンス** (200 OK):
```json
{
  "message": "Item updated successfully",
  "item": {
    "userId": "user-123",
    "itemId": "550e8400-e29b-41d4-a716-446655440000",
    "title": "更新されたアイテム",
    "description": "説明を更新しました",
    "status": "COMPLETED",
    "tags": ["updated", "completed"],
    "updatedAt": "2024-01-20T11:00:00.000Z",
    "updatedBy": "user@example.com"
  }
}
```

### 5. アイテム削除 (Delete)

**エンドポイント**: `DELETE /items/{itemId}`

**レスポンス** (200 OK):
```json
{
  "message": "Item deleted successfully"
}
```

**注意**: ソフトデリート実装のため、アイテムのステータスが`DELETED`に変更されます。

## テスト手順

### 1. 認証トークンの取得

```bash
# ログインしてトークンを取得
curl -X POST ${API_ENDPOINT}/auth/signin \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "Test123!@#$"
  }' | jq -r '.authenticationResult.IdToken' > token.txt

# トークンを変数に保存
ID_TOKEN=$(cat token.txt)
```

### 2. CRUDオペレーションのテスト

```bash
# 1. アイテム作成
curl -X POST ${CRUD_API_ENDPOINT}/items \
  -H "Authorization: Bearer $ID_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "テストタスク",
    "description": "これはテスト用のタスクです",
    "itemType": "task",
    "tags": ["test", "sample"]
  }' | jq '.'

# レスポンスからitemIdを取得
ITEM_ID=$(curl -X POST ${CRUD_API_ENDPOINT}/items \
  -H "Authorization: Bearer $ID_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title": "Test", "itemType": "task"}' | jq -r '.item.itemId')

# 2. アイテム一覧取得
curl -X GET ${CRUD_API_ENDPOINT}/items \
  -H "Authorization: Bearer $ID_TOKEN" | jq '.'

# 3. アイテム詳細取得
curl -X GET ${CRUD_API_ENDPOINT}/items/$ITEM_ID \
  -H "Authorization: Bearer $ID_TOKEN" | jq '.'

# 4. アイテム更新
curl -X PUT ${CRUD_API_ENDPOINT}/items/$ITEM_ID \
  -H "Authorization: Bearer $ID_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "更新されたタスク",
    "status": "IN_PROGRESS"
  }' | jq '.'

# 5. アイテム削除
curl -X DELETE ${CRUD_API_ENDPOINT}/items/$ITEM_ID \
  -H "Authorization: Bearer $ID_TOKEN" | jq '.'
```

## ベストプラクティス

### 1. エラーハンドリング

```javascript
// Lambda関数でのエラーハンドリング例
try {
  // 処理実行
} catch (error) {
  console.error('Error:', error);
  
  // クライアントエラー (4xx)
  if (error.code === 'ValidationException') {
    return {
      statusCode: 400,
      body: JSON.stringify({ error: 'Invalid input' })
    };
  }
  
  // サーバーエラー (5xx)
  return {
    statusCode: 500,
    body: JSON.stringify({ error: 'Internal server error' })
  };
}
```

### 2. 入力検証

```javascript
// 必須フィールドの検証
if (!body.title || !body.itemType) {
  return {
    statusCode: 400,
    body: JSON.stringify({
      error: 'Missing required fields: title, itemType'
    })
  };
}

// 文字列長の検証
if (body.title.length > 100) {
  return {
    statusCode: 400,
    body: JSON.stringify({
      error: 'Title must be 100 characters or less'
    })
  };
}
```

### 3. ページネーション

大量のデータを扱う場合は、必ずページネーションを実装：

```javascript
// DynamoDBでのページネーション
const params = {
  TableName: TABLE_NAME,
  Limit: 20,  // 1ページあたり20件
  ExclusiveStartKey: lastEvaluatedKey  // 前のページの最後のキー
};

const result = await dynamodb.query(params).promise();

// 次のページトークンを返す
if (result.LastEvaluatedKey) {
  response.nextToken = Buffer.from(
    JSON.stringify(result.LastEvaluatedKey)
  ).toString('base64');
}
```

### 4. アクセス制御

ユーザーは自分のデータのみアクセス可能：

```javascript
// userIdでフィルタリング
const userId = event.requestContext.authorizer.claims.sub;

const params = {
  TableName: TABLE_NAME,
  Key: {
    userId: userId,  // 認証されたユーザーのIDを使用
    itemId: itemId
  }
};
```

### 5. 監査ログ

すべての変更操作を追跡：

```javascript
// 作成者・更新者の記録
item.createdBy = event.requestContext.authorizer.claims.email;
item.createdAt = new Date().toISOString();

// 更新時
item.updatedBy = event.requestContext.authorizer.claims.email;
item.updatedAt = new Date().toISOString();
```

## パフォーマンス最適化

### 1. DynamoDBの最適化

```yaml
# 適切なインデックスの設計
GlobalSecondaryIndexes:
  - IndexName: userId-createdAt-index
    # 最新のアイテムを効率的に取得

  - IndexName: userId-itemType-index
    # タイプ別のフィルタリングを高速化
```

### 2. Lambda関数の最適化

```javascript
// 接続の再利用
const dynamodb = new AWS.DynamoDB.DocumentClient({
  httpOptions: {
    agent: new https.Agent({ keepAlive: true })
  }
});

// コールドスタート対策
exports.handler = async (event) => {
  // ハンドラー内でのみ必要なモジュールをロード
  const heavyModule = require('heavy-module');
};
```

### 3. API Gatewayのキャッシング

```yaml
# 読み取り専用エンドポイントでキャッシュを有効化
CachingEnabled: true
CacheClusterSize: '0.5'  # GB
CacheTtlInSeconds: 300   # 5分間キャッシュ
```

## トラブルシューティング

### よくある問題と解決方法

#### 1. 認証エラー (401 Unauthorized)

```bash
# トークンの有効期限確認
jwt decode $ID_TOKEN

# 新しいトークンを取得
curl -X POST ${API_ENDPOINT}/auth/refresh \
  -H "Content-Type: application/json" \
  -d "{\"refreshToken\": \"$REFRESH_TOKEN\"}"
```

#### 2. アクセス拒否エラー (403 Forbidden)

```bash
# Lambda実行ロールの権限確認
aws iam get-role-policy \
  --role-name crud-system-dev-crud-lambda-role \
  --policy-name DynamoDBPolicy
```

#### 3. データが見つからない (404 Not Found)

```bash
# DynamoDBテーブルの確認
aws dynamodb scan \
  --table-name crud-system-dev-items \
  --filter-expression "userId = :userId" \
  --expression-attribute-values '{":userId":{"S":"user-123"}}'
```

## モニタリング

### CloudWatchダッシュボード

```bash
# API Gatewayメトリクス
- 4XXError: クライアントエラー率
- 5XXError: サーバーエラー率
- Count: リクエスト数
- Latency: レスポンス時間

# Lambdaメトリクス
- Invocations: 実行回数
- Errors: エラー率
- Duration: 実行時間
- Throttles: スロットリング

# DynamoDBメトリクス
- ConsumedReadCapacityUnits
- ConsumedWriteCapacityUnits
- UserErrors
- SystemErrors
```

## まとめ

このガイドでは、AWSのサーバーレスサービスを使用してスケーラブルなCRUD APIを実装しました。主な学習ポイント：

1. **API Gateway**によるRESTful API設計
2. **Lambda**でのビジネスロジック実装
3. **DynamoDB**でのNoSQLデータモデリング
4. **Cognito**による認証・認可
5. エラーハンドリングとベストプラクティス

次のステップとして、以下の機能拡張を検討できます：

- バッチ操作の実装
- リアルタイム更新（WebSocket）
- 検索機能の追加（ElasticSearch連携）
- ファイルアップロード機能
- データのエクスポート/インポート機能