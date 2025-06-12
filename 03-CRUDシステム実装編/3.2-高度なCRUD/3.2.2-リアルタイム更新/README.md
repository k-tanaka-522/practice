# 3.2.2 リアルタイム更新

## 学習目標

このセクションでは、WebSocketとAWS API Gatewayを活用したリアルタイム通信システムを構築し、チャット・ライブ更新・コラボレーション機能など、動的でインタラクティブなWebアプリケーションの実装方法を習得します。

### 習得できるスキル
- WebSocket API Gateway によるリアルタイム通信
- Lambda での WebSocket 接続管理とメッセージ配信
- DynamoDB によるWebSocket接続情報管理
- イベント駆動アーキテクチャの実装
- フロントエンドでのWebSocket統合
- リアルタイムデータ同期とコンフリクト解決

## 前提知識

### 必須の知識
- WebSocket プロトコルの基本概念
- Lambda 関数の開発（1.2.3セクション完了）
- DynamoDB の基本操作（2.3.2セクション完了）
- JavaScript の非同期処理とPromise

### あると望ましい知識
- リアルタイム通信プロトコルの理解
- イベント駆動設計パターン
- フロントエンド状態管理（Redux等）
- WebRTC の基本概念

## アーキテクチャ概要

### WebSocket リアルタイム通信アーキテクチャ

```
                    ┌─────────────────────┐
                    │   Client Apps       │
                    │ (Web/Mobile)        │
                    │                     │
                    │ ┌─────────────────┐ │
                    │ │  WebSocket      │ │
                    │ │  Client         │ │
                    │ │  (Auto-reconnect│ │
                    │ │   & Heartbeat)  │ │
                    │ └─────────────────┘ │
                    └─────────┬───────────┘
                              │ WSS Connection
                    ┌─────────┼───────────┐
                    │         │           │
                    ▼         ▼           ▼
          ┌─────────────────┐ ┌──────────┐ ┌─────────────────┐
          │   CloudFront    │ │    WAF   │ │   Route 53      │
          │ (Static Assets) │ │(DDoS     │ │  (DNS Routing)  │
          └─────────────────┘ │Protect)  │ └─────────────────┘
                              └──────────┘
                                   │
                                   ▼
          ┌─────────────────────────────────────────────────────────┐
          │            API Gateway (WebSocket API)                  │
          │                                                         │
          │  ┌─────────────────────────────────────────────────┐   │
          │  │              Route Management               │   │
          │  │                                                  │   │
          │  │  ┌─────────────┐  ┌─────────────┐  ┌──────────┐ │   │
          │  │  │   $connect  │  │ $disconnect │  │  Custom  │ │   │
          │  │  │   Route     │  │   Route     │  │  Routes  │ │   │
          │  │  │             │  │             │  │          │ │   │
          │  │  │ ┌─────────┐ │  │ ┌─────────┐ │  │┌────────┐│ │   │
          │  │  │ │Auth     │ │  │ │Cleanup  │ │  ││Message ││ │   │
          │  │  │ │Check    │ │  │ │Handler  │ │  ││Handler ││ │   │
          │  │  │ └─────────┘ │  │ └─────────┘ │  │└────────┘│ │   │
          │  │  └─────────────┘  └─────────────┘  └──────────┘ │   │
          │  └─────────────────────────────────────────────────┘   │
          └─────────────────────────────────────────────────────────┘
                                   │
                                   ▼
          ┌─────────────────────────────────────────────────────────┐
          │               Lambda Functions                          │
          │              (WebSocket Handlers)                      │
          │                                                         │
          │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │
          │  │Connection   │  │ Message     │  │Broadcast    │   │
          │  │Manager      │  │ Processor   │  │Service      │   │
          │  │             │  │             │  │             │   │
          │  │┌──────────┐ │  │┌──────────┐ │  │┌──────────┐ │   │
          │  ││Connect   │ │  ││Route     │ │  ││Room      │ │   │
          │  ││Disconnect│ │  ││Message   │ │  ││Broadcast │ │   │
          │  ││Authorize │ │  ││Validate  │ │  ││User      │ │   │
          │  │└──────────┘ │  │└──────────┘ │  │└──────────┘ │   │
          │  └─────────────┘  └─────────────┘  └─────────────┘   │
          └─────────────────────────────────────────────────────────┘
                                   │
                    ┌──────────────┼──────────────┐
                    │              │              │
                    ▼              ▼              ▼
          ┌─────────────────┐ ┌──────────┐ ┌─────────────────┐
          │   DynamoDB      │ │ElastiCache│ │   EventBridge   │
          │ (Connections)   │ │(Session   │ │(Event Routing)  │
          │                 │ │ Cache)    │ │                 │
          │ ┌─────────────┐ │ │┌────────┐ │ │ ┌─────────────┐ │
          │ │WebSocket    │ │ ││Active  │ │ │ │   Rules     │ │
          │ │Connection   │ │ ││Sessions│ │ │ │   Targets   │ │
          │ │Registry     │ │ │└────────┘ │ │ │   Patterns  │ │
          │ │             │ │ │          │ │ │ └─────────────┘ │
          │ │ ┌─────────┐ │ │ │┌────────┐ │ │ └─────────────────┘
          │ │ │Room     │ │ │ ││Message │ │ │ 
          │ │ │Members  │ │ │ ││Queue   │ │ │ 
          │ │ │Presence │ │ │ │└────────┘ │ │ 
          │ │ └─────────┘ │ │ └──────────┘ │ 
          │ └─────────────┘ │              │ 
          └─────────────────┘              │ 
                    │                      │ 
                    ▼                      ▼ 
          ┌─────────────────────────────────────────────────────────┐
          │               Streaming & Analytics                     │
          │                                                         │
          │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │
          │  │   Kinesis   │  │CloudWatch   │  │   S3 Data   │   │
          │  │   Streams   │  │   Metrics   │  │   Archive   │   │
          │  │             │  │             │  │             │   │
          │  │┌──────────┐ │  │┌──────────┐ │  │┌──────────┐ │   │
          │  ││Message   │ │  ││Connection│ │  ││Chat      │ │   │
          │  ││Analytics │ │  ││Stats     │ │  ││History   │ │   │
          │  ││Real-time │ │  ││Alarms    │ │  ││Backup    │ │   │
          │  │└──────────┘ │  │└──────────┘ │  │└──────────┘ │   │
          │  └─────────────┘  └─────────────┘  └─────────────┘   │
          └─────────────────────────────────────────────────────────┘
```

### 主要コンポーネント
- **WebSocket API Gateway**: リアルタイム双方向通信エンドポイント
- **Lambda Functions**: 接続管理・メッセージ処理・配信ロジック
- **DynamoDB**: WebSocket接続情報とセッション管理
- **ElastiCache**: 高速セッションキャッシュ
- **EventBridge**: イベント駆動ルーティング
- **Kinesis**: リアルタイムメッセージ分析

## ハンズオン手順

### ステップ1: WebSocket API Gateway の構築

1. **CloudFormation WebSocket インフラ**
```yaml
# cloudformation/websocket-infrastructure.yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Real-time WebSocket communication infrastructure'

Parameters:
  ProjectName:
    Type: String
    Default: 'realtime-app'
  
  EnvironmentName:
    Type: String
    Default: 'dev'
    AllowedValues: [dev, staging, prod]
  
  EnableElastiCache:
    Type: String
    Default: 'false'
    AllowedValues: ['true', 'false']
    Description: 'Enable ElastiCache for session management'

Conditions:
  IsProduction: !Equals [!Ref EnvironmentName, 'prod']
  EnableCache: !Equals [!Ref EnableElastiCache, 'true']

Resources:
  # WebSocket API Gateway
  WebSocketApi:
    Type: AWS::ApiGatewayV2::Api
    Properties:
      Name: !Sub '${ProjectName}-${EnvironmentName}-websocket-api'
      Description: 'WebSocket API for real-time communication'
      ProtocolType: WEBSOCKET
      RouteSelectionExpression: '$request.body.action'
      Tags:
        Environment: !Ref EnvironmentName
        Project: !Ref ProjectName

  # Lambda Functions
  ConnectionHandlerFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: !Sub '${ProjectName}-${EnvironmentName}-connection-handler'
      Runtime: nodejs18.x
      Handler: connection-handler.handler
      Role: !GetAtt LambdaExecutionRole.Arn
      Code:
        S3Bucket: !Ref ArtifactsBucket
        S3Key: 'lambda/connection-handler.zip'
      Environment:
        Variables:
          CONNECTIONS_TABLE: !Ref ConnectionsTable
          ROOMS_TABLE: !Ref RoomsTable
          ELASTICACHE_ENDPOINT: !If [EnableCache, !GetAtt ElastiCacheCluster.RedisEndpoint.Address, '']
          API_GATEWAY_ENDPOINT: !Sub 'https://${WebSocketApi}.execute-api.${AWS::Region}.amazonaws.com/${EnvironmentName}'
      Timeout: 30
      MemorySize: 512
      DeadLetterQueue:
        TargetArn: !GetAtt DeadLetterQueue.Arn
      TracingConfig:
        Mode: Active

  MessageHandlerFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: !Sub '${ProjectName}-${EnvironmentName}-message-handler'
      Runtime: nodejs18.x
      Handler: message-handler.handler
      Role: !GetAtt LambdaExecutionRole.Arn
      Code:
        S3Bucket: !Ref ArtifactsBucket
        S3Key: 'lambda/message-handler.zip'
      Environment:
        Variables:
          CONNECTIONS_TABLE: !Ref ConnectionsTable
          ROOMS_TABLE: !Ref RoomsTable
          MESSAGES_TABLE: !Ref MessagesTable
          API_GATEWAY_ENDPOINT: !Sub 'https://${WebSocketApi}.execute-api.${AWS::Region}.amazonaws.com/${EnvironmentName}'
          KINESIS_STREAM: !Ref MessageAnalyticsStream
      Timeout: 30
      MemorySize: 1024
      ReservedConcurrencyLimit: !If [IsProduction, 100, 10]

  BroadcastFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: !Sub '${ProjectName}-${EnvironmentName}-broadcast'
      Runtime: nodejs18.x
      Handler: broadcast.handler
      Role: !GetAtt LambdaExecutionRole.Arn
      Code:
        S3Bucket: !Ref ArtifactsBucket
        S3Key: 'lambda/broadcast.zip'
      Environment:
        Variables:
          CONNECTIONS_TABLE: !Ref ConnectionsTable
          API_GATEWAY_ENDPOINT: !Sub 'https://${WebSocketApi}.execute-api.${AWS::Region}.amazonaws.com/${EnvironmentName}'
      Timeout: 60
      MemorySize: 1024

  # WebSocket Routes
  ConnectRoute:
    Type: AWS::ApiGatewayV2::Route
    Properties:
      ApiId: !Ref WebSocketApi
      RouteKey: '$connect'
      AuthorizationType: NONE
      Target: !Sub 'integrations/${ConnectIntegration}'

  DisconnectRoute:
    Type: AWS::ApiGatewayV2::Route
    Properties:
      ApiId: !Ref WebSocketApi
      RouteKey: '$disconnect'
      Target: !Sub 'integrations/${DisconnectIntegration}'

  MessageRoute:
    Type: AWS::ApiGatewayV2::Route
    Properties:
      ApiId: !Ref WebSocketApi
      RouteKey: 'message'
      Target: !Sub 'integrations/${MessageIntegration}'

  JoinRoomRoute:
    Type: AWS::ApiGatewayV2::Route
    Properties:
      ApiId: !Ref WebSocketApi
      RouteKey: 'joinRoom'
      Target: !Sub 'integrations/${MessageIntegration}'

  LeaveRoomRoute:
    Type: AWS::ApiGatewayV2::Route
    Properties:
      ApiId: !Ref WebSocketApi
      RouteKey: 'leaveRoom'
      Target: !Sub 'integrations/${MessageIntegration}'

  # Lambda Integrations
  ConnectIntegration:
    Type: AWS::ApiGatewayV2::Integration
    Properties:
      ApiId: !Ref WebSocketApi
      IntegrationType: AWS_PROXY
      IntegrationUri: !Sub 'arn:aws:apigateway:${AWS::Region}:lambda:path/2015-03-31/functions/${ConnectionHandlerFunction.Arn}/invocations'
      
  DisconnectIntegration:
    Type: AWS::ApiGatewayV2::Integration
    Properties:
      ApiId: !Ref WebSocketApi
      IntegrationType: AWS_PROXY
      IntegrationUri: !Sub 'arn:aws:apigateway:${AWS::Region}:lambda:path/2015-03-31/functions/${ConnectionHandlerFunction.Arn}/invocations'
      
  MessageIntegration:
    Type: AWS::ApiGatewayV2::Integration
    Properties:
      ApiId: !Ref WebSocketApi
      IntegrationType: AWS_PROXY
      IntegrationUri: !Sub 'arn:aws:apigateway:${AWS::Region}:lambda:path/2015-03-31/functions/${MessageHandlerFunction.Arn}/invocations'

  # API Gateway Deployment
  WebSocketDeployment:
    Type: AWS::ApiGatewayV2::Deployment
    DependsOn:
      - ConnectRoute
      - DisconnectRoute
      - MessageRoute
      - JoinRoomRoute
      - LeaveRoomRoute
    Properties:
      ApiId: !Ref WebSocketApi

  WebSocketStage:
    Type: AWS::ApiGatewayV2::Stage
    Properties:
      ApiId: !Ref WebSocketApi
      DeploymentId: !Ref WebSocketDeployment
      StageName: !Ref EnvironmentName
      Description: !Sub '${EnvironmentName} stage for WebSocket API'
      DefaultRouteSettings:
        ThrottlingBurstLimit: !If [IsProduction, 5000, 1000]
        ThrottlingRateLimit: !If [IsProduction, 2000, 500]
      AccessLogSettings:
        DestinationArn: !GetAtt WebSocketLogGroup.Arn
        Format: '{"requestId":"$requestId","ip":"$identity.sourceIp","requestTime":"$requestTime","routeKey":"$routeKey","status":"$status"}'

  # DynamoDB Tables
  ConnectionsTable:
    Type: AWS::DynamoDB::Table
    Properties:
      TableName: !Sub '${ProjectName}-${EnvironmentName}-connections'
      BillingMode: PAY_PER_REQUEST
      AttributeDefinitions:
        - AttributeName: connectionId
          AttributeType: S
        - AttributeName: userId
          AttributeType: S
        - AttributeName: roomId
          AttributeType: S
      KeySchema:
        - AttributeName: connectionId
          KeyType: HASH
      GlobalSecondaryIndexes:
        - IndexName: user-connections-index
          KeySchema:
            - AttributeName: userId
              KeyType: HASH
          Projection:
            ProjectionType: ALL
        - IndexName: room-connections-index
          KeySchema:
            - AttributeName: roomId
              KeyType: HASH
          Projection:
            ProjectionType: ALL
      TimeToLiveSpecification:
        AttributeName: ttl
        Enabled: true
      StreamSpecification:
        StreamViewType: NEW_AND_OLD_IMAGES

  RoomsTable:
    Type: AWS::DynamoDB::Table
    Properties:
      TableName: !Sub '${ProjectName}-${EnvironmentName}-rooms'
      BillingMode: PAY_PER_REQUEST
      AttributeDefinitions:
        - AttributeName: roomId
          AttributeType: S
        - AttributeName: ownerId
          AttributeType: S
      KeySchema:
        - AttributeName: roomId
          KeyType: HASH
      GlobalSecondaryIndexes:
        - IndexName: owner-rooms-index
          KeySchema:
            - AttributeName: ownerId
              KeyType: HASH
          Projection:
            ProjectionType: ALL

  MessagesTable:
    Type: AWS::DynamoDB::Table
    Properties:
      TableName: !Sub '${ProjectName}-${EnvironmentName}-messages'
      BillingMode: PAY_PER_REQUEST
      AttributeDefinitions:
        - AttributeName: messageId
          AttributeType: S
        - AttributeName: roomId
          AttributeType: S
        - AttributeName: timestamp
          AttributeType: S
      KeySchema:
        - AttributeName: messageId
          KeyType: HASH
      GlobalSecondaryIndexes:
        - IndexName: room-messages-index
          KeySchema:
            - AttributeName: roomId
              KeyType: HASH
            - AttributeName: timestamp
              KeyType: RANGE
          Projection:
            ProjectionType: ALL
      TimeToLiveSpecification:
        AttributeName: ttl
        Enabled: true

  # Kinesis Stream for Analytics
  MessageAnalyticsStream:
    Type: AWS::Kinesis::Stream
    Properties:
      Name: !Sub '${ProjectName}-${EnvironmentName}-message-analytics'
      ShardCount: !If [IsProduction, 2, 1]
      RetentionPeriodHours: 24
      StreamEncryption:
        EncryptionType: KMS
        KeyId: alias/aws/kinesis
      Tags:
        - Key: Environment
          Value: !Ref EnvironmentName
        - Key: Project
          Value: !Ref ProjectName

  # ElastiCache (Optional)
  ElastiCacheSubnetGroup:
    Type: AWS::ElastiCache::SubnetGroup
    Condition: EnableCache
    Properties:
      Description: 'Subnet group for ElastiCache'
      SubnetIds:
        - !Ref PrivateSubnet1
        - !Ref PrivateSubnet2

  ElastiCacheCluster:
    Type: AWS::ElastiCache::ReplicationGroup
    Condition: EnableCache
    Properties:
      ReplicationGroupDescription: 'Redis cluster for WebSocket sessions'
      NumCacheClusters: 2
      Engine: redis
      CacheNodeType: cache.t3.micro
      SubnetGroupName: !Ref ElastiCacheSubnetGroup
      SecurityGroupIds:
        - !Ref ElastiCacheSecurityGroup
      AtRestEncryptionEnabled: true
      TransitEncryptionEnabled: true

  # Lambda Permissions
  ConnectLambdaPermission:
    Type: AWS::Lambda::Permission
    Properties:
      Action: lambda:InvokeFunction
      FunctionName: !Ref ConnectionHandlerFunction
      Principal: apigateway.amazonaws.com
      SourceArn: !Sub 'arn:aws:execute-api:${AWS::Region}:${AWS::AccountId}:${WebSocketApi}/*/*'

  MessageLambdaPermission:
    Type: AWS::Lambda::Permission
    Properties:
      Action: lambda:InvokeFunction
      FunctionName: !Ref MessageHandlerFunction
      Principal: apigateway.amazonaws.com
      SourceArn: !Sub 'arn:aws:execute-api:${AWS::Region}:${AWS::AccountId}:${WebSocketApi}/*/*'

  # CloudWatch Logs
  WebSocketLogGroup:
    Type: AWS::Logs::LogGroup
    Properties:
      LogGroupName: !Sub '/aws/apigateway/${ProjectName}-${EnvironmentName}-websocket'
      RetentionInDays: !If [IsProduction, 30, 7]

  # IAM Role
  LambdaExecutionRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: lambda.amazonaws.com
            Action: sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
        - arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess
      Policies:
        - PolicyName: DynamoDBAccess
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - dynamodb:GetItem
                  - dynamodb:PutItem
                  - dynamodb:UpdateItem
                  - dynamodb:DeleteItem
                  - dynamodb:Query
                  - dynamodb:Scan
                Resource:
                  - !GetAtt ConnectionsTable.Arn
                  - !Sub '${ConnectionsTable.Arn}/index/*'
                  - !GetAtt RoomsTable.Arn
                  - !Sub '${RoomsTable.Arn}/index/*'
                  - !GetAtt MessagesTable.Arn
                  - !Sub '${MessagesTable.Arn}/index/*'
        - PolicyName: WebSocketApiAccess
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - execute-api:ManageConnections
                Resource: !Sub 'arn:aws:execute-api:${AWS::Region}:${AWS::AccountId}:${WebSocketApi}/*/*'
        - PolicyName: KinesisAccess
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - kinesis:PutRecord
                  - kinesis:PutRecords
                Resource: !GetAtt MessageAnalyticsStream.Arn

Outputs:
  WebSocketApiId:
    Description: 'WebSocket API ID'
    Value: !Ref WebSocketApi
    Export:
      Name: !Sub '${AWS::StackName}-WebSocketApiId'
  
  WebSocketApiEndpoint:
    Description: 'WebSocket API endpoint URL'
    Value: !Sub 'wss://${WebSocketApi}.execute-api.${AWS::Region}.amazonaws.com/${EnvironmentName}'
    Export:
      Name: !Sub '${AWS::StackName}-WebSocketEndpoint'
  
  ConnectionsTableName:
    Description: 'Connections DynamoDB table name'
    Value: !Ref ConnectionsTable
    Export:
      Name: !Sub '${AWS::StackName}-ConnectionsTable'
```

### ステップ2: Lambda関数の実装

1. **接続管理ハンドラー**
```javascript
// src/lambda/connection-handler.js
const AWS = require('aws-sdk');
const jwt = require('jsonwebtoken');

const dynamodb = new AWS.DynamoDB.DocumentClient();
const apigateway = new AWS.ApiGatewayManagementApi();

const CONNECTIONS_TABLE = process.env.CONNECTIONS_TABLE;
const ROOMS_TABLE = process.env.ROOMS_TABLE;
const API_GATEWAY_ENDPOINT = process.env.API_GATEWAY_ENDPOINT;

exports.handler = async (event) => {
    console.log('WebSocket event:', JSON.stringify(event, null, 2));
    
    const { routeKey, connectionId, requestContext } = event;
    const { domainName, stage } = requestContext;
    
    // API Gateway管理APIクライアント設定
    apigateway.config.update({
        endpoint: `https://${domainName}/${stage}`
    });
    
    try {
        switch (routeKey) {
            case '$connect':
                return await handleConnect(event);
            case '$disconnect':
                return await handleDisconnect(event);
            default:
                return { statusCode: 400, body: 'Unknown route' };
        }
    } catch (error) {
        console.error('Connection handler error:', error);
        return { statusCode: 500, body: 'Internal server error' };
    }
};

async function handleConnect(event) {
    const { connectionId, requestContext } = event;
    const queryParams = event.queryStringParameters || {};
    
    try {
        // JWTトークン検証（オプション）
        let userId = null;
        if (queryParams.token) {
            try {
                const decoded = jwt.verify(queryParams.token, process.env.JWT_SECRET);
                userId = decoded.sub;
            } catch (jwtError) {
                console.warn('Invalid JWT token:', jwtError.message);
                return { statusCode: 401, body: 'Unauthorized' };
            }
        }
        
        // 接続情報をDynamoDBに保存
        const timestamp = new Date().toISOString();
        const connectionData = {
            connectionId: connectionId,
            userId: userId,
            connectedAt: timestamp,
            lastActivity: timestamp,
            userAgent: requestContext.identity?.userAgent,
            sourceIp: requestContext.identity?.sourceIp,
            ttl: Math.floor(Date.now() / 1000) + (24 * 60 * 60), // 24時間後に期限切れ
            status: 'connected'
        };
        
        await dynamodb.put({
            TableName: CONNECTIONS_TABLE,
            Item: connectionData
        }).promise();
        
        // 接続成功通知
        await sendToConnection(connectionId, {
            type: 'connection',
            status: 'connected',
            connectionId: connectionId,
            timestamp: timestamp
        });
        
        console.log(`Connection established: ${connectionId}`);
        return { statusCode: 200, body: 'Connected' };
        
    } catch (error) {
        console.error('Connect error:', error);
        return { statusCode: 500, body: 'Connection failed' };
    }
}

async function handleDisconnect(event) {
    const { connectionId } = event;
    
    try {
        // 接続情報取得
        const connectionResult = await dynamodb.get({
            TableName: CONNECTIONS_TABLE,
            Key: { connectionId: connectionId }
        }).promise();
        
        const connection = connectionResult.Item;
        
        if (connection) {
            // ルームから退出処理
            if (connection.roomId) {
                await leaveRoom(connectionId, connection.roomId, connection.userId);
            }
            
            // 接続情報削除
            await dynamodb.delete({
                TableName: CONNECTIONS_TABLE,
                Key: { connectionId: connectionId }
            }).promise();
            
            console.log(`Connection disconnected: ${connectionId}`);
        }
        
        return { statusCode: 200, body: 'Disconnected' };
        
    } catch (error) {
        console.error('Disconnect error:', error);
        return { statusCode: 500, body: 'Disconnection failed' };
    }
}

async function leaveRoom(connectionId, roomId, userId) {
    try {
        // ルーム情報更新
        await dynamodb.update({
            TableName: ROOMS_TABLE,
            Key: { roomId: roomId },
            UpdateExpression: 'DELETE members :connectionId',
            ExpressionAttributeValues: {
                ':connectionId': new Set([connectionId])
            }
        }).promise();
        
        // ルームの他のメンバーに退出通知
        await broadcastToRoom(roomId, {
            type: 'memberLeft',
            roomId: roomId,
            userId: userId,
            connectionId: connectionId,
            timestamp: new Date().toISOString()
        }, connectionId);
        
    } catch (error) {
        console.error('Leave room error:', error);
    }
}

async function sendToConnection(connectionId, message) {
    try {
        await apigateway.postToConnection({
            ConnectionId: connectionId,
            Data: JSON.stringify(message)
        }).promise();
    } catch (error) {
        if (error.statusCode === 410) {
            // 切断された接続の削除
            await dynamodb.delete({
                TableName: CONNECTIONS_TABLE,
                Key: { connectionId: connectionId }
            }).promise();
        }
        throw error;
    }
}

async function broadcastToRoom(roomId, message, excludeConnectionId = null) {
    try {
        // ルームのアクティブな接続を取得
        const connections = await dynamodb.query({
            TableName: CONNECTIONS_TABLE,
            IndexName: 'room-connections-index',
            KeyConditionExpression: 'roomId = :roomId',
            ExpressionAttributeValues: {
                ':roomId': roomId
            }
        }).promise();
        
        const sendPromises = connections.Items
            .filter(conn => conn.connectionId !== excludeConnectionId)
            .map(conn => sendToConnection(conn.connectionId, message));
        
        await Promise.allSettled(sendPromises);
        
    } catch (error) {
        console.error('Broadcast to room error:', error);
    }
}
```

2. **メッセージハンドラー**
```javascript
// src/lambda/message-handler.js
const AWS = require('aws-sdk');
const { v4: uuidv4 } = require('uuid');

const dynamodb = new AWS.DynamoDB.DocumentClient();
const apigateway = new AWS.ApiGatewayManagementApi();
const kinesis = new AWS.Kinesis();

const CONNECTIONS_TABLE = process.env.CONNECTIONS_TABLE;
const ROOMS_TABLE = process.env.ROOMS_TABLE;
const MESSAGES_TABLE = process.env.MESSAGES_TABLE;
const KINESIS_STREAM = process.env.KINESIS_STREAM;

exports.handler = async (event) => {
    const { connectionId, requestContext } = event;
    const { domainName, stage } = requestContext;
    
    // API Gateway管理APIクライアント設定
    apigateway.config.update({
        endpoint: `https://${domainName}/${stage}`
    });
    
    try {
        const message = JSON.parse(event.body);
        const { action } = message;
        
        // 接続情報取得
        const connectionResult = await dynamodb.get({
            TableName: CONNECTIONS_TABLE,
            Key: { connectionId: connectionId }
        }).promise();
        
        if (!connectionResult.Item) {
            return { statusCode: 404, body: 'Connection not found' };
        }
        
        const connection = connectionResult.Item;
        
        // 最終アクティビティ時刻更新
        await updateLastActivity(connectionId);
        
        switch (action) {
            case 'message':
                return await handleMessage(connection, message);
            case 'joinRoom':
                return await handleJoinRoom(connection, message);
            case 'leaveRoom':
                return await handleLeaveRoom(connection, message);
            case 'typing':
                return await handleTyping(connection, message);
            case 'ping':
                return await handlePing(connection);
            default:
                return { statusCode: 400, body: 'Unknown action' };
        }
        
    } catch (error) {
        console.error('Message handler error:', error);
        return { statusCode: 500, body: 'Message processing failed' };
    }
};

async function handleMessage(connection, message) {
    const { roomId, content, messageType = 'text' } = message;
    const { connectionId, userId } = connection;
    
    try {
        // メッセージ検証
        if (!roomId || !content) {
            await sendToConnection(connectionId, {
                type: 'error',
                message: 'roomId and content are required'
            });
            return { statusCode: 400, body: 'Invalid message' };
        }
        
        // ルーム参加確認
        if (connection.roomId !== roomId) {
            await sendToConnection(connectionId, {
                type: 'error',
                message: 'You are not in this room'
            });
            return { statusCode: 403, body: 'Not in room' };
        }
        
        // メッセージ保存
        const messageId = uuidv4();
        const timestamp = new Date().toISOString();
        
        const messageData = {
            messageId: messageId,
            roomId: roomId,
            userId: userId,
            connectionId: connectionId,
            content: content,
            messageType: messageType,
            timestamp: timestamp,
            ttl: Math.floor(Date.now() / 1000) + (30 * 24 * 60 * 60) // 30日後削除
        };
        
        await dynamodb.put({
            TableName: MESSAGES_TABLE,
            Item: messageData
        }).promise();
        
        // ルームメンバーにブロードキャスト
        const broadcastMessage = {
            type: 'message',
            messageId: messageId,
            roomId: roomId,
            userId: userId,
            content: content,
            messageType: messageType,
            timestamp: timestamp
        };
        
        await broadcastToRoom(roomId, broadcastMessage);
        
        // 分析用データをKinesisに送信
        await sendToKinesis(messageData);
        
        return { statusCode: 200, body: 'Message sent' };
        
    } catch (error) {
        console.error('Handle message error:', error);
        throw error;
    }
}

async function handleJoinRoom(connection, message) {
    const { roomId, roomName } = message;
    const { connectionId, userId } = connection;
    
    try {
        // ルーム存在確認・作成
        let room = await getOrCreateRoom(roomId, roomName, userId);
        
        // 既に参加している場合は何もしない
        if (connection.roomId === roomId) {
            await sendToConnection(connectionId, {
                type: 'joinedRoom',
                roomId: roomId,
                status: 'already_joined'
            });
            return { statusCode: 200, body: 'Already in room' };
        }
        
        // 現在のルームから退出
        if (connection.roomId) {
            await leaveCurrentRoom(connection);
        }
        
        // 新しいルームに参加
        await joinRoom(connectionId, roomId, userId);
        
        // 参加成功通知
        await sendToConnection(connectionId, {
            type: 'joinedRoom',
            roomId: roomId,
            roomName: room.roomName,
            memberCount: room.memberCount || 0,
            timestamp: new Date().toISOString()
        });
        
        // 他のメンバーに参加通知
        await broadcastToRoom(roomId, {
            type: 'memberJoined',
            roomId: roomId,
            userId: userId,
            connectionId: connectionId,
            timestamp: new Date().toISOString()
        }, connectionId);
        
        return { statusCode: 200, body: 'Joined room' };
        
    } catch (error) {
        console.error('Join room error:', error);
        throw error;
    }
}

async function handleLeaveRoom(connection, message) {
    const { connectionId, userId, roomId } = connection;
    
    if (!roomId) {
        return { statusCode: 400, body: 'Not in any room' };
    }
    
    try {
        await leaveCurrentRoom(connection);
        
        await sendToConnection(connectionId, {
            type: 'leftRoom',
            roomId: roomId,
            timestamp: new Date().toISOString()
        });
        
        return { statusCode: 200, body: 'Left room' };
        
    } catch (error) {
        console.error('Leave room error:', error);
        throw error;
    }
}

async function handleTyping(connection, message) {
    const { roomId, isTyping } = message;
    const { connectionId, userId } = connection;
    
    if (connection.roomId !== roomId) {
        return { statusCode: 403, body: 'Not in room' };
    }
    
    try {
        // 他のメンバーにタイピング状態通知
        await broadcastToRoom(roomId, {
            type: 'typing',
            roomId: roomId,
            userId: userId,
            isTyping: isTyping,
            timestamp: new Date().toISOString()
        }, connectionId);
        
        return { statusCode: 200, body: 'Typing status sent' };
        
    } catch (error) {
        console.error('Handle typing error:', error);
        throw error;
    }
}

async function handlePing(connection) {
    const { connectionId } = connection;
    
    try {
        await sendToConnection(connectionId, {
            type: 'pong',
            timestamp: new Date().toISOString()
        });
        
        return { statusCode: 200, body: 'Pong sent' };
        
    } catch (error) {
        console.error('Handle ping error:', error);
        throw error;
    }
}

async function getOrCreateRoom(roomId, roomName, ownerId) {
    try {
        // ルーム存在確認
        const roomResult = await dynamodb.get({
            TableName: ROOMS_TABLE,
            Key: { roomId: roomId }
        }).promise();
        
        if (roomResult.Item) {
            return roomResult.Item;
        }
        
        // ルーム作成
        const room = {
            roomId: roomId,
            roomName: roomName || `Room ${roomId}`,
            ownerId: ownerId,
            createdAt: new Date().toISOString(),
            memberCount: 0,
            settings: {
                isPublic: true,
                maxMembers: 100,
                allowFileSharing: true
            }
        };
        
        await dynamodb.put({
            TableName: ROOMS_TABLE,
            Item: room,
            ConditionExpression: 'attribute_not_exists(roomId)'
        }).promise();
        
        return room;
        
    } catch (error) {
        if (error.code === 'ConditionalCheckFailedException') {
            // 並行作成時のリトライ
            const roomResult = await dynamodb.get({
                TableName: ROOMS_TABLE,
                Key: { roomId: roomId }
            }).promise();
            return roomResult.Item;
        }
        throw error;
    }
}

async function joinRoom(connectionId, roomId, userId) {
    // 接続情報更新
    await dynamodb.update({
        TableName: CONNECTIONS_TABLE,
        Key: { connectionId: connectionId },
        UpdateExpression: 'SET roomId = :roomId',
        ExpressionAttributeValues: {
            ':roomId': roomId
        }
    }).promise();
    
    // ルームメンバー数更新
    await dynamodb.update({
        TableName: ROOMS_TABLE,
        Key: { roomId: roomId },
        UpdateExpression: 'ADD memberCount :inc',
        ExpressionAttributeValues: {
            ':inc': 1
        }
    }).promise();
}

async function leaveCurrentRoom(connection) {
    const { connectionId, roomId } = connection;
    
    if (!roomId) return;
    
    // 接続情報からルーム削除
    await dynamodb.update({
        TableName: CONNECTIONS_TABLE,
        Key: { connectionId: connectionId },
        UpdateExpression: 'REMOVE roomId'
    }).promise();
    
    // ルームメンバー数減少
    await dynamodb.update({
        TableName: ROOMS_TABLE,
        Key: { roomId: roomId },
        UpdateExpression: 'ADD memberCount :dec',
        ExpressionAttributeValues: {
            ':dec': -1
        }
    }).promise();
    
    // 他のメンバーに退出通知
    await broadcastToRoom(roomId, {
        type: 'memberLeft',
        roomId: roomId,
        userId: connection.userId,
        connectionId: connectionId,
        timestamp: new Date().toISOString()
    }, connectionId);
}

async function updateLastActivity(connectionId) {
    await dynamodb.update({
        TableName: CONNECTIONS_TABLE,
        Key: { connectionId: connectionId },
        UpdateExpression: 'SET lastActivity = :timestamp',
        ExpressionAttributeValues: {
            ':timestamp': new Date().toISOString()
        }
    }).promise();
}

async function sendToConnection(connectionId, message) {
    try {
        await apigateway.postToConnection({
            ConnectionId: connectionId,
            Data: JSON.stringify(message)
        }).promise();
    } catch (error) {
        if (error.statusCode === 410) {
            // 切断された接続の削除
            await dynamodb.delete({
                TableName: CONNECTIONS_TABLE,
                Key: { connectionId: connectionId }
            }).promise();
        }
        throw error;
    }
}

async function broadcastToRoom(roomId, message, excludeConnectionId = null) {
    try {
        const connections = await dynamodb.query({
            TableName: CONNECTIONS_TABLE,
            IndexName: 'room-connections-index',
            KeyConditionExpression: 'roomId = :roomId',
            ExpressionAttributeValues: {
                ':roomId': roomId
            }
        }).promise();
        
        const sendPromises = connections.Items
            .filter(conn => conn.connectionId !== excludeConnectionId)
            .map(conn => sendToConnection(conn.connectionId, message));
        
        const results = await Promise.allSettled(sendPromises);
        
        // 失敗した送信のログ
        results.forEach((result, index) => {
            if (result.status === 'rejected') {
                console.error(`Failed to send to connection ${connections.Items[index].connectionId}:`, result.reason);
            }
        });
        
    } catch (error) {
        console.error('Broadcast to room error:', error);
    }
}

async function sendToKinesis(messageData) {
    try {
        await kinesis.putRecord({
            StreamName: KINESIS_STREAM,
            Data: JSON.stringify({
                eventType: 'message',
                timestamp: new Date().toISOString(),
                data: messageData
            }),
            PartitionKey: messageData.roomId
        }).promise();
    } catch (error) {
        console.error('Kinesis put record error:', error);
    }
}
```

### ステップ3: フロントエンド実装

1. **WebSocket クライアントクラス**
```javascript
// src/client/websocket-client.js
class WebSocketClient {
    constructor(options = {}) {
        this.url = options.url;
        this.token = options.token;
        this.ws = null;
        this.connectionId = null;
        this.currentRoom = null;
        this.reconnectAttempts = 0;
        this.maxReconnectAttempts = options.maxReconnectAttempts || 5;
        this.reconnectInterval = options.reconnectInterval || 1000;
        this.heartbeatInterval = options.heartbeatInterval || 30000;
        this.heartbeatTimer = null;
        
        // イベントハンドラー
        this.eventHandlers = new Map();
        
        // 自動再接続設定
        this.autoReconnect = options.autoReconnect !== false;
        
        // 接続状態
        this.connectionState = 'disconnected'; // 'disconnected', 'connecting', 'connected'
        
        this.setupEventHandlers();
    }
    
    /**
     * WebSocket接続を開始
     */
    async connect() {
        if (this.connectionState === 'connected' || this.connectionState === 'connecting') {
            return;
        }
        
        this.connectionState = 'connecting';
        this.emit('connecting');
        
        try {
            const wsUrl = this.token ? `${this.url}?token=${this.token}` : this.url;
            this.ws = new WebSocket(wsUrl);
            
            this.ws.onopen = this.handleOpen.bind(this);
            this.ws.onclose = this.handleClose.bind(this);
            this.ws.onerror = this.handleError.bind(this);
            this.ws.onmessage = this.handleMessage.bind(this);
            
        } catch (error) {
            console.error('WebSocket connection error:', error);
            this.connectionState = 'disconnected';
            this.emit('error', error);
            
            if (this.autoReconnect) {
                this.scheduleReconnect();
            }
        }
    }
    
    /**
     * WebSocket接続を切断
     */
    disconnect() {
        this.autoReconnect = false;
        this.clearHeartbeat();
        
        if (this.ws) {
            this.ws.close(1000, 'Client disconnect');
        }
        
        this.connectionState = 'disconnected';
        this.emit('disconnected');
    }
    
    /**
     * メッセージ送信
     */
    send(action, data = {}) {
        if (this.connectionState !== 'connected') {
            console.warn('WebSocket not connected');
            return false;
        }
        
        try {
            const message = {
                action: action,
                timestamp: new Date().toISOString(),
                ...data
            };
            
            this.ws.send(JSON.stringify(message));
            return true;
        } catch (error) {
            console.error('Send message error:', error);
            return false;
        }
    }
    
    /**
     * ルームに参加
     */
    joinRoom(roomId, roomName = null) {
        return this.send('joinRoom', {
            roomId: roomId,
            roomName: roomName
        });
    }
    
    /**
     * ルームから退出
     */
    leaveRoom() {
        return this.send('leaveRoom', {
            roomId: this.currentRoom
        });
    }
    
    /**
     * メッセージ送信
     */
    sendMessage(content, messageType = 'text') {
        if (!this.currentRoom) {
            console.warn('Not in any room');
            return false;
        }
        
        return this.send('message', {
            roomId: this.currentRoom,
            content: content,
            messageType: messageType
        });
    }
    
    /**
     * タイピング状態送信
     */
    sendTyping(isTyping) {
        if (!this.currentRoom) {
            return false;
        }
        
        return this.send('typing', {
            roomId: this.currentRoom,
            isTyping: isTyping
        });
    }
    
    /**
     * ハートビート送信
     */
    sendPing() {
        return this.send('ping');
    }
    
    /**
     * イベントリスナー登録
     */
    on(event, handler) {
        if (!this.eventHandlers.has(event)) {
            this.eventHandlers.set(event, []);
        }
        this.eventHandlers.get(event).push(handler);
    }
    
    /**
     * イベントリスナー削除
     */
    off(event, handler) {
        if (this.eventHandlers.has(event)) {
            const handlers = this.eventHandlers.get(event);
            const index = handlers.indexOf(handler);
            if (index > -1) {
                handlers.splice(index, 1);
            }
        }
    }
    
    /**
     * イベント発火
     */
    emit(event, data = null) {
        if (this.eventHandlers.has(event)) {
            this.eventHandlers.get(event).forEach(handler => {
                try {
                    handler(data);
                } catch (error) {
                    console.error(`Event handler error for ${event}:`, error);
                }
            });
        }
    }
    
    setupEventHandlers() {
        // デフォルトイベントハンドラー
        this.on('connected', (data) => {
            console.log('WebSocket connected:', data);
            this.connectionId = data.connectionId;
        });
        
        this.on('joinedRoom', (data) => {
            console.log('Joined room:', data);
            this.currentRoom = data.roomId;
        });
        
        this.on('leftRoom', (data) => {
            console.log('Left room:', data);
            this.currentRoom = null;
        });
        
        this.on('message', (data) => {
            console.log('Received message:', data);
        });
        
        this.on('error', (error) => {
            console.error('WebSocket error:', error);
        });
    }
    
    handleOpen(event) {
        console.log('WebSocket connection opened');
        this.connectionState = 'connected';
        this.reconnectAttempts = 0;
        this.startHeartbeat();
        this.emit('connected', { connectionId: null });
    }
    
    handleClose(event) {
        console.log('WebSocket connection closed:', event.code, event.reason);
        this.connectionState = 'disconnected';
        this.clearHeartbeat();
        this.currentRoom = null;
        this.emit('disconnected', { code: event.code, reason: event.reason });
        
        if (this.autoReconnect && event.code !== 1000) {
            this.scheduleReconnect();
        }
    }
    
    handleError(event) {
        console.error('WebSocket error:', event);
        this.emit('error', event);
    }
    
    handleMessage(event) {
        try {
            const message = JSON.parse(event.data);
            console.log('WebSocket message received:', message);
            
            // メッセージタイプに応じてイベント発火
            this.emit(message.type, message);
            
            // 特定のメッセージタイプの処理
            switch (message.type) {
                case 'connection':
                    if (message.status === 'connected') {
                        this.connectionId = message.connectionId;
                    }
                    break;
                    
                case 'pong':
                    // ハートビート応答
                    break;
                    
                case 'error':
                    console.error('Server error:', message.message);
                    break;
            }
            
        } catch (error) {
            console.error('Message parsing error:', error);
        }
    }
    
    scheduleReconnect() {
        if (this.reconnectAttempts >= this.maxReconnectAttempts) {
            console.error('Max reconnection attempts reached');
            this.emit('reconnectFailed');
            return;
        }
        
        this.reconnectAttempts++;
        const delay = this.reconnectInterval * Math.pow(2, this.reconnectAttempts - 1);
        
        console.log(`Reconnecting in ${delay}ms (attempt ${this.reconnectAttempts})`);
        this.emit('reconnecting', { attempts: this.reconnectAttempts, delay });
        
        setTimeout(() => {
            if (this.autoReconnect && this.connectionState === 'disconnected') {
                this.connect();
            }
        }, delay);
    }
    
    startHeartbeat() {
        this.clearHeartbeat();
        this.heartbeatTimer = setInterval(() => {
            this.sendPing();
        }, this.heartbeatInterval);
    }
    
    clearHeartbeat() {
        if (this.heartbeatTimer) {
            clearInterval(this.heartbeatTimer);
            this.heartbeatTimer = null;
        }
    }
    
    /**
     * 接続状態取得
     */
    isConnected() {
        return this.connectionState === 'connected';
    }
    
    /**
     * 現在のルーム取得
     */
    getCurrentRoom() {
        return this.currentRoom;
    }
    
    /**
     * 接続ID取得
     */
    getConnectionId() {
        return this.connectionId;
    }
}

export default WebSocketClient;
```

2. **React チャットコンポーネント**
```jsx
// src/components/Chat/ChatRoom.jsx
import React, { useState, useEffect, useRef } from 'react';
import WebSocketClient from '../../client/websocket-client';

const ChatRoom = ({ roomId, roomName, userId, token }) => {
    const [messages, setMessages] = useState([]);
    const [inputMessage, setInputMessage] = useState('');
    const [isConnected, setIsConnected] = useState(false);
    const [isTyping, setIsTyping] = useState(false);
    const [typingUsers, setTypingUsers] = useState(new Set());
    const [roomMembers, setRoomMembers] = useState([]);
    const [connectionStatus, setConnectionStatus] = useState('disconnected');
    
    const wsClient = useRef(null);
    const messagesEndRef = useRef(null);
    const typingTimeoutRef = useRef(null);
    
    useEffect(() => {
        if (!wsClient.current) {
            initializeWebSocket();
        }
        
        return () => {
            if (wsClient.current) {
                wsClient.current.disconnect();
            }
        };
    }, []);
    
    useEffect(() => {
        if (wsClient.current && isConnected && roomId) {
            joinRoom();
        }
    }, [isConnected, roomId]);
    
    useEffect(() => {
        scrollToBottom();
    }, [messages]);
    
    const initializeWebSocket = () => {
        const wsUrl = process.env.REACT_APP_WEBSOCKET_URL;
        
        wsClient.current = new WebSocketClient({
            url: wsUrl,
            token: token,
            autoReconnect: true,
            maxReconnectAttempts: 5
        });
        
        // イベントハンドラー設定
        wsClient.current.on('connected', handleConnected);
        wsClient.current.on('disconnected', handleDisconnected);
        wsClient.current.on('connecting', handleConnecting);
        wsClient.current.on('reconnecting', handleReconnecting);
        wsClient.current.on('joinedRoom', handleJoinedRoom);
        wsClient.current.on('leftRoom', handleLeftRoom);
        wsClient.current.on('message', handleMessage);
        wsClient.current.on('memberJoined', handleMemberJoined);
        wsClient.current.on('memberLeft', handleMemberLeft);
        wsClient.current.on('typing', handleTyping);
        wsClient.current.on('error', handleError);
        
        // 接続開始
        wsClient.current.connect();
    };
    
    const handleConnected = (data) => {
        setIsConnected(true);
        setConnectionStatus('connected');
        console.log('Connected to WebSocket:', data);
    };
    
    const handleDisconnected = (data) => {
        setIsConnected(false);
        setConnectionStatus('disconnected');
        console.log('Disconnected from WebSocket:', data);
    };
    
    const handleConnecting = () => {
        setConnectionStatus('connecting');
    };
    
    const handleReconnecting = (data) => {
        setConnectionStatus(`reconnecting (${data.attempts})`);
    };
    
    const handleJoinedRoom = (data) => {
        console.log('Joined room:', data);
        setMessages([]); // 新しいルームの場合、メッセージをクリア
    };
    
    const handleLeftRoom = (data) => {
        console.log('Left room:', data);
    };
    
    const handleMessage = (data) => {
        const newMessage = {
            id: data.messageId,
            userId: data.userId,
            content: data.content,
            messageType: data.messageType,
            timestamp: data.timestamp,
            isOwn: data.userId === userId
        };
        
        setMessages(prev => [...prev, newMessage]);
    };
    
    const handleMemberJoined = (data) => {
        console.log('Member joined:', data);
        // メンバーリスト更新ロジック
    };
    
    const handleMemberLeft = (data) => {
        console.log('Member left:', data);
        // メンバーリスト更新ロジック
    };
    
    const handleTyping = (data) => {
        const { userId: typingUserId, isTyping } = data;
        
        setTypingUsers(prev => {
            const newSet = new Set(prev);
            if (isTyping) {
                newSet.add(typingUserId);
            } else {
                newSet.delete(typingUserId);
            }
            return newSet;
        });
        
        // タイピング表示の自動削除
        if (isTyping) {
            setTimeout(() => {
                setTypingUsers(prev => {
                    const newSet = new Set(prev);
                    newSet.delete(typingUserId);
                    return newSet;
                });
            }, 3000);
        }
    };
    
    const handleError = (error) => {
        console.error('WebSocket error:', error);
    };
    
    const joinRoom = () => {
        if (wsClient.current && roomId) {
            wsClient.current.joinRoom(roomId, roomName);
        }
    };
    
    const sendMessage = () => {
        if (!inputMessage.trim() || !wsClient.current) {
            return;
        }
        
        const success = wsClient.current.sendMessage(inputMessage.trim());
        if (success) {
            setInputMessage('');
            stopTyping();
        }
    };
    
    const handleInputChange = (e) => {
        setInputMessage(e.target.value);
        
        // タイピング状態の管理
        if (!isTyping && e.target.value.length > 0) {
            startTyping();
        }
        
        // タイピング状態のタイムアウト管理
        if (typingTimeoutRef.current) {
            clearTimeout(typingTimeoutRef.current);
        }
        
        if (e.target.value.length > 0) {
            typingTimeoutRef.current = setTimeout(() => {
                stopTyping();
            }, 1000);
        } else {
            stopTyping();
        }
    };
    
    const handleKeyPress = (e) => {
        if (e.key === 'Enter' && !e.shiftKey) {
            e.preventDefault();
            sendMessage();
        }
    };
    
    const startTyping = () => {
        if (wsClient.current && !isTyping) {
            setIsTyping(true);
            wsClient.current.sendTyping(true);
        }
    };
    
    const stopTyping = () => {
        if (wsClient.current && isTyping) {
            setIsTyping(false);
            wsClient.current.sendTyping(false);
        }
        
        if (typingTimeoutRef.current) {
            clearTimeout(typingTimeoutRef.current);
            typingTimeoutRef.current = null;
        }
    };
    
    const scrollToBottom = () => {
        messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
    };
    
    const formatTimestamp = (timestamp) => {
        return new Date(timestamp).toLocaleTimeString([], { 
            hour: '2-digit', 
            minute: '2-digit' 
        });
    };
    
    const renderConnectionStatus = () => {
        const statusColors = {
            connected: 'green',
            connecting: 'orange',
            disconnected: 'red'
        };
        
        return (
            <div className="connection-status">
                <span 
                    className="status-indicator"
                    style={{ backgroundColor: statusColors[connectionStatus.split(' ')[0]] }}
                />
                <span className="status-text">{connectionStatus}</span>
            </div>
        );
    };
    
    const renderTypingIndicator = () => {
        if (typingUsers.size === 0) return null;
        
        const typingUsersList = Array.from(typingUsers);
        let text = '';
        
        if (typingUsersList.length === 1) {
            text = `${typingUsersList[0]} is typing...`;
        } else if (typingUsersList.length === 2) {
            text = `${typingUsersList[0]} and ${typingUsersList[1]} are typing...`;
        } else {
            text = `${typingUsersList.length} users are typing...`;
        }
        
        return (
            <div className="typing-indicator">
                <div className="typing-animation">
                    <span></span>
                    <span></span>
                    <span></span>
                </div>
                <span className="typing-text">{text}</span>
            </div>
        );
    };
    
    return (
        <div className="chat-room">
            <div className="chat-header">
                <h3>{roomName || roomId}</h3>
                {renderConnectionStatus()}
            </div>
            
            <div className="messages-container">
                {messages.map((message) => (
                    <div 
                        key={message.id}
                        className={`message ${message.isOwn ? 'own-message' : 'other-message'}`}
                    >
                        <div className="message-header">
                            <span className="message-user">{message.userId}</span>
                            <span className="message-time">
                                {formatTimestamp(message.timestamp)}
                            </span>
                        </div>
                        <div className="message-content">
                            {message.content}
                        </div>
                    </div>
                ))}
                {renderTypingIndicator()}
                <div ref={messagesEndRef} />
            </div>
            
            <div className="chat-input">
                <textarea
                    value={inputMessage}
                    onChange={handleInputChange}
                    onKeyPress={handleKeyPress}
                    placeholder="Type a message..."
                    disabled={!isConnected}
                    rows={2}
                />
                <button 
                    onClick={sendMessage}
                    disabled={!isConnected || !inputMessage.trim()}
                >
                    Send
                </button>
            </div>
        </div>
    );
};

export default ChatRoom;
```

## 検証方法

### 1. WebSocket 接続テスト
```bash
# wscat を使用した手動テスト
npm install -g wscat

# WebSocket 接続テスト
wscat -c wss://your-api-id.execute-api.region.amazonaws.com/dev

# メッセージ送信テスト
{"action":"joinRoom","roomId":"test-room"}
{"action":"message","roomId":"test-room","content":"Hello World!"}
```

### 2. 負荷テスト
```javascript
// 複数接続負荷テスト
const WebSocket = require('ws');

async function loadTest(concurrentConnections = 100) {
    const connections = [];
    const wsUrl = 'wss://your-api-id.execute-api.region.amazonaws.com/dev';
    
    for (let i = 0; i < concurrentConnections; i++) {
        const ws = new WebSocket(wsUrl);
        connections.push(ws);
        
        ws.on('open', () => {
            console.log(`Connection ${i} opened`);
            
            // ルーム参加
            ws.send(JSON.stringify({
                action: 'joinRoom',
                roomId: 'load-test-room'
            }));
            
            // 定期的にメッセージ送信
            setInterval(() => {
                ws.send(JSON.stringify({
                    action: 'message',
                    roomId: 'load-test-room',
                    content: `Message from connection ${i}`
                }));
            }, 5000);
        });
        
        ws.on('message', (data) => {
            const message = JSON.parse(data);
            console.log(`Connection ${i} received:`, message.type);
        });
        
        // 接続間隔
        await new Promise(resolve => setTimeout(resolve, 100));
    }
    
    console.log(`Started ${concurrentConnections} connections`);
}

loadTest(50);
```

### 3. メトリクス監視
```bash
# CloudWatch メトリクス確認
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApiGatewayV2 \
  --metric-name MessageCount \
  --dimensions Name=ApiId,Value=your-api-id \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-01T23:59:59Z \
  --period 3600 \
  --statistics Sum
```

## トラブルシューティング

### よくある問題と解決策

#### 1. 接続切断の頻発
**症状**: WebSocket接続が頻繁に切断される
**解決策**:
- ハートビート間隔の調整
- API Gateway タイムアウト設定確認
- ネットワーク環境の調査

#### 2. メッセージ配信遅延
**症状**: リアルタイム性が低い
**解決策**:
- Lambda同時実行数の確認
- DynamoDB読み取り性能の最適化
- キャッシュ戦略の導入

#### 3. スケーリング問題
**症状**: 大量接続時のパフォーマンス低下
**解決策**:
- DynamoDB Auto Scaling設定
- Lambda予約済み同時実行数の調整
- 接続分散の実装

## 学習リソース

### AWS公式ドキュメント
- [API Gateway WebSocket APIs](https://docs.aws.amazon.com/apigateway/latest/developerguide/websocket-api.html)
- [Lambda Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html)
- [DynamoDB Streams](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Streams.html)

### 追加学習教材
- [WebSocket Protocol Specification](https://tools.ietf.org/html/rfc6455)
- [Real-time Web Applications](https://developer.mozilla.org/en-US/docs/Web/API/WebSockets_API)

## セキュリティとコストの考慮事項

### セキュリティベストプラクティス
1. **認証・認可**: JWT トークンベース認証
2. **レート制限**: API Gateway スロットリング
3. **入力検証**: メッセージ内容の検証・サニタイズ
4. **接続管理**: 不正接続の検知と切断

### コスト最適化
1. **接続管理**: アイドル接続の自動切断
2. **メッセージ最適化**: 不要なブロードキャスト削減
3. **DynamoDB最適化**: TTL活用による自動削除
4. **Lambda最適化**: 適切なメモリ・タイムアウト設定

### AWS Well-Architectedフレームワークとの関連
- **運用性の柱**: CloudWatch監視・ログ管理・自動化
- **セキュリティの柱**: 認証・認可・入力検証・暗号化
- **信頼性の柱**: 自動再接続・エラーハンドリング・フェイルオーバー
- **パフォーマンス効率の柱**: 接続プール・適切なタイムアウト設定
- **コスト最適化の柱**: 従量課金・リソース最適化・自動スケーリング

## 次のステップ

### 推奨される学習パス
1. **4.1.1 Kinesisストリーミング**: 大規模イベント処理
2. **5.2.1 チャットボット作成**: AI統合リアルタイム機能
3. **6.1.1 マルチステージビルド**: CI/CD パイプライン
4. **6.2.1 APM実装**: リアルタイム監視強化

### 発展的な機能
1. **WebRTC統合**: P2P通信とメディアストリーミング
2. **Message Queue**: 高信頼性メッセージ配信
3. **Federation**: 複数リージョン間のリアルタイム同期
4. **Analytics**: リアルタイム使用状況分析

### 実践プロジェクトのアイデア
1. **リアルタイムチャット**: Slack風チャットアプリ
2. **コラボレーションツール**: 共同編集機能
3. **ライブダッシュボード**: リアルタイムデータ可視化
4. **ゲームプラットフォーム**: マルチプレイヤーゲーム