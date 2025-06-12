# 2.3.2 DynamoDB

## 学習目標

このセクションでは、Amazon DynamoDBを使用したサーバーレスNoSQLデータベースの設計・実装・運用を学習し、高性能でスケーラブルなアプリケーションバックエンドの構築方法を習得します。

### 習得できるスキル
- DynamoDB テーブル設計とパーティション戦略
- プライマリキー・ソートキー・GSI設計
- 単一テーブル設計パターンの実装
- DynamoDB Streams を活用したイベント駆動処理
- Auto Scaling とオンデマンド課金の最適化
- DAX（DynamoDB Accelerator）によるキャッシュ戦略

## 前提知識

### 必須の知識
- NoSQL データベースの基本概念
- JSON形式データの理解
- AWS Lambda の基本操作（1.2.3セクション完了）
- CloudFormation の基本操作（1.1.1セクション完了）

### あると望ましい知識
- データモデリングの経験
- リレーショナルデータベースとの差異理解
- アプリケーションアクセスパターンの分析
- パフォーマンス最適化の概念

## アーキテクチャ概要

### DynamoDB マルチアクセスパターンアーキテクチャ

```
                    ┌─────────────────────┐
                    │   Web/Mobile        │
                    │   Applications      │
                    └─────────┬───────────┘
                              │
                    ┌─────────┼───────────┐
                    │         │           │
                    ▼         ▼           ▼
          ┌─────────────────┐ ┌──────────┐ ┌─────────────────┐
          │   API Gateway   │ │GraphQL   │ │  Direct SDK     │
          │   + Lambda      │ │AppSync   │ │   Access        │
          └─────────┬───────┘ └────┬─────┘ └─────────┬───────┘
                    │              │                 │
                    └──────────────┼─────────────────┘
                                   │
                                   ▼
          ┌─────────────────────────────────────────────────────────┐
          │                DynamoDB Accelerator (DAX)               │
          │                  (Microsecond Latency)                  │
          │                                                         │
          │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │
          │  │   Node 1    │  │   Node 2    │  │   Node 3    │   │
          │  │    Cache    │  │    Cache    │  │    Cache    │   │
          │  └─────────────┘  └─────────────┘  └─────────────┘   │
          └─────────────────────────────────────────────────────────┘
                                   │
                                   ▼
          ┌─────────────────────────────────────────────────────────┐
          │                    DynamoDB Tables                      │
          │                                                         │
          │  ┌─────────────────────────────────────────────────┐   │
          │  │               Single Table Design               │   │
          │  │                                                  │   │
          │  │  PK           SK              Data               │   │
          │  │  USER#123     PROFILE         {user info}       │   │
          │  │  USER#123     ORDER#456       {order info}      │   │
          │  │  PRODUCT#789  METADATA        {product info}    │   │
          │  │  ORDER#456    ITEM#001        {order item}      │   │
          │  │                                                  │   │
          │  │  Global Secondary Indexes (GSI):               │   │
          │  │  - GSI1: Email lookup                          │   │
          │  │  - GSI2: Status-based queries                  │   │
          │  │  - GSI3: Date range queries                    │   │
          │  └─────────────────────────────────────────────────┘   │
          └─────────────────────────────────────────────────────────┘
                                   │
                                   ▼
          ┌─────────────────────────────────────────────────────────┐
          │                 DynamoDB Streams                        │
          │                (Change Data Capture)                   │
          │                                                         │
          │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │
          │  │   INSERT    │  │   MODIFY    │  │   REMOVE    │   │
          │  │   Events    │  │   Events    │  │   Events    │   │
          │  └─────────────┘  └─────────────┘  └─────────────┘   │
          └─────────┬───────────────┬───────────────┬─────────────┘
                    │               │               │
                    ▼               ▼               ▼
          ┌─────────────────┐ ┌──────────┐ ┌─────────────────┐
          │   Lambda        │ │Kinesis   │ │   ElasticSearch │
          │  (Real-time     │ │Analytics │ │   (Search Index)│
          │   Processing)   │ │          │ │                 │
          └─────────────────┘ └──────────┘ └─────────────────┘
                    │               │               │
                    ▼               ▼               ▼
          ┌─────────────────┐ ┌──────────┐ ┌─────────────────┐
          │      SNS        │ │   S3     │ │   CloudWatch    │
          │ (Notifications) │ │(Archive) │ │   (Metrics)     │
          └─────────────────┘ └──────────┘ └─────────────────┘
```

### 主要コンポーネント
- **DynamoDB Tables**: 高性能NoSQLデータストレージ
- **Global Secondary Indexes (GSI)**: 柔軟なクエリパターン対応
- **DynamoDB Accelerator (DAX)**: マイクロ秒レベルキャッシュ
- **DynamoDB Streams**: リアルタイム変更ストリーム
- **Auto Scaling**: 動的キャパシティ調整
- **Point-in-Time Recovery**: 継続的バックアップ

## ハンズオン手順

### ステップ1: 単一テーブル設計パターンの実装

1. **エンティティ関係図と アクセスパターン分析**
```javascript
// docs/data-model-design.js
/**
 * Eコマースアプリケーションのデータモデル設計
 * 
 * エンティティ:
 * - User (ユーザー)
 * - Product (商品)
 * - Order (注文)
 * - OrderItem (注文アイテム)
 * - Category (カテゴリ)
 * - Review (レビュー)
 * 
 * アクセスパターン:
 * 1. ユーザー情報の取得 (PK: USER#{userId})
 * 2. ユーザーの注文履歴取得 (PK: USER#{userId}, SK: begins_with(ORDER#))
 * 3. 商品情報の取得 (PK: PRODUCT#{productId})
 * 4. カテゴリ別商品一覧 (GSI1: PK=CATEGORY#{categoryId})
 * 5. 注文詳細の取得 (PK: ORDER#{orderId})
 * 6. 商品レビュー一覧 (PK: PRODUCT#{productId}, SK: begins_with(REVIEW#))
 * 7. ユーザー別レビュー (GSI2: PK=USER#{userId}, SK=REVIEW#{reviewId})
 * 8. 日付範囲での注文検索 (GSI3: PK=ORDER_BY_DATE, SK=timestamp)
 */

const AccessPatterns = {
    // 基本的なエンティティアクセス
    GET_USER: {
        operation: 'GetItem',
        key: { PK: 'USER#{userId}', SK: 'PROFILE' }
    },
    
    GET_PRODUCT: {
        operation: 'GetItem', 
        key: { PK: 'PRODUCT#{productId}', SK: 'METADATA' }
    },
    
    // 1対多リレーション
    GET_USER_ORDERS: {
        operation: 'Query',
        key: { PK: 'USER#{userId}' },
        sortKey: { SK: { begins_with: 'ORDER#' } }
    },
    
    GET_PRODUCT_REVIEWS: {
        operation: 'Query',
        key: { PK: 'PRODUCT#{productId}' },
        sortKey: { SK: { begins_with: 'REVIEW#' } }
    },
    
    // GSI を使用した検索
    GET_PRODUCTS_BY_CATEGORY: {
        operation: 'Query',
        index: 'GSI1',
        key: { GSI1PK: 'CATEGORY#{categoryId}' }
    },
    
    GET_REVIEWS_BY_USER: {
        operation: 'Query', 
        index: 'GSI2',
        key: { GSI2PK: 'USER#{userId}' },
        sortKey: { GSI2SK: { begins_with: 'REVIEW#' } }
    },
    
    // 時系列検索
    GET_ORDERS_BY_DATE_RANGE: {
        operation: 'Query',
        index: 'GSI3', 
        key: { GSI3PK: 'ORDER_BY_DATE' },
        sortKey: { GSI3SK: { between: [startDate, endDate] } }
    }
};
```

2. **CloudFormation DynamoDB テーブル定義**
```yaml
# cloudformation/dynamodb-tables.yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'DynamoDB tables with single-table design pattern'

Parameters:
  ProjectName:
    Type: String
    Default: 'dynamodb-demo'
  
  EnvironmentName:
    Type: String
    Default: 'dev'
    AllowedValues: [dev, staging, prod]
  
  EnableDAX:
    Type: String
    Default: 'false'
    AllowedValues: ['true', 'false']
    Description: 'Enable DynamoDB Accelerator (DAX) cluster'

Conditions:
  IsProduction: !Equals [!Ref EnvironmentName, 'prod']
  EnableDAXCluster: !Equals [!Ref EnableDAX, 'true']

Resources:
  # メインテーブル（単一テーブル設計）
  MainTable:
    Type: AWS::DynamoDB::Table
    Properties:
      TableName: !Sub '${ProjectName}-${EnvironmentName}-main-table'
      BillingMode: !If [IsProduction, PROVISIONED, PAY_PER_REQUEST]
      
      # プロビジョニング設定（本番環境）
      ProvisionedThroughput:
        !If
          - IsProduction
          - ReadCapacityUnits: 100
            WriteCapacityUnits: 100
          - !Ref AWS::NoValue
      
      # 主キー設計
      AttributeDefinitions:
        # プライマリキー
        - AttributeName: PK
          AttributeType: S
        - AttributeName: SK
          AttributeType: S
        
        # GSI キー
        - AttributeName: GSI1PK
          AttributeType: S
        - AttributeName: GSI1SK
          AttributeType: S
        - AttributeName: GSI2PK
          AttributeType: S
        - AttributeName: GSI2SK
          AttributeType: S
        - AttributeName: GSI3PK
          AttributeType: S
        - AttributeName: GSI3SK
          AttributeType: S
      
      KeySchema:
        - AttributeName: PK
          KeyType: HASH
        - AttributeName: SK
          KeyType: RANGE
      
      # Global Secondary Indexes
      GlobalSecondaryIndexes:
        # GSI1: カテゴリ・ステータス別検索
        - IndexName: GSI1
          KeySchema:
            - AttributeName: GSI1PK
              KeyType: HASH
            - AttributeName: GSI1SK
              KeyType: RANGE
          Projection:
            ProjectionType: ALL
          ProvisionedThroughput:
            !If
              - IsProduction
              - ReadCapacityUnits: 50
                WriteCapacityUnits: 50
              - !Ref AWS::NoValue
        
        # GSI2: ユーザー別・タイプ別検索
        - IndexName: GSI2
          KeySchema:
            - AttributeName: GSI2PK
              KeyType: HASH
            - AttributeName: GSI2SK
              KeyType: RANGE
          Projection:
            ProjectionType: ALL
          ProvisionedThroughput:
            !If
              - IsProduction  
              - ReadCapacityUnits: 25
                WriteCapacityUnits: 25
              - !Ref AWS::NoValue
        
        # GSI3: 時系列検索
        - IndexName: GSI3
          KeySchema:
            - AttributeName: GSI3PK
              KeyType: HASH
            - AttributeName: GSI3SK
              KeyType: RANGE
          Projection:
            ProjectionType: KEYS_ONLY
          ProvisionedThroughput:
            !If
              - IsProduction
              - ReadCapacityUnits: 25
                WriteCapacityUnits: 25
              - !Ref AWS::NoValue
      
      # ストリーム設定
      StreamSpecification:
        StreamViewType: NEW_AND_OLD_IMAGES
      
      # Point-in-Time Recovery
      PointInTimeRecoverySpecification:
        PointInTimeRecoveryEnabled: true
      
      # 削除保護（本番環境）
      DeletionProtectionEnabled: !If [IsProduction, true, false]
      
      # 暗号化設定
      SSESpecification:
        SSEEnabled: true
        KMSMasterKeyId: !Ref DynamoDBKMSKey
      
      # タグ設定
      Tags:
        - Key: Environment
          Value: !Ref EnvironmentName
        - Key: Project
          Value: !Ref ProjectName
        - Key: DataPattern
          Value: SingleTable
  
  # Auto Scaling設定（本番環境）
  TableReadCapacityScalableTarget:
    Type: AWS::ApplicationAutoScaling::ScalableTarget
    Condition: IsProduction
    Properties:
      MaxCapacity: 1000
      MinCapacity: 50
      ResourceId: !Sub 'table/${MainTable}'
      RoleARN: !GetAtt DynamoDBAutoScalingRole.Arn
      ScalableDimension: dynamodb:table:ReadCapacityUnits
      ServiceNamespace: dynamodb
  
  TableReadScalingPolicy:
    Type: AWS::ApplicationAutoScaling::ScalingPolicy
    Condition: IsProduction
    Properties:
      PolicyName: ReadAutoScalingPolicy
      PolicyType: TargetTrackingScaling
      ScalingTargetId: !Ref TableReadCapacityScalableTarget
      TargetTrackingScalingPolicyConfiguration:
        TargetValue: 70.0
        ScaleInCooldown: 60
        ScaleOutCooldown: 60
        PredefinedMetricSpecification:
          PredefinedMetricType: DynamoDBReadCapacityUtilization
  
  # KMS キー
  DynamoDBKMSKey:
    Type: AWS::KMS::Key
    Properties:
      Description: !Sub 'KMS key for ${ProjectName} DynamoDB encryption'
      KeyPolicy:
        Version: '2012-10-17'
        Statement:
          - Sid: Enable IAM User Permissions
            Effect: Allow
            Principal:
              AWS: !Sub 'arn:aws:iam::${AWS::AccountId}:root'
            Action: 'kms:*'
            Resource: '*'
          - Sid: Allow DynamoDB access
            Effect: Allow
            Principal:
              Service: dynamodb.amazonaws.com
            Action:
              - kms:Decrypt
              - kms:GenerateDataKey
            Resource: '*'
  
  DynamoDBKMSKeyAlias:
    Type: AWS::KMS::Alias
    Properties:
      AliasName: !Sub 'alias/${ProjectName}-${EnvironmentName}-dynamodb'
      TargetKeyId: !Ref DynamoDBKMSKey
  
  # DAX クラスター（オプション）
  DAXCluster:
    Type: AWS::DAX::Cluster
    Condition: EnableDAXCluster
    Properties:
      ClusterName: !Sub '${ProjectName}-${EnvironmentName}-dax'
      Description: 'DynamoDB Accelerator cluster'
      NodeType: dax.t3.small
      ReplicationFactor: 3
      IAMRoleARN: !GetAtt DAXServiceRole.Arn
      SubnetGroupName: !Ref DAXSubnetGroup
      SecurityGroupIds:
        - !Ref DAXSecurityGroup
      SSESpecification:
        SSEEnabled: true
      Tags:
        - Key: Environment
          Value: !Ref EnvironmentName
        - Key: Project
          Value: !Ref ProjectName
  
  DAXSubnetGroup:
    Type: AWS::DAX::SubnetGroup
    Condition: EnableDAXCluster
    Properties:
      SubnetGroupName: !Sub '${ProjectName}-${EnvironmentName}-dax-subnet-group'
      Description: 'Subnet group for DAX cluster'
      SubnetIds:
        - !Ref PrivateSubnet1
        - !Ref PrivateSubnet2
  
  # セキュリティグループ
  DAXSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Condition: EnableDAXCluster
    Properties:
      GroupDescription: 'Security group for DAX cluster'
      VpcId: !Ref VPC
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 8111
          ToPort: 8111
          SourceSecurityGroupId: !Ref ApplicationSecurityGroup
          Description: 'DAX access from application layer'
  
  # IAM ロール
  DynamoDBAutoScalingRole:
    Type: AWS::IAM::Role
    Condition: IsProduction
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: application-autoscaling.amazonaws.com
            Action: sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/service-role/DynamoDBAutoscaleRole
  
  DAXServiceRole:
    Type: AWS::IAM::Role
    Condition: EnableDAXCluster
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: dax.amazonaws.com
            Action: sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess
  
  # CloudWatch アラーム
  ReadThrottleAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: !Sub '${ProjectName}-${EnvironmentName}-read-throttle'
      AlarmDescription: 'DynamoDB read throttle alarm'
      MetricName: ReadThrottledRequests
      Namespace: AWS/DynamoDB
      Statistic: Sum
      Period: 300
      EvaluationPeriods: 2
      Threshold: 5
      ComparisonOperator: GreaterThanThreshold
      Dimensions:
        - Name: TableName
          Value: !Ref MainTable
  
  WriteThrottleAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: !Sub '${ProjectName}-${EnvironmentName}-write-throttle'
      AlarmDescription: 'DynamoDB write throttle alarm'
      MetricName: WriteThrottledRequests
      Namespace: AWS/DynamoDB
      Statistic: Sum
      Period: 300
      EvaluationPeriods: 2
      Threshold: 5
      ComparisonOperator: GreaterThanThreshold
      Dimensions:
        - Name: TableName
          Value: !Ref MainTable

Outputs:
  MainTableName:
    Description: 'Main DynamoDB table name'
    Value: !Ref MainTable
    Export:
      Name: !Sub '${AWS::StackName}-MainTable'
  
  MainTableArn:
    Description: 'Main DynamoDB table ARN'
    Value: !GetAtt MainTable.Arn
    Export:
      Name: !Sub '${AWS::StackName}-MainTableArn'
  
  MainTableStreamArn:
    Description: 'Main DynamoDB table stream ARN'
    Value: !GetAtt MainTable.StreamArn
    Export:
      Name: !Sub '${AWS::StackName}-MainTableStream'
  
  DAXClusterEndpoint:
    Condition: EnableDAXCluster
    Description: 'DAX cluster endpoint'
    Value: !GetAtt DAXCluster.ClusterDiscoveryEndpoint
    Export:
      Name: !Sub '${AWS::StackName}-DAXEndpoint'
```

### ステップ2: データアクセス層の実装

1. **DynamoDB データアクセスクラス**
```javascript
// src/database/dynamodb-client.js
const AWS = require('aws-sdk');
const { v4: uuidv4 } = require('uuid');

class DynamoDBClient {
    constructor(options = {}) {
        // DAX設定対応
        if (options.daxEndpoint) {
            const AmazonDaxClient = require('amazon-dax-client');
            this.daxClient = new AmazonDaxClient({
                endpoints: [options.daxEndpoint],
                region: options.region || 'ap-northeast-1'
            });
            this.client = this.daxClient;
        } else {
            this.client = new AWS.DynamoDB.DocumentClient({
                region: options.region || 'ap-northeast-1'
            });
        }
        
        this.tableName = options.tableName || process.env.DYNAMODB_TABLE_NAME;
    }
    
    /**
     * 単一アイテム取得
     */
    async getItem(pk, sk) {
        const params = {
            TableName: this.tableName,
            Key: { PK: pk, SK: sk }
        };
        
        try {
            const result = await this.client.get(params).promise();
            return result.Item;
        } catch (error) {
            console.error('Error getting item:', error);
            throw error;
        }
    }
    
    /**
     * アイテム作成・更新
     */
    async putItem(item) {
        const timestamp = new Date().toISOString();
        const itemWithMetadata = {
            ...item,
            createdAt: item.createdAt || timestamp,
            updatedAt: timestamp,
            ttl: item.ttl || Math.floor(Date.now() / 1000) + (365 * 24 * 60 * 60) // 1年後
        };
        
        const params = {
            TableName: this.tableName,
            Item: itemWithMetadata,
            ConditionExpression: 'attribute_not_exists(PK) AND attribute_not_exists(SK)'
        };
        
        try {
            await this.client.put(params).promise();
            return itemWithMetadata;
        } catch (error) {
            console.error('Error putting item:', error);
            throw error;
        }
    }
    
    /**
     * アイテム更新
     */
    async updateItem(pk, sk, updateData, conditions = {}) {
        // 動的UPDATE式生成
        const updateExpression = [];
        const expressionAttributeNames = {};
        const expressionAttributeValues = {};
        
        Object.keys(updateData).forEach(key => {
            updateExpression.push(`#${key} = :${key}`);
            expressionAttributeNames[`#${key}`] = key;
            expressionAttributeValues[`:${key}`] = updateData[key];
        });
        
        // updatedAt自動設定
        updateExpression.push('#updatedAt = :updatedAt');
        expressionAttributeNames['#updatedAt'] = 'updatedAt';
        expressionAttributeValues[':updatedAt'] = new Date().toISOString();
        
        const params = {
            TableName: this.tableName,
            Key: { PK: pk, SK: sk },
            UpdateExpression: `SET ${updateExpression.join(', ')}`,
            ExpressionAttributeNames: expressionAttributeNames,
            ExpressionAttributeValues: expressionAttributeValues,
            ConditionExpression: conditions.conditionExpression,
            ReturnValues: 'ALL_NEW'
        };
        
        try {
            const result = await this.client.update(params).promise();
            return result.Attributes;
        } catch (error) {
            console.error('Error updating item:', error);
            throw error;
        }
    }
    
    /**
     * クエリ実行（プライマリキー）
     */
    async query(pk, options = {}) {
        const params = {
            TableName: this.tableName,
            KeyConditionExpression: 'PK = :pk',
            ExpressionAttributeValues: { ':pk': pk }
        };
        
        // ソートキー条件追加
        if (options.skCondition) {
            params.KeyConditionExpression += ` AND ${options.skCondition.expression}`;
            Object.assign(params.ExpressionAttributeValues, options.skCondition.values);
        }
        
        // フィルタ条件
        if (options.filterExpression) {
            params.FilterExpression = options.filterExpression;
        }
        
        // ページネーション
        if (options.limit) {
            params.Limit = options.limit;
        }
        if (options.exclusiveStartKey) {
            params.ExclusiveStartKey = options.exclusiveStartKey;
        }
        
        // 逆順ソート
        if (options.scanIndexForward !== undefined) {
            params.ScanIndexForward = options.scanIndexForward;
        }
        
        try {
            const result = await this.client.query(params).promise();
            return {
                items: result.Items,
                lastEvaluatedKey: result.LastEvaluatedKey,
                count: result.Count,
                scannedCount: result.ScannedCount
            };
        } catch (error) {
            console.error('Error querying items:', error);
            throw error;
        }
    }
    
    /**
     * GSI クエリ実行
     */
    async queryGSI(indexName, gsiPK, options = {}) {
        const params = {
            TableName: this.tableName,
            IndexName: indexName,
            KeyConditionExpression: `${indexName}PK = :gsiPk`,
            ExpressionAttributeValues: { ':gsiPk': gsiPK }
        };
        
        // GSI ソートキー条件
        if (options.gsiSkCondition) {
            params.KeyConditionExpression += ` AND ${options.gsiSkCondition.expression}`;
            Object.assign(params.ExpressionAttributeValues, options.gsiSkCondition.values);
        }
        
        // その他オプション適用
        if (options.filterExpression) params.FilterExpression = options.filterExpression;
        if (options.limit) params.Limit = options.limit;
        if (options.exclusiveStartKey) params.ExclusiveStartKey = options.exclusiveStartKey;
        if (options.scanIndexForward !== undefined) params.ScanIndexForward = options.scanIndexForward;
        
        try {
            const result = await this.client.query(params).promise();
            return {
                items: result.Items,
                lastEvaluatedKey: result.LastEvaluatedKey,
                count: result.Count,
                scannedCount: result.ScannedCount
            };
        } catch (error) {
            console.error('Error querying GSI:', error);
            throw error;
        }
    }
    
    /**
     * バッチ書き込み
     */
    async batchWrite(items, deleteKeys = []) {
        const putRequests = items.map(item => ({
            PutRequest: { Item: item }
        }));
        
        const deleteRequests = deleteKeys.map(key => ({
            DeleteRequest: { Key: key }
        }));
        
        const requests = [...putRequests, ...deleteRequests];
        const batches = [];
        
        // 25アイテムずつバッチ処理
        for (let i = 0; i < requests.length; i += 25) {
            batches.push(requests.slice(i, i + 25));
        }
        
        const results = [];
        
        for (const batch of batches) {
            const params = {
                RequestItems: {
                    [this.tableName]: batch
                }
            };
            
            try {
                const result = await this.client.batchWrite(params).promise();
                results.push(result);
                
                // 未処理アイテムの再試行
                if (result.UnprocessedItems && Object.keys(result.UnprocessedItems).length > 0) {
                    console.warn('Unprocessed items detected, retrying...');
                    await this._retryUnprocessedItems(result.UnprocessedItems);
                }
            } catch (error) {
                console.error('Error in batch write:', error);
                throw error;
            }
        }
        
        return results;
    }
    
    /**
     * トランザクション書き込み
     */
    async transactWrite(transactItems) {
        const params = {
            TransactItems: transactItems
        };
        
        try {
            await this.client.transactWrite(params).promise();
            return true;
        } catch (error) {
            console.error('Error in transaction write:', error);
            throw error;
        }
    }
    
    /**
     * アイテム削除
     */
    async deleteItem(pk, sk, conditions = {}) {
        const params = {
            TableName: this.tableName,
            Key: { PK: pk, SK: sk },
            ConditionExpression: conditions.conditionExpression,
            ReturnValues: 'ALL_OLD'
        };
        
        try {
            const result = await this.client.delete(params).promise();
            return result.Attributes;
        } catch (error) {
            console.error('Error deleting item:', error);
            throw error;
        }
    }
    
    /**
     * 未処理アイテム再試行（内部メソッド）
     */
    async _retryUnprocessedItems(unprocessedItems, retryCount = 0) {
        if (retryCount >= 3) {
            throw new Error('Max retry attempts reached for unprocessed items');
        }
        
        // 指数バックオフ
        const delay = Math.pow(2, retryCount) * 100;
        await new Promise(resolve => setTimeout(resolve, delay));
        
        const params = { RequestItems: unprocessedItems };
        
        try {
            const result = await this.client.batchWrite(params).promise();
            
            if (result.UnprocessedItems && Object.keys(result.UnprocessedItems).length > 0) {
                await this._retryUnprocessedItems(result.UnprocessedItems, retryCount + 1);
            }
        } catch (error) {
            console.error(`Retry ${retryCount + 1} failed:`, error);
            throw error;
        }
    }
}

module.exports = DynamoDBClient;
```

2. **エンティティ別データアクセスオブジェクト**
```javascript
// src/dao/user-dao.js
const DynamoDBClient = require('../database/dynamodb-client');
const { v4: uuidv4 } = require('uuid');

class UserDAO extends DynamoDBClient {
    constructor(options) {
        super(options);
    }
    
    /**
     * ユーザー作成
     */
    async createUser(userData) {
        const userId = uuidv4();
        const timestamp = new Date().toISOString();
        
        const userItem = {
            PK: `USER#${userId}`,
            SK: 'PROFILE',
            entityType: 'USER',
            userId: userId,
            email: userData.email,
            username: userData.username,
            firstName: userData.firstName,
            lastName: userData.lastName,
            status: 'ACTIVE',
            emailVerified: false,
            
            // GSI キー設定
            GSI1PK: `EMAIL#${userData.email}`,
            GSI1SK: `USER#${userId}`,
            GSI2PK: `STATUS#ACTIVE`,
            GSI2SK: `USER#${timestamp}`,
            
            createdAt: timestamp,
            updatedAt: timestamp
        };
        
        try {
            await this.putItem(userItem);
            return { userId, ...userItem };
        } catch (error) {
            if (error.code === 'ConditionalCheckFailedException') {
                throw new Error('User already exists');
            }
            throw error;
        }
    }
    
    /**
     * ユーザー取得（ID）
     */
    async getUserById(userId) {
        return await this.getItem(`USER#${userId}`, 'PROFILE');
    }
    
    /**
     * ユーザー取得（メール）
     */
    async getUserByEmail(email) {
        const result = await this.queryGSI('GSI1', `EMAIL#${email}`);
        return result.items.length > 0 ? result.items[0] : null;
    }
    
    /**
     * ユーザー一覧取得（ステータス別）
     */
    async getUsersByStatus(status, options = {}) {
        return await this.queryGSI('GSI2', `STATUS#${status}`, {
            limit: options.limit,
            exclusiveStartKey: options.exclusiveStartKey,
            scanIndexForward: false // 新しい順
        });
    }
    
    /**
     * ユーザー更新
     */
    async updateUser(userId, updateData) {
        const allowedFields = ['firstName', 'lastName', 'phoneNumber', 'profileImageUrl'];
        const filteredData = {};
        
        allowedFields.forEach(field => {
            if (updateData[field] !== undefined) {
                filteredData[field] = updateData[field];
            }
        });
        
        if (Object.keys(filteredData).length === 0) {
            throw new Error('No valid fields to update');
        }
        
        return await this.updateItem(
            `USER#${userId}`, 
            'PROFILE', 
            filteredData,
            { conditionExpression: 'attribute_exists(PK)' }
        );
    }
    
    /**
     * ユーザーの注文履歴取得
     */
    async getUserOrders(userId, options = {}) {
        return await this.query(`USER#${userId}`, {
            skCondition: {
                expression: 'begins_with(SK, :skPrefix)',
                values: { ':skPrefix': 'ORDER#' }
            },
            limit: options.limit,
            exclusiveStartKey: options.exclusiveStartKey,
            scanIndexForward: false
        });
    }
}

// src/dao/product-dao.js
class ProductDAO extends DynamoDBClient {
    constructor(options) {
        super(options);
    }
    
    /**
     * 商品作成
     */
    async createProduct(productData) {
        const productId = uuidv4();
        const timestamp = new Date().toISOString();
        
        const productItem = {
            PK: `PRODUCT#${productId}`,
            SK: 'METADATA',
            entityType: 'PRODUCT',
            productId: productId,
            name: productData.name,
            description: productData.description,
            price: productData.price,
            categoryId: productData.categoryId,
            inventory: productData.inventory || 0,
            status: 'ACTIVE',
            
            // GSI キー設定
            GSI1PK: `CATEGORY#${productData.categoryId}`,
            GSI1SK: `PRODUCT#${timestamp}`,
            GSI2PK: `STATUS#ACTIVE`,
            GSI2SK: `PRODUCT#${productId}`,
            
            createdAt: timestamp,
            updatedAt: timestamp
        };
        
        await this.putItem(productItem);
        return productItem;
    }
    
    /**
     * 商品取得
     */
    async getProduct(productId) {
        return await this.getItem(`PRODUCT#${productId}`, 'METADATA');
    }
    
    /**
     * カテゴリ別商品一覧
     */
    async getProductsByCategory(categoryId, options = {}) {
        return await this.queryGSI('GSI1', `CATEGORY#${categoryId}`, {
            limit: options.limit,
            exclusiveStartKey: options.exclusiveStartKey,
            scanIndexForward: false
        });
    }
    
    /**
     * 商品レビュー追加
     */
    async addProductReview(productId, userId, reviewData) {
        const reviewId = uuidv4();
        const timestamp = new Date().toISOString();
        
        const reviewItem = {
            PK: `PRODUCT#${productId}`,
            SK: `REVIEW#${reviewId}`,
            entityType: 'REVIEW',
            reviewId: reviewId,
            productId: productId,
            userId: userId,
            rating: reviewData.rating,
            comment: reviewData.comment,
            
            // GSI設定（ユーザー別レビュー検索用）
            GSI2PK: `USER#${userId}`,
            GSI2SK: `REVIEW#${reviewId}`,
            
            createdAt: timestamp,
            updatedAt: timestamp
        };
        
        await this.putItem(reviewItem);
        return reviewItem;
    }
    
    /**
     * 商品レビュー一覧取得
     */
    async getProductReviews(productId, options = {}) {
        return await this.query(`PRODUCT#${productId}`, {
            skCondition: {
                expression: 'begins_with(SK, :skPrefix)',
                values: { ':skPrefix': 'REVIEW#' }
            },
            limit: options.limit,
            exclusiveStartKey: options.exclusiveStartKey,
            scanIndexForward: false
        });
    }
}

module.exports = { UserDAO, ProductDAO };
```

### ステップ3: DynamoDB Streams 統合

1. **Streams処理Lambda関数**
```javascript
// src/lambda/dynamodb-stream-processor.js
const AWS = require('aws-sdk');

const sns = new AWS.SNS();
const ses = new AWS.SES();

exports.handler = async (event) => {
    console.log('DynamoDB Streams event:', JSON.stringify(event, null, 2));
    
    const processingPromises = event.Records.map(async (record) => {
        try {
            await processRecord(record);
        } catch (error) {
            console.error('Error processing record:', error);
            // デッドレターキューへの送信または再試行ロジック
            throw error;
        }
    });
    
    await Promise.all(processingPromises);
    
    return {
        statusCode: 200,
        body: JSON.stringify({
            message: `Processed ${event.Records.length} records successfully`,
            timestamp: new Date().toISOString()
        })
    };
};

async function processRecord(record) {
    const { eventName, dynamodb } = record;
    const entityType = dynamodb.NewImage?.entityType?.S;
    
    console.log(`Processing ${eventName} for ${entityType}`);
    
    switch (entityType) {
        case 'USER':
            await processUserEvent(eventName, dynamodb);
            break;
        case 'ORDER':
            await processOrderEvent(eventName, dynamodb);
            break;
        case 'PRODUCT':
            await processProductEvent(eventName, dynamodb);
            break;
        case 'REVIEW':
            await processReviewEvent(eventName, dynamodb);
            break;
        default:
            console.log(`Unknown entity type: ${entityType}`);
    }
}

async function processUserEvent(eventName, dynamodb) {
    if (eventName === 'INSERT') {
        const newUser = unmarshallDynamoDBItem(dynamodb.NewImage);
        
        // ウェルカムメール送信
        await sendWelcomeEmail(newUser);
        
        // ユーザー作成イベントをSNSに発行
        await publishEvent('user-created', {
            userId: newUser.userId,
            email: newUser.email,
            timestamp: new Date().toISOString()
        });
    }
}

async function processOrderEvent(eventName, dynamodb) {
    const orderData = unmarshallDynamoDBItem(dynamodb.NewImage);
    
    switch (eventName) {
        case 'INSERT':
            // 注文確認メール
            await sendOrderConfirmationEmail(orderData);
            
            // 在庫更新処理
            await updateInventory(orderData);
            
            // 注文イベント発行
            await publishEvent('order-created', {
                orderId: orderData.orderId,
                userId: orderData.userId,
                amount: orderData.totalAmount,
                timestamp: new Date().toISOString()
            });
            break;
            
        case 'MODIFY':
            const oldOrder = unmarshallDynamoDBItem(dynamodb.OldImage);
            
            // ステータス変更検知
            if (oldOrder.status !== orderData.status) {
                await handleOrderStatusChange(orderData, oldOrder.status);
            }
            break;
    }
}

async function processReviewEvent(eventName, dynamodb) {
    if (eventName === 'INSERT') {
        const review = unmarshallDynamoDBItem(dynamodb.NewImage);
        
        // 商品評価の再計算
        await updateProductRating(review.productId);
        
        // レビュー投稿イベント発行
        await publishEvent('review-created', {
            reviewId: review.reviewId,
            productId: review.productId,
            userId: review.userId,
            rating: review.rating,
            timestamp: new Date().toISOString()
        });
    }
}

async function sendWelcomeEmail(user) {
    const params = {
        Source: process.env.FROM_EMAIL,
        Destination: {
            ToAddresses: [user.email]
        },
        Message: {
            Subject: {
                Data: 'ご登録ありがとうございます',
                Charset: 'UTF-8'
            },
            Body: {
                Html: {
                    Data: `
                        <h1>ようこそ、${user.firstName || user.username}さん！</h1>
                        <p>アカウント登録が完了しました。</p>
                        <p>ユーザーID: ${user.userId}</p>
                        <p>登録日時: ${user.createdAt}</p>
                    `,
                    Charset: 'UTF-8'
                }
            }
        }
    };
    
    try {
        await ses.sendEmail(params).promise();
        console.log(`Welcome email sent to ${user.email}`);
    } catch (error) {
        console.error('Error sending welcome email:', error);
        throw error;
    }
}

async function publishEvent(eventType, payload) {
    const message = {
        eventType: eventType,
        timestamp: new Date().toISOString(),
        payload: payload
    };
    
    const params = {
        TopicArn: process.env.SNS_TOPIC_ARN,
        Message: JSON.stringify(message),
        MessageAttributes: {
            eventType: {
                DataType: 'String',
                StringValue: eventType
            }
        }
    };
    
    try {
        await sns.publish(params).promise();
        console.log(`Event published: ${eventType}`);
    } catch (error) {
        console.error('Error publishing event:', error);
        throw error;
    }
}

function unmarshallDynamoDBItem(item) {
    const AWS = require('aws-sdk');
    return AWS.DynamoDB.Converter.unmarshall(item);
}

async function updateInventory(orderData) {
    // 在庫更新ロジック実装
    console.log('Updating inventory for order:', orderData.orderId);
}

async function updateProductRating(productId) {
    // 商品評価再計算ロジック実装
    console.log('Updating product rating for:', productId);
}

async function handleOrderStatusChange(orderData, oldStatus) {
    console.log(`Order ${orderData.orderId} status changed from ${oldStatus} to ${orderData.status}`);
}
```

### ステップ4: デプロイとテスト

1. **デプロイスクリプト**
```bash
#!/bin/bash
# scripts/deploy-dynamodb.sh

set -e

PROJECT_NAME="dynamodb-demo"
ENVIRONMENT="dev"
REGION="ap-northeast-1"

echo "Deploying DynamoDB infrastructure..."

# DynamoDBスタックデプロイ
aws cloudformation deploy \
  --template-file cloudformation/dynamodb-tables.yaml \
  --stack-name ${PROJECT_NAME}-${ENVIRONMENT}-dynamodb \
  --parameter-overrides \
    ProjectName=${PROJECT_NAME} \
    EnvironmentName=${ENVIRONMENT} \
    EnableDAX=false \
  --capabilities CAPABILITY_IAM \
  --region ${REGION}

# テーブル名取得
TABLE_NAME=$(aws cloudformation describe-stacks \
  --stack-name ${PROJECT_NAME}-${ENVIRONMENT}-dynamodb \
  --query 'Stacks[0].Outputs[?OutputKey==`MainTableName`].OutputValue' \
  --output text)

echo "DynamoDB table created: $TABLE_NAME"

# サンプルデータ投入
echo "Inserting sample data..."
node scripts/insert-sample-data.js --table-name "$TABLE_NAME"

echo "Deployment completed successfully!"
```

2. **サンプルデータ投入スクリプト**
```javascript
// scripts/insert-sample-data.js
const DynamoDBClient = require('../src/database/dynamodb-client');
const { UserDAO, ProductDAO } = require('../src/dao');

async function insertSampleData() {
    const dbClient = new DynamoDBClient({ 
        tableName: process.argv.includes('--table-name') 
            ? process.argv[process.argv.indexOf('--table-name') + 1]
            : process.env.DYNAMODB_TABLE_NAME 
    });
    
    const userDAO = new UserDAO({ tableName: dbClient.tableName });
    const productDAO = new ProductDAO({ tableName: dbClient.tableName });
    
    try {
        // サンプルユーザー作成
        console.log('Creating sample users...');
        const users = await Promise.all([
            userDAO.createUser({
                email: 'user1@example.com',
                username: 'user1',
                firstName: '太郎',
                lastName: '田中'
            }),
            userDAO.createUser({
                email: 'user2@example.com', 
                username: 'user2',
                firstName: '花子',
                lastName: '佐藤'
            })
        ]);
        
        console.log(`Created ${users.length} users`);
        
        // サンプル商品作成
        console.log('Creating sample products...');
        const products = await Promise.all([
            productDAO.createProduct({
                name: 'ノートパソコン',
                description: '高性能ノートパソコン',
                price: 120000,
                categoryId: 'electronics',
                inventory: 50
            }),
            productDAO.createProduct({
                name: 'スマートフォン',
                description: '最新スマートフォン',
                price: 80000,
                categoryId: 'electronics', 
                inventory: 100
            })
        ]);
        
        console.log(`Created ${products.length} products`);
        
        // サンプルレビュー作成
        console.log('Creating sample reviews...');
        await Promise.all([
            productDAO.addProductReview(products[0].productId, users[0].userId, {
                rating: 5,
                comment: '素晴らしい商品です！'
            }),
            productDAO.addProductReview(products[1].productId, users[1].userId, {
                rating: 4,
                comment: 'とても満足しています。'
            })
        ]);
        
        console.log('Sample data insertion completed!');
        
    } catch (error) {
        console.error('Error inserting sample data:', error);
        process.exit(1);
    }
}

insertSampleData();
```

## 検証方法

### 1. 基本CRUD操作テスト
```javascript
// test/dynamodb-operations.test.js
const { UserDAO, ProductDAO } = require('../src/dao');

async function testCRUDOperations() {
    const userDAO = new UserDAO({ tableName: process.env.DYNAMODB_TABLE_NAME });
    
    // ユーザー作成テスト
    const user = await userDAO.createUser({
        email: 'test@example.com',
        username: 'testuser',
        firstName: 'Test',
        lastName: 'User'
    });
    console.log('Created user:', user);
    
    // ユーザー取得テスト
    const retrievedUser = await userDAO.getUserById(user.userId);
    console.log('Retrieved user:', retrievedUser);
    
    // メールでユーザー検索テスト
    const userByEmail = await userDAO.getUserByEmail('test@example.com');
    console.log('User by email:', userByEmail);
    
    // ユーザー更新テスト
    const updatedUser = await userDAO.updateUser(user.userId, {
        firstName: 'Updated',
        phoneNumber: '+81-90-1234-5678'
    });
    console.log('Updated user:', updatedUser);
}

testCRUDOperations().catch(console.error);
```

### 2. パフォーマンステスト
```bash
# CloudWatchメトリクス確認
aws cloudwatch get-metric-statistics \
  --namespace AWS/DynamoDB \
  --metric-name ConsumedReadCapacityUnits \
  --dimensions Name=TableName,Value=dynamodb-demo-dev-main-table \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-01T23:59:59Z \
  --period 3600 \
  --statistics Sum
```

### 3. GSI クエリテスト
```javascript
// GSI活用テスト
async function testGSIQueries() {
    const productDAO = new ProductDAO({ tableName: process.env.DYNAMODB_TABLE_NAME });
    
    // カテゴリ別商品検索
    const electronicsProducts = await productDAO.getProductsByCategory('electronics', {
        limit: 10
    });
    console.log('Electronics products:', electronicsProducts);
    
    // ユーザー別レビュー検索
    const userReviews = await productDAO.queryGSI('GSI2', 'USER#user-id-here', {
        gsiSkCondition: {
            expression: 'begins_with(GSI2SK, :prefix)',
            values: { ':prefix': 'REVIEW#' }
        }
    });
    console.log('User reviews:', userReviews);
}
```

## トラブルシューティング

### よくある問題と解決策

#### 1. ホットパーティション
**症状**: 特定のパーティションに負荷集中
**解決策**:
- パーティションキー設計の見直し
- ランダム性の追加（タイムスタンプサフィックス等）
- GSI の活用

#### 2. GSI スロットリング
**症状**: GSI での読み込み・書き込み制限
**解決策**:
```javascript
// 指数バックオフによるリトライ実装
async function queryWithRetry(params, maxRetries = 3) {
    for (let attempt = 0; attempt < maxRetries; attempt++) {
        try {
            return await this.client.query(params).promise();
        } catch (error) {
            if (error.code === 'ProvisionedThroughputExceededException') {
                const delay = Math.pow(2, attempt) * 100 + Math.random() * 100;
                await new Promise(resolve => setTimeout(resolve, delay));
                continue;
            }
            throw error;
        }
    }
    throw new Error('Max retry attempts reached');
}
```

#### 3. アイテムサイズ制限
**症状**: 400KB制限エラー
**解決策**:
- データの正規化
- S3への大容量データ分離
- 圧縮の活用

## 学習リソース

### AWS公式ドキュメント
- [Amazon DynamoDB 開発者ガイド](https://docs.aws.amazon.com/dynamodb/latest/developerguide/)
- [DynamoDB ベストプラクティス](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/best-practices.html)
- [DynamoDB Accelerator (DAX)](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/DAX.html)

### 追加学習教材
- [AWS re:Invent DynamoDB Sessions](https://www.youtube.com/playlist?list=PLhr1KZpdzukdeX8mQ2qO73bg6UKQHYsHb)
- [The DynamoDB Book](https://www.dynamodbbook.com/)

## セキュリティとコストの考慮事項

### セキュリティベストプラクティス
1. **IAM最小権限**: 必要最小限のアクセス許可
2. **暗号化**: 保存時・転送時暗号化
3. **VPCエンドポイント**: プライベート通信経路
4. **監査ログ**: CloudTrail連携

### コスト最適化
1. **オンデマンド vs プロビジョニング**: ワークロードパターンに応じた選択
2. **GSI 最適化**: 必要最小限のGSI作成
3. **TTL活用**: 自動データ削除
4. **ストレージクラス**: IA（Infrequent Access）の活用

### AWS Well-Architectedフレームワークとの関連
- **運用性の柱**: CloudWatch監視・X-Rayトレーシング
- **セキュリティの柱**: IAM・VPCエンドポイント・暗号化
- **信頼性の柱**: Multi-AZ・バックアップ・エラーハンドリング
- **パフォーマンス効率の柱**: 適切なキー設計・GSI活用・DAX
- **コスト最適化の柱**: オンデマンド課金・TTL・適切なプロビジョニング

## 次のステップ

### 推奨される学習パス
1. **3.1.1 ユーザー管理システム**: 認証機能との統合
2. **3.1.2 データ操作API**: 高度なクエリパターン
3. **3.2.2 リアルタイム更新**: WebSocketとStreams連携
4. **4.1.1 Kinesisストリーミング**: 大規模データ処理

### 発展的な機能
1. **DynamoDB Global Tables**: マルチリージョン対応
2. **PartiQL**: SQL風クエリ言語
3. **DynamoDB Transactions**: ACID対応処理
4. **Export to S3**: データ分析基盤連携

### 実践プロジェクトのアイデア
1. **リアルタイムチャット**: WebSocket + Streams
2. **IoTデータ収集**: 大量時系列データ処理
3. **ゲームリーダーボード**: 高性能ランキング
4. **SaaSマルチテナント**: テナント分離設計