# 2.4 データベース基礎

## 🎯 学習目標

**DynamoDB を使った基本的なデータ操作**を通じて、NoSQLデータベースの概念とサーバーレスアプリケーションでのデータ永続化を習得します。

### このセクションで学ぶこと

1. **DynamoDB基本概念**: NoSQL、テーブル、パーティションキー、ソートキー
2. **CRUD操作**: Create、Read、Update、Delete の実装
3. **データモデリング**:効率的なテーブル設計とインデックス
4. **Lambda連携**: API経由でのデータベース操作
5. **パフォーマンス**: 読み書きキャパシティとコスト最適化

## ⏰ 所要時間
**約2時間**

```
設計・準備     [30分] → データモデル設計とDynamoDB理解
実装・デプロイ  [60分] → テーブル作成とCRUD API構築
テスト・確認   [30分] → データ操作テストと動作確認
```

## 📋 前提条件

- 2.3-認証システムの完了
- NoSQLデータベースの基本概念理解
- Lambda関数でのAWS SDK使用経験

## 🏗️ 構築するアーキテクチャ

```
┌─────────────────────────────────────────────────────────────────┐
│                   Frontend Application                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │   Create    │  │    List     │  │   Update    │             │
│  │    Form     │  │    View     │  │   Delete    │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
└─────────────┬───────────────┬───────────────┬───────────────────┘
              │               │               │
              ▼               ▼               ▼
┌─────────────────────────────────────────────────────────────────┐
│                      API Gateway                               │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │    POST     │  │     GET     │  │   PUT/DEL   │             │
│  │ /api/items  │  │ /api/items  │  │ /api/items  │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
└─────────────┬───────────────┬───────────────┬───────────────────┘
              │               │               │
              ▼               ▼               ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Lambda Functions                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │   Create    │  │    List     │  │   Update    │             │
│  │   Item      │  │   Items     │  │   Delete    │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
└─────────────────────────────────────┬───────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                      DynamoDB                                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │    Users    │  │    Items    │  │   Global    │             │
│  │    Table    │  │    Table    │  │   Index     │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
└─────────────────────────────────────────────────────────────────┘
```

## 📦 実装する機能

### 1. DynamoDB テーブル設計

**Usersテーブル**:
- パーティションキー: `userId` (String)
- 属性: `email`, `name`, `createdAt`, `updatedAt`

**Itemsテーブル**:
- パーティションキー: `userId` (String)
- ソートキー: `itemId` (String)
- 属性: `title`, `description`, `status`, `createdAt`, `updatedAt`

**GSI (Global Secondary Index)**:
- インデックス名: `StatusIndex`
- パーティションキー: `status`
- ソートキー: `createdAt`

### 2. CRUD API エンドポイント

- **POST /api/items**: アイテム作成
- **GET /api/items**: ユーザーのアイテム一覧取得
- **GET /api/items/{itemId}**: 特定アイテム取得
- **PUT /api/items/{itemId}**: アイテム更新
- **DELETE /api/items/{itemId}**: アイテム削除

### 3. データバリデーション

- 必須フィールドチェック
- データ型検証
- 文字数制限
- ユーザー権限確認

## 🛠️ 実装手順

### Step 1: DynamoDB テーブル作成

```bash
# 作業ディレクトリに移動
cd 2.4-データベース基礎

# CloudFormationテンプレートの確認
ls cloudformation/
```

### Step 2: データベースシステムのデプロイ

```bash
# S3にテンプレートをアップロード
aws s3 cp cloudformation/templates/ s3://your-cf-bucket/database-basics/ --recursive

# データベースシステムスタックのデプロイ
aws cloudformation create-stack \
  --stack-name database-basics \
  --template-body file://cloudformation/main-stack.yaml \
  --parameters ParameterKey=Environment,ParameterValue=dev \
               ParameterKey=CFBucket,ParameterValue=your-cf-bucket \
               ParameterKey=AuthStackName,ParameterValue=auth-system \
  --capabilities CAPABILITY_IAM
```

### Step 3: テーブル設定の確認

```bash
# テーブル一覧の確認
aws dynamodb list-tables

# Usersテーブルの詳細確認
aws dynamodb describe-table --table-name dev-users-table

# Itemsテーブルの詳細確認
aws dynamodb describe-table --table-name dev-items-table
```

### Step 4: CRUD操作のテスト

```bash
# アイテム作成のテスト
curl -X POST https://your-api-url/dev/api/items \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Test Item",
    "description": "This is a test item",
    "status": "active"
  }'

# アイテム一覧取得のテスト
curl -X GET https://your-api-url/dev/api/items \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

## 📊 DynamoDB データモデリング

### 1. テーブル設計原則

**単一テーブル設計** vs **複数テーブル設計**:
```
複数テーブル設計（今回採用）:
- Users テーブル: ユーザー情報
- Items テーブル: アイテム情報
- 理解しやすく、管理しやすい
```

### 2. キー設計

**パーティションキー選択**:
```javascript
// 良い例: ユーザーごとにデータが分散
PartitionKey: userId

// 悪い例: データが偏る
PartitionKey: status (active/inactive のみ)
```

**ソートキー活用**:
```javascript
// 時系列でのソート
SortKey: createdAt

// 複合キー
SortKey: itemId (UUID)
```

### 3. インデックス設計

**GSI活用例**:
```yaml
StatusIndex:
  PartitionKey: status
  SortKey: createdAt
  # 特定ステータスのアイテムを作成日時順で取得
```

## 🔧 Lambda関数サンプルコード

### Create Item Function

```javascript
import { DynamoDBClient, PutItemCommand } from "@aws-sdk/client-dynamodb";
import { marshall } from "@aws-sdk/util-dynamodb";
import { v4 as uuidv4 } from 'uuid';

const client = new DynamoDBClient({ region: process.env.AWS_REGION });

exports.handler = async (event) => {
    console.log('Event:', JSON.stringify(event, null, 2));
    
    try {
        // ユーザー認証情報の取得
        const userClaims = event.requestContext.authorizer.claims;
        const userId = userClaims.sub;
        
        // リクエストボディの解析
        const body = JSON.parse(event.body || '{}');
        const { title, description, status = 'active' } = body;
        
        // バリデーション
        if (!title || !description) {
            return {
                statusCode: 400,
                headers: {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                body: JSON.stringify({
                    error: 'Title and description are required'
                })
            };
        }
        
        // アイテムデータの準備
        const itemId = uuidv4();
        const now = new Date().toISOString();
        
        const item = {
            userId,
            itemId,
            title,
            description,
            status,
            createdAt: now,
            updatedAt: now
        };
        
        // DynamoDBに保存
        const command = new PutItemCommand({
            TableName: process.env.ITEMS_TABLE_NAME,
            Item: marshall(item),
            ConditionExpression: 'attribute_not_exists(itemId)'
        });
        
        await client.send(command);
        
        return {
            statusCode: 201,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({
                success: true,
                message: 'Item created successfully',
                item
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
                error: 'Failed to create item'
            })
        };
    }
};
```

### List Items Function

```javascript
import { DynamoDBClient, QueryCommand } from "@aws-sdk/client-dynamodb";
import { unmarshall } from "@aws-sdk/util-dynamodb";

const client = new DynamoDBClient({ region: process.env.AWS_REGION });

exports.handler = async (event) => {
    console.log('Event:', JSON.stringify(event, null, 2));
    
    try {
        // ユーザー認証情報の取得
        const userClaims = event.requestContext.authorizer.claims;
        const userId = userClaims.sub;
        
        // クエリパラメータの取得
        const queryParams = event.queryStringParameters || {};
        const status = queryParams.status;
        const limit = parseInt(queryParams.limit) || 50;
        
        let command;
        
        if (status) {
            // ステータスでフィルタリング（GSI使用）
            command = new QueryCommand({
                TableName: process.env.ITEMS_TABLE_NAME,
                IndexName: 'StatusIndex',
                KeyConditionExpression: '#status = :status',
                FilterExpression: 'userId = :userId',
                ExpressionAttributeNames: {
                    '#status': 'status'
                },
                ExpressionAttributeValues: {
                    ':status': { S: status },
                    ':userId': { S: userId }
                },
                Limit: limit,
                ScanIndexForward: false // 降順（新しい順）
            });
        } else {
            // ユーザーの全アイテム取得
            command = new QueryCommand({
                TableName: process.env.ITEMS_TABLE_NAME,
                KeyConditionExpression: 'userId = :userId',
                ExpressionAttributeValues: {
                    ':userId': { S: userId }
                },
                Limit: limit,
                ScanIndexForward: false
            });
        }
        
        const result = await client.send(command);
        const items = result.Items.map(item => unmarshall(item));
        
        return {
            statusCode: 200,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({
                success: true,
                items,
                count: items.length,
                lastEvaluatedKey: result.LastEvaluatedKey
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
                error: 'Failed to list items'
            })
        };
    }
};
```

### Update Item Function

```javascript
import { DynamoDBClient, UpdateItemCommand, GetItemCommand } from "@aws-sdk/client-dynamodb";
import { marshall, unmarshall } from "@aws-sdk/util-dynamodb";

const client = new DynamoDBClient({ region: process.env.AWS_REGION });

exports.handler = async (event) => {
    console.log('Event:', JSON.stringify(event, null, 2));
    
    try {
        // ユーザー認証情報の取得
        const userClaims = event.requestContext.authorizer.claims;
        const userId = userClaims.sub;
        
        // パスパラメータからitemIdを取得
        const itemId = event.pathParameters.itemId;
        
        // リクエストボディの解析
        const body = JSON.parse(event.body || '{}');
        const { title, description, status } = body;
        
        // まず、アイテムの存在確認とユーザー権限確認
        const getCommand = new GetItemCommand({
            TableName: process.env.ITEMS_TABLE_NAME,
            Key: marshall({ userId, itemId })
        });
        
        const existingItem = await client.send(getCommand);
        
        if (!existingItem.Item) {
            return {
                statusCode: 404,
                headers: {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                body: JSON.stringify({
                    error: 'Item not found'
                })
            };
        }
        
        // 更新式の構築
        let updateExpression = 'SET updatedAt = :updatedAt';
        const expressionAttributeValues = {
            ':updatedAt': { S: new Date().toISOString() }
        };
        
        if (title) {
            updateExpression += ', title = :title';
            expressionAttributeValues[':title'] = { S: title };
        }
        
        if (description) {
            updateExpression += ', description = :description';
            expressionAttributeValues[':description'] = { S: description };
        }
        
        if (status) {
            updateExpression += ', #status = :status';
            expressionAttributeValues[':status'] = { S: status };
        }
        
        const updateCommand = new UpdateItemCommand({
            TableName: process.env.ITEMS_TABLE_NAME,
            Key: marshall({ userId, itemId }),
            UpdateExpression: updateExpression,
            ExpressionAttributeValues: expressionAttributeValues,
            ExpressionAttributeNames: status ? { '#status': 'status' } : undefined,
            ReturnValues: 'ALL_NEW'
        });
        
        const result = await client.send(updateCommand);
        const updatedItem = unmarshall(result.Attributes);
        
        return {
            statusCode: 200,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({
                success: true,
                message: 'Item updated successfully',
                item: updatedItem
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
                error: 'Failed to update item'
            })
        };
    }
};
```

### Delete Item Function

```javascript
import { DynamoDBClient, DeleteItemCommand, GetItemCommand } from "@aws-sdk/client-dynamodb";
import { marshall } from "@aws-sdk/util-dynamodb";

const client = new DynamoDBClient({ region: process.env.AWS_REGION });

exports.handler = async (event) => {
    console.log('Event:', JSON.stringify(event, null, 2));
    
    try {
        // ユーザー認証情報の取得
        const userClaims = event.requestContext.authorizer.claims;
        const userId = userClaims.sub;
        
        // パスパラメータからitemIdを取得
        const itemId = event.pathParameters.itemId;
        
        // アイテムの存在確認とユーザー権限確認
        const getCommand = new GetItemCommand({
            TableName: process.env.ITEMS_TABLE_NAME,
            Key: marshall({ userId, itemId })
        });
        
        const existingItem = await client.send(getCommand);
        
        if (!existingItem.Item) {
            return {
                statusCode: 404,
                headers: {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                body: JSON.stringify({
                    error: 'Item not found'
                })
            };
        }
        
        // アイテムの削除
        const deleteCommand = new DeleteItemCommand({
            TableName: process.env.ITEMS_TABLE_NAME,
            Key: marshall({ userId, itemId }),
            ConditionExpression: 'attribute_exists(itemId)'
        });
        
        await client.send(deleteCommand);
        
        return {
            statusCode: 200,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({
                success: true,
                message: 'Item deleted successfully'
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
                error: 'Failed to delete item'
            })
        };
    }
};
```

## 📁 ファイル構成

```
2.4-データベース基礎/
├── README.md
├── cloudformation/
│   ├── main-stack.yaml
│   └── templates/
│       ├── dynamodb-tables.yaml
│       ├── lambda-crud.yaml
│       └── lambda-code/
│           ├── create-item/
│           │   ├── index.js
│           │   └── package.json
│           ├── list-items/
│           │   ├── index.js
│           │   └── package.json
│           ├── update-item/
│           │   ├── index.js
│           │   └── package.json
│           └── delete-item/
│               ├── index.js
│               └── package.json
├── examples/
│   ├── data-operations.js
│   └── batch-operations.js
├── tests/
│   ├── crud-tests.http
│   └── data-validation-tests.js
└── docs/
    ├── data-modeling.md
    └── performance-tuning.md
```

## 🧪 テストとデバッグ

### 1. CRUD操作テスト

**CREATE テスト**:
```bash
curl -X POST https://your-api-url/dev/api/items \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Learning DynamoDB",
    "description": "Understanding NoSQL database operations",
    "status": "active"
  }'
```

**READ テスト**:
```bash
# 全アイテム取得
curl -X GET https://your-api-url/dev/api/items \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"

# ステータスでフィルタ
curl -X GET "https://your-api-url/dev/api/items?status=active&limit=10" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

**UPDATE テスト**:
```bash
curl -X PUT https://your-api-url/dev/api/items/ITEM_ID \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Updated Title",
    "status": "completed"
  }'
```

**DELETE テスト**:
```bash
curl -X DELETE https://your-api-url/dev/api/items/ITEM_ID \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

### 2. パフォーマンステスト

```javascript
// 大量データ挿入テスト
const createMultipleItems = async (count) => {
  const promises = [];
  
  for (let i = 0; i < count; i++) {
    promises.push(
      fetch('/api/items', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          title: `Item ${i}`,
          description: `Description for item ${i}`,
          status: i % 2 === 0 ? 'active' : 'completed'
        })
      })
    );
  }
  
  const startTime = Date.now();
  await Promise.all(promises);
  const endTime = Date.now();
  
  console.log(`Created ${count} items in ${endTime - startTime}ms`);
};
```

## 📊 パフォーマンス最適化

### 1. 読み書きキャパシティ設定

```yaml
# On-Demand（推奨）
BillingMode: PAY_PER_REQUEST

# Provisioned（予測可能な負荷の場合）
BillingMode: PROVISIONED
ProvisionedThroughput:
  ReadCapacityUnits: 5
  WriteCapacityUnits: 5
```

### 2. クエリ最適化

```javascript
// 良い例: パーティションキーを使用
const getUserItems = async (userId) => {
  return await dynamodb.query({
    TableName: 'Items',
    KeyConditionExpression: 'userId = :userId',
    ExpressionAttributeValues: {
      ':userId': userId
    }
  }).promise();
};

// 悪い例: Scanを使用（避ける）
const getAllActiveItems = async () => {
  return await dynamodb.scan({
    TableName: 'Items',
    FilterExpression: '#status = :status',
    ExpressionAttributeNames: {
      '#status': 'status'
    },
    ExpressionAttributeValues: {
      ':status': 'active'
    }
  }).promise();
};
```

### 3. インデックス活用

```javascript
// GSIを使用したステータス別検索
const getItemsByStatus = async (status) => {
  return await dynamodb.query({
    TableName: 'Items',
    IndexName: 'StatusIndex',
    KeyConditionExpression: '#status = :status',
    ExpressionAttributeNames: {
      '#status': 'status'
    },
    ExpressionAttributeValues: {
      ':status': status
    },
    ScanIndexForward: false // 新しい順
  }).promise();
};
```

## 💰 コスト試算

### 月間利用想定
- アイテム数: 1,000件
- 読み取り: 10,000回/月
- 書き込み: 1,000回/月
- ストレージ: 1MB

### 予想コスト（On-Demand）
```
書き込み: $1.25 (1M書き込みまで)
読み取り: $0.25 (1M読み取りまで)
ストレージ: $0.25 (GB/月)

合計: 約 $1.75/月
```

### 無料利用枠
```
DynamoDB無料利用枠（12ヶ月間）:
- 25GB ストレージ
- 2.5M 読み取りリクエスト
- 1M 書き込みリクエスト
```

## 🚀 次のステップ

このセクションの完了後：

1. **CRUD操作の動作確認**: 全てのAPI エンドポイントのテスト完了
2. **データ整合性の確認**: バリデーションとエラーハンドリングの確認
3. **パフォーマンス確認**: レスポンス時間とスループットの測定

**次は 2.5-簡単なWebアプリ で React フロントエンドとの統合を行います！**

## 🧹 リソースのクリーンアップ

学習完了後、以下のコマンドでリソースを削除：

```bash
# CloudFormationスタックの削除
aws cloudformation delete-stack --stack-name database-basics

# 削除完了の確認
aws cloudformation describe-stacks --stack-name database-basics
```

## 📚 参考資料

- [DynamoDB Developer Guide](https://docs.aws.amazon.com/dynamodb/latest/developerguide/)
- [DynamoDB Best Practices](https://docs.aws.amazon.com/dynamodb/latest/developerguide/best-practices.html)
- [NoSQL Workbench for DynamoDB](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/workbench.html)
- [DynamoDB Pricing](https://aws.amazon.com/dynamodb/pricing/)

---

**🎯 目標**: NoSQLデータベースの基礎をマスターし、フルスタックWebアプリケーションの完成へ！