# 1.2.3 Lambda関数デプロイ

## 学習目標

このセクションでは、AWS Lambdaを使用したサーバーレスアプリケーションの開発・デプロイ・運用方法を習得し、イベント駆動型アーキテクチャの実装を学習します。

### 習得できるスキル
- AWS Lambda関数の開発とデプロイ
- イベント駆動アーキテクチャの設計と実装
- API Gateway連携による REST API構築
- CloudWatch Events/EventBridgeによる定期実行
- Lambda Layersによるコード共有
- デッドレターキューとエラーハンドリング

## 前提知識

### 必須の知識
- Python、Node.js、またはJavaの基本プログラミング
- JSON形式の理解
- REST APIの基本概念
- CloudFormationの基本操作（1.1.1セクション完了）

### あると望ましい知識
- サーバーレスアーキテクチャの概念
- AWS SDKの使用経験
- CloudWatchの基本操作
- SQS、SNSの基本概念

## アーキテクチャ概要

### サーバーレスアプリケーションアーキテクチャ

```
                    ┌─────────────────┐
                    │   CloudFront    │
                    │  (CDN/Edge)     │
                    └─────────┬───────┘
                              │
                              ▼
        ┌─────────────────────────────────────────────────────────┐
        │                API Gateway                              │
        │                                                         │
        │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │
        │  │     GET     │  │    POST     │  │   DELETE    │   │
        │  │   /users    │  │   /users    │  │ /users/{id} │   │
        │  └─────────────┘  └─────────────┘  └─────────────┘   │
        └─────────┬───────────────┬───────────────┬─────────────┘
                  │               │               │
                  ▼               ▼               ▼
        ┌─────────────────┐ ┌─────────────┐ ┌─────────────────┐
        │   Lambda        │ │   Lambda    │ │   Lambda        │
        │  List Users     │ │ Create User │ │  Delete User    │
        │                 │ │             │ │                 │
        │ ┌─────────────┐ │ │┌──────────┐ │ │ ┌─────────────┐ │
        │ │   Runtime   │ │ ││ Runtime  │ │ │ │   Runtime   │ │
        │ │  (Python)   │ │ ││(Node.js) │ │ │ │   (Java)    │ │
        │ └─────────────┘ │ │└──────────┘ │ │ └─────────────┘ │
        └─────────┬───────┘ └──────┬──────┘ └─────────┬───────┘
                  │                │                  │
                  ▼                ▼                  ▼
        ┌─────────────────────────────────────────────────────────┐
        │                   DynamoDB                              │
        │                                                         │
        │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │
        │  │   Users     │  │   Orders    │  │   Products  │   │
        │  │   Table     │  │   Table     │  │   Table     │   │
        │  └─────────────┘  └─────────────┘  └─────────────┘   │
        └─────────────────────────────────────────────────────────┘
                                   │
                                   ▼
        ┌─────────────────────────────────────────────────────────┐
        │              Event-Driven Processing                    │
        │                                                         │
        │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │
        │  │ EventBridge │  │     SQS     │  │     SNS     │   │
        │  │  (Cron)     │  │   (Queue)   │  │ (Notifications)│   │
        │  └─────────────┘  └─────────────┘  └─────────────┘   │
        │         │                │                │            │
        │         ▼                ▼                ▼            │
        │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │
        │  │   Lambda    │  │   Lambda    │  │   Lambda    │   │
        │  │ (Scheduled) │  │ (Async Job) │  │(Notification)│   │
        │  └─────────────┘  └─────────────┘  └─────────────┘   │
        └─────────────────────────────────────────────────────────┘
```

### 主要コンポーネント
- **Lambda Functions**: ビジネスロジック実行
- **API Gateway**: HTTPエンドポイント提供
- **DynamoDB**: データ永続化
- **EventBridge**: スケジュール実行
- **SQS/SNS**: 非同期処理・通知
- **Lambda Layers**: 共通ライブラリ

## ハンズオン手順

### ステップ1: 基本的なLambda関数の作成

1. **Python Lambda関数 (CRUD API)**
```python
# src/lambda/users/list_users.py
import json
import boto3
import os
from decimal import Decimal
from boto3.dynamodb.conditions import Key
from botocore.exceptions import ClientError

dynamodb = boto3.resource('dynamodb')
table_name = os.environ['USERS_TABLE']
table = dynamodb.Table(table_name)

def lambda_handler(event, context):
    """ユーザー一覧取得Lambda関数"""
    try:
        # クエリパラメータの取得
        query_params = event.get('queryStringParameters') or {}
        limit = int(query_params.get('limit', 50))
        last_key = query_params.get('lastKey')
        
        # DynamoDBスキャン
        scan_params = {
            'Limit': min(limit, 100)  # 最大100件
        }
        
        if last_key:
            scan_params['ExclusiveStartKey'] = {'userId': last_key}
        
        response = table.scan(**scan_params)
        
        # Decimal型をfloatに変換
        items = [convert_decimal(item) for item in response['Items']]
        
        # レスポンス構築
        result = {
            'users': items,
            'count': len(items)
        }
        
        if 'LastEvaluatedKey' in response:
            result['lastKey'] = response['LastEvaluatedKey']['userId']
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
            },
            'body': json.dumps(result, ensure_ascii=False)
        }
        
    except ClientError as e:
        print(f"DynamoDB error: {e}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({
                'error': 'Failed to fetch users',
                'message': str(e)
            })
        }
    except Exception as e:
        print(f"Unexpected error: {e}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({
                'error': 'Internal server error',
                'message': str(e)
            })
        }

def convert_decimal(obj):
    """Decimal型をJSON互換型に変換"""
    if isinstance(obj, list):
        return [convert_decimal(i) for i in obj]
    elif isinstance(obj, dict):
        return {k: convert_decimal(v) for k, v in obj.items()}
    elif isinstance(obj, Decimal):
        return float(obj)
    return obj
```

2. **Node.js Lambda関数 (ユーザー作成)**
```javascript
// src/lambda/users/create_user.js
const AWS = require('aws-sdk');
const { v4: uuidv4 } = require('uuid');

const dynamodb = new AWS.DynamoDB.DocumentClient();
const tableName = process.env.USERS_TABLE;

exports.handler = async (event, context) => {
    try {
        // リクエストボディの解析
        const requestBody = JSON.parse(event.body);
        
        // バリデーション
        const validation = validateUserData(requestBody);
        if (!validation.isValid) {
            return {
                statusCode: 400,
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    error: 'Validation failed',
                    details: validation.errors
                })
            };
        }
        
        // ユーザーデータ作成
        const userId = uuidv4();
        const timestamp = new Date().toISOString();
        
        const userData = {
            userId: userId,
            email: requestBody.email,
            name: requestBody.name,
            phone: requestBody.phone || null,
            address: requestBody.address || null,
            status: 'active',
            createdAt: timestamp,
            updatedAt: timestamp
        };
        
        // DynamoDBに保存
        await dynamodb.put({
            TableName: tableName,
            Item: userData,
            ConditionExpression: 'attribute_not_exists(userId)'
        }).promise();
        
        // 成功レスポンス
        return {
            statusCode: 201,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({
                message: 'User created successfully',
                user: userData
            })
        };
        
    } catch (error) {
        console.error('Error:', error);
        
        if (error.code === 'ConditionalCheckFailedException') {
            return {
                statusCode: 409,
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    error: 'User already exists'
                })
            };
        }
        
        return {
            statusCode: 500,
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                error: 'Failed to create user',
                message: error.message
            })
        };
    }
};

function validateUserData(data) {
    const errors = [];
    
    if (!data.email || !isValidEmail(data.email)) {
        errors.push('Valid email is required');
    }
    
    if (!data.name || data.name.length < 2) {
        errors.push('Name must be at least 2 characters');
    }
    
    return {
        isValid: errors.length === 0,
        errors: errors
    };
}

function isValidEmail(email) {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
}
```

### ステップ2: Lambda関数のCloudFormation定義

1. **Lambda関数とロール**
```yaml
# lambda-functions.yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Lambda functions for serverless application'

Parameters:
  ProjectName:
    Type: String
    Default: 'lambda-deploy'
  
  EnvironmentName:
    Type: String
    Default: 'dev'
    AllowedValues: [dev, staging, prod]
  
  UsersTableName:
    Type: String
    Description: 'DynamoDB table name for users'

Resources:
  # Lambda Execution Role
  LambdaExecutionRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: !Sub '${ProjectName}-${EnvironmentName}-lambda-role'
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: lambda.amazonaws.com
            Action: sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
        - arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole
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
                  - dynamodb:Scan
                  - dynamodb:Query
                Resource: 
                  - !Sub 'arn:aws:dynamodb:${AWS::Region}:${AWS::AccountId}:table/${UsersTableName}'
                  - !Sub 'arn:aws:dynamodb:${AWS::Region}:${AWS::AccountId}:table/${UsersTableName}/index/*'

  # Lambda Layer (共通ライブラリ用)
  CommonLibraryLayer:
    Type: AWS::Lambda::LayerVersion
    Properties:
      LayerName: !Sub '${ProjectName}-${EnvironmentName}-common-libs'
      Description: 'Common libraries for Lambda functions'
      Content:
        S3Bucket: !Ref ArtifactsBucket
        S3Key: 'layers/common-libs.zip'
      CompatibleRuntimes:
        - python3.9
        - nodejs18.x
      LicenseInfo: 'MIT'

  # List Users Lambda Function
  ListUsersFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: !Sub '${ProjectName}-${EnvironmentName}-list-users'
      Runtime: python3.9
      Handler: list_users.lambda_handler
      Role: !GetAtt LambdaExecutionRole.Arn
      Code:
        S3Bucket: !Ref ArtifactsBucket
        S3Key: 'functions/list-users.zip'
      Environment:
        Variables:
          USERS_TABLE: !Ref UsersTableName
          ENVIRONMENT: !Ref EnvironmentName
      Timeout: 30
      MemorySize: 128
      ReservedConcurrencyLimit: 100
      Layers:
        - !Ref CommonLibraryLayer
      DeadLetterQueue:
        TargetArn: !GetAtt DeadLetterQueue.Arn
      Tags:
        - Key: Environment
          Value: !Ref EnvironmentName
        - Key: Project
          Value: !Ref ProjectName

  # Create User Lambda Function
  CreateUserFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: !Sub '${ProjectName}-${EnvironmentName}-create-user'
      Runtime: nodejs18.x
      Handler: create_user.handler
      Role: !GetAtt LambdaExecutionRole.Arn
      Code:
        S3Bucket: !Ref ArtifactsBucket
        S3Key: 'functions/create-user.zip'
      Environment:
        Variables:
          USERS_TABLE: !Ref UsersTableName
          ENVIRONMENT: !Ref EnvironmentName
      Timeout: 30
      MemorySize: 256
      ReservedConcurrencyLimit: 50
      DeadLetterQueue:
        TargetArn: !GetAtt DeadLetterQueue.Arn
      Tags:
        - Key: Environment
          Value: !Ref EnvironmentName
        - Key: Project
          Value: !Ref ProjectName

  # Scheduled Function (定期実行)
  ScheduledFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: !Sub '${ProjectName}-${EnvironmentName}-scheduled-task'
      Runtime: python3.9
      Handler: scheduled_task.lambda_handler
      Role: !GetAtt LambdaExecutionRole.Arn
      Code:
        ZipFile: |
          import json
          import boto3
          import os
          from datetime import datetime
          
          def lambda_handler(event, context):
              print(f"Scheduled task executed at: {datetime.now().isoformat()}")
              
              # 例: 古いデータのクリーンアップ
              dynamodb = boto3.resource('dynamodb')
              table = dynamodb.Table(os.environ['USERS_TABLE'])
              
              # 実際のクリーンアップロジックをここに実装
              print("Cleanup task completed")
              
              return {
                  'statusCode': 200,
                  'body': json.dumps({
                      'message': 'Scheduled task completed successfully',
                      'timestamp': datetime.now().isoformat()
                  })
              }
      Environment:
        Variables:
          USERS_TABLE: !Ref UsersTableName
      Timeout: 300
      MemorySize: 512
      Tags:
        - Key: Environment
          Value: !Ref EnvironmentName
        - Key: Project
          Value: !Ref ProjectName

  # EventBridge Rule for Scheduled Function
  ScheduledEventRule:
    Type: AWS::Events::Rule
    Properties:
      Name: !Sub '${ProjectName}-${EnvironmentName}-scheduled-rule'
      Description: 'Schedule for Lambda function execution'
      ScheduleExpression: 'rate(1 hour)'  # 1時間ごと
      State: ENABLED
      Targets:
        - Arn: !GetAtt ScheduledFunction.Arn
          Id: ScheduledFunctionTarget

  # Lambda Permission for EventBridge
  ScheduledFunctionPermission:
    Type: AWS::Lambda::Permission
    Properties:
      FunctionName: !Ref ScheduledFunction
      Action: lambda:InvokeFunction
      Principal: events.amazonaws.com
      SourceArn: !GetAtt ScheduledEventRule.Arn

  # Dead Letter Queue
  DeadLetterQueue:
    Type: AWS::SQS::Queue
    Properties:
      QueueName: !Sub '${ProjectName}-${EnvironmentName}-dlq'
      MessageRetentionPeriod: 1209600  # 14 days
      VisibilityTimeoutSeconds: 60
      Tags:
        - Key: Environment
          Value: !Ref EnvironmentName
        - Key: Project
          Value: !Ref ProjectName

  # CloudWatch Log Groups
  ListUsersLogGroup:
    Type: AWS::Logs::LogGroup
    Properties:
      LogGroupName: !Sub '/aws/lambda/${ListUsersFunction}'
      RetentionInDays: 30

  CreateUserLogGroup:
    Type: AWS::Logs::LogGroup
    Properties:
      LogGroupName: !Sub '/aws/lambda/${CreateUserFunction}'
      RetentionInDays: 30

  ScheduledFunctionLogGroup:
    Type: AWS::Logs::LogGroup
    Properties:
      LogGroupName: !Sub '/aws/lambda/${ScheduledFunction}'
      RetentionInDays: 30

  # S3 Bucket for artifacts
  ArtifactsBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Sub '${ProjectName}-${EnvironmentName}-artifacts-${AWS::AccountId}-${AWS::Region}'
      VersioningConfiguration:
        Status: Enabled
      LifecycleConfiguration:
        Rules:
          - Id: DeleteOldVersions
            Status: Enabled
            NoncurrentVersionExpirationInDays: 30
      PublicAccessBlockConfiguration:
        BlockPublicAcls: true
        BlockPublicPolicy: true
        IgnorePublicAcls: true
        RestrictPublicBuckets: true

  # CloudWatch Alarms
  ListUsersFunctionErrorAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: !Sub '${ProjectName}-${EnvironmentName}-list-users-errors'
      AlarmDescription: 'Lambda function error rate alarm'
      MetricName: Errors
      Namespace: AWS/Lambda
      Statistic: Sum
      Period: 300
      EvaluationPeriods: 2
      Threshold: 5
      ComparisonOperator: GreaterThanOrEqualToThreshold
      Dimensions:
        - Name: FunctionName
          Value: !Ref ListUsersFunction

  CreateUserFunctionDurationAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: !Sub '${ProjectName}-${EnvironmentName}-create-user-duration'
      AlarmDescription: 'Lambda function duration alarm'
      MetricName: Duration
      Namespace: AWS/Lambda
      Statistic: Average
      Period: 300
      EvaluationPeriods: 2
      Threshold: 20000  # 20秒
      ComparisonOperator: GreaterThanThreshold
      Dimensions:
        - Name: FunctionName
          Value: !Ref CreateUserFunction

Outputs:
  ListUsersFunctionArn:
    Description: 'List Users Lambda Function ARN'
    Value: !GetAtt ListUsersFunction.Arn
    Export:
      Name: !Sub '${AWS::StackName}-ListUsersFunction'
  
  CreateUserFunctionArn:
    Description: 'Create User Lambda Function ARN'
    Value: !GetAtt CreateUserFunction.Arn
    Export:
      Name: !Sub '${AWS::StackName}-CreateUserFunction'
  
  LambdaExecutionRoleArn:
    Description: 'Lambda Execution Role ARN'
    Value: !GetAtt LambdaExecutionRole.Arn
    Export:
      Name: !Sub '${AWS::StackName}-LambdaExecutionRole'
  
  ArtifactsBucketName:
    Description: 'S3 Bucket for artifacts'
    Value: !Ref ArtifactsBucket
    Export:
      Name: !Sub '${AWS::StackName}-ArtifactsBucket'
  
  DeadLetterQueueUrl:
    Description: 'Dead Letter Queue URL'
    Value: !Ref DeadLetterQueue
    Export:
      Name: !Sub '${AWS::StackName}-DeadLetterQueue'
```

### ステップ3: API Gateway統合

1. **API Gateway設定**
```yaml
# api-gateway-lambda.yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'API Gateway integration with Lambda functions'

Parameters:
  ProjectName:
    Type: String
    Default: 'lambda-deploy'
  
  EnvironmentName:
    Type: String
    Default: 'dev'
  
  ListUsersFunctionArn:
    Type: String
    Description: 'List Users Lambda Function ARN'
  
  CreateUserFunctionArn:
    Type: String
    Description: 'Create User Lambda Function ARN'

Resources:
  # REST API
  RestApi:
    Type: AWS::ApiGateway::RestApi
    Properties:
      Name: !Sub '${ProjectName}-${EnvironmentName}-api'
      Description: 'REST API for Lambda functions'
      EndpointConfiguration:
        Types:
          - REGIONAL
      BinaryMediaTypes:
        - 'application/json'

  # Users Resource
  UsersResource:
    Type: AWS::ApiGateway::Resource
    Properties:
      RestApiId: !Ref RestApi
      ParentId: !GetAtt RestApi.RootResourceId
      PathPart: users

  # GET /users Method
  GetUsersMethod:
    Type: AWS::ApiGateway::Method
    Properties:
      RestApiId: !Ref RestApi
      ResourceId: !Ref UsersResource
      HttpMethod: GET
      AuthorizationType: NONE
      RequestParameters:
        method.request.querystring.limit: false
        method.request.querystring.lastKey: false
      Integration:
        Type: AWS_PROXY
        IntegrationHttpMethod: POST
        Uri: !Sub 'arn:aws:apigateway:${AWS::Region}:lambda:path/2015-03-31/functions/${ListUsersFunctionArn}/invocations'
        IntegrationResponses:
          - StatusCode: 200
            ResponseParameters:
              method.response.header.Access-Control-Allow-Origin: "'*'"
      MethodResponses:
        - StatusCode: 200
          ResponseParameters:
            method.response.header.Access-Control-Allow-Origin: true

  # POST /users Method
  PostUsersMethod:
    Type: AWS::ApiGateway::Method
    Properties:
      RestApiId: !Ref RestApi
      ResourceId: !Ref UsersResource
      HttpMethod: POST
      AuthorizationType: NONE
      Integration:
        Type: AWS_PROXY
        IntegrationHttpMethod: POST
        Uri: !Sub 'arn:aws:apigateway:${AWS::Region}:lambda:path/2015-03-31/functions/${CreateUserFunctionArn}/invocations'
      MethodResponses:
        - StatusCode: 201
        - StatusCode: 400
        - StatusCode: 409

  # CORS Options Method
  OptionsUsersMethod:
    Type: AWS::ApiGateway::Method
    Properties:
      RestApiId: !Ref RestApi
      ResourceId: !Ref UsersResource
      HttpMethod: OPTIONS
      AuthorizationType: NONE
      Integration:
        Type: MOCK
        IntegrationResponses:
          - StatusCode: 200
            ResponseParameters:
              method.response.header.Access-Control-Allow-Headers: "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
              method.response.header.Access-Control-Allow-Methods: "'GET,POST,OPTIONS'"
              method.response.header.Access-Control-Allow-Origin: "'*'"
        RequestTemplates:
          application/json: '{"statusCode": 200}'
      MethodResponses:
        - StatusCode: 200
          ResponseParameters:
            method.response.header.Access-Control-Allow-Headers: true
            method.response.header.Access-Control-Allow-Methods: true
            method.response.header.Access-Control-Allow-Origin: true

  # API Deployment
  ApiDeployment:
    Type: AWS::ApiGateway::Deployment
    DependsOn:
      - GetUsersMethod
      - PostUsersMethod
      - OptionsUsersMethod
    Properties:
      RestApiId: !Ref RestApi
      StageName: !Ref EnvironmentName
      StageDescription:
        Description: !Sub '${EnvironmentName} stage'
        MethodSettings:
          - ResourcePath: '/*'
            HttpMethod: '*'
            LoggingLevel: INFO
            DataTraceEnabled: true
            MetricsEnabled: true
            ThrottlingRateLimit: 1000
            ThrottlingBurstLimit: 2000

  # Lambda Permissions
  ListUsersLambdaPermission:
    Type: AWS::Lambda::Permission
    Properties:
      FunctionName: !Ref ListUsersFunctionArn
      Action: lambda:InvokeFunction
      Principal: apigateway.amazonaws.com
      SourceArn: !Sub '${RestApi}/*/GET/users'

  CreateUserLambdaPermission:
    Type: AWS::Lambda::Permission
    Properties:
      FunctionName: !Ref CreateUserFunctionArn
      Action: lambda:InvokeFunction
      Principal: apigateway.amazonaws.com
      SourceArn: !Sub '${RestApi}/*/POST/users'

  # Usage Plan
  ApiUsagePlan:
    Type: AWS::ApiGateway::UsagePlan
    Properties:
      UsagePlanName: !Sub '${ProjectName}-${EnvironmentName}-usage-plan'
      Description: 'Usage plan for Lambda API'
      ApiStages:
        - ApiId: !Ref RestApi
          Stage: !Ref EnvironmentName
      Throttle:
        RateLimit: 1000
        BurstLimit: 2000
      Quota:
        Limit: 100000
        Period: DAY

Outputs:
  ApiUrl:
    Description: 'API Gateway endpoint URL'
    Value: !Sub 'https://${RestApi}.execute-api.${AWS::Region}.amazonaws.com/${EnvironmentName}'
    Export:
      Name: !Sub '${AWS::StackName}-ApiUrl'
  
  RestApiId:
    Description: 'REST API ID'
    Value: !Ref RestApi
    Export:
      Name: !Sub '${AWS::StackName}-RestApiId'
```

### ステップ4: デプロイスクリプト

1. **デプロイ自動化スクリプト**
```bash
#!/bin/bash
# scripts/deploy.sh

set -e

PROJECT_NAME="lambda-deploy"
ENVIRONMENT="dev"
REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "Deploying Lambda functions..."

# S3バケット作成（まだ存在しない場合）
BUCKET_NAME="${PROJECT_NAME}-${ENVIRONMENT}-artifacts-${ACCOUNT_ID}-${REGION}"
aws s3 mb s3://${BUCKET_NAME} --region ${REGION} 2>/dev/null || true

# Lambda関数のパッケージ作成
echo "Packaging Lambda functions..."

# Python関数のパッケージ
cd src/lambda/users
zip -r ../../../list-users.zip list_users.py
cd ../../../

# Node.js関数のパッケージ
cd src/lambda/users
npm install
zip -r ../../../create-user.zip create_user.js node_modules/
cd ../../../

# S3にアップロード
echo "Uploading packages to S3..."
aws s3 cp list-users.zip s3://${BUCKET_NAME}/functions/
aws s3 cp create-user.zip s3://${BUCKET_NAME}/functions/

# CloudFormationスタックのデプロイ
echo "Deploying CloudFormation stacks..."

# Lambda関数スタック
aws cloudformation deploy \
  --template-file cloudformation/lambda-functions.yaml \
  --stack-name ${PROJECT_NAME}-${ENVIRONMENT}-lambda \
  --parameter-overrides \
    ProjectName=${PROJECT_NAME} \
    EnvironmentName=${ENVIRONMENT} \
    UsersTableName=${PROJECT_NAME}-${ENVIRONMENT}-users \
  --capabilities CAPABILITY_NAMED_IAM \
  --region ${REGION}

# Lambda関数ARNを取得
LIST_USERS_ARN=$(aws cloudformation describe-stacks \
  --stack-name ${PROJECT_NAME}-${ENVIRONMENT}-lambda \
  --query 'Stacks[0].Outputs[?OutputKey==`ListUsersFunctionArn`].OutputValue' \
  --output text)

CREATE_USER_ARN=$(aws cloudformation describe-stacks \
  --stack-name ${PROJECT_NAME}-${ENVIRONMENT}-lambda \
  --query 'Stacks[0].Outputs[?OutputKey==`CreateUserFunctionArn`].OutputValue' \
  --output text)

# API Gatewayスタック
aws cloudformation deploy \
  --template-file cloudformation/api-gateway-lambda.yaml \
  --stack-name ${PROJECT_NAME}-${ENVIRONMENT}-api \
  --parameter-overrides \
    ProjectName=${PROJECT_NAME} \
    EnvironmentName=${ENVIRONMENT} \
    ListUsersFunctionArn=${LIST_USERS_ARN} \
    CreateUserFunctionArn=${CREATE_USER_ARN} \
  --region ${REGION}

# API URLを取得して表示
API_URL=$(aws cloudformation describe-stacks \
  --stack-name ${PROJECT_NAME}-${ENVIRONMENT}-api \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiUrl`].OutputValue' \
  --output text)

echo "Deployment completed!"
echo "API URL: ${API_URL}"
echo "Test endpoints:"
echo "  GET ${API_URL}/users"
echo "  POST ${API_URL}/users"

# クリーンアップ
rm -f list-users.zip create-user.zip

echo "You can test the API using:"
echo "curl ${API_URL}/users"
```

## 検証方法

### 1. Lambda関数の動作確認
```bash
# 直接呼び出しテスト
aws lambda invoke \
  --function-name lambda-deploy-dev-list-users \
  --payload '{}' \
  response.json

# レスポンス確認
cat response.json
```

### 2. API Gateway経由のテスト
```bash
# ユーザー一覧取得
curl -X GET https://api-id.execute-api.us-east-1.amazonaws.com/dev/users

# ユーザー作成
curl -X POST https://api-id.execute-api.us-east-1.amazonaws.com/dev/users \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "name": "Test User",
    "phone": "090-1234-5678"
  }'
```

### 3. CloudWatchログの確認
```bash
# ログストリーム確認
aws logs describe-log-streams \
  --log-group-name /aws/lambda/lambda-deploy-dev-list-users

# ログイベント取得
aws logs get-log-events \
  --log-group-name /aws/lambda/lambda-deploy-dev-list-users \
  --log-stream-name <log-stream-name>
```

## トラブルシューティング

### よくある問題と解決策

#### 1. Lambda関数がタイムアウト
**症状**: Task timed out after X seconds
**解決策**:
- タイムアウト値の調整
- DynamoDB接続プールの最適化
- 不要な処理の削除

#### 2. API GatewayのCORSエラー
**症状**: CORS policy エラー
**解決策**:
```yaml
# 適切なCORSヘッダーの設定
ResponseParameters:
  method.response.header.Access-Control-Allow-Origin: "'*'"
  method.response.header.Access-Control-Allow-Methods: "'GET,POST,OPTIONS'"
  method.response.header.Access-Control-Allow-Headers: "'Content-Type,Authorization'"
```

#### 3. DynamoDB権限エラー
**症状**: AccessDeniedException
**解決策**:
- IAMロールの権限確認
- リソースARNの正確性確認
- CloudTrailでのAPI呼び出し詳細確認

## 学習リソース

### AWS公式ドキュメント
- [AWS Lambda 開発者ガイド](https://docs.aws.amazon.com/lambda/latest/dg/)
- [Amazon API Gateway 開発者ガイド](https://docs.aws.amazon.com/apigateway/latest/developerguide/)
- [Lambda ベストプラクティス](https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html)

### 追加学習教材
- [Serverless Application Lens](https://docs.aws.amazon.com/wellarchitected/latest/serverless-applications-lens/)
- [AWS SAM (Serverless Application Model)](https://docs.aws.amazon.com/serverless-application-model/)

## セキュリティとコストの考慮事項

### セキュリティベストプラクティス
1. **最小権限IAMロール**: 必要最小限の権限のみ付与
2. **環境変数の暗号化**: 機密情報の適切な管理
3. **API認証**: Cognitoやカスタム認証の実装
4. **ログの適切な管理**: 機密情報のログ出力回避

### コスト最適化
1. **適切なメモリ配分**: パフォーマンスとコストのバランス
2. **Provisioned Concurrency**: 予測可能な負荷での利用
3. **デッドレターキュー**: 失敗したリクエストの適切な処理
4. **ログ保持期間**: CloudWatch Logsの適切な設定

### AWS Well-Architectedフレームワークとの関連
- **運用性の柱**: CloudWatchによる監視とX-Rayトレーシング
- **セキュリティの柱**: IAMロールと VPC Lambda
- **信頼性の柱**: Dead Letter Queue とエラーハンドリング
- **パフォーマンス効率の柱**: 適切なメモリ・タイムアウト設定
- **コスト最適化の柱**: 従量課金とリソース最適化

## 次のステップ

### 推奨される学習パス
1. **2.2.1 REST-API**: より複雑なAPI構築
2. **3.1.2 データ操作API**: データベース操作の高度化
3. **5.1.2 テキスト生成実装**: AI機能との統合
4. **6.1.1 マルチステージビルド**: サーバーレスCI/CD

### 発展的な機能
1. **AWS SAM**: Infrastructure as Codeの高度化
2. **Step Functions**: ワークフロー管理
3. **EventBridge**: イベント駆動アーキテクチャ
4. **Lambda Extensions**: 監視・セキュリティ機能の拡張

### 実践プロジェクトのアイデア
1. **サーバーレスWebアプリケーション**: フルスタック構成
2. **データ処理パイプライン**: S3トリガーによるETL
3. **チャットボット**: Slack/Discord連携
4. **IoTデータ処理**: リアルタイムデータ分析