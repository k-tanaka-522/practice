# 2.2.1 REST API

## 学習目標

このセクションでは、AWS Lambda、API Gateway、DynamoDBを使用して、スケーラブルでセキュアなREST APIを構築する方法を習得します。

### 習得できるスキル
- RESTful APIの設計原則とベストプラクティス
- AWS API Gatewayによるエンドポイント管理
- Lambda関数を使用したサーバーレスAPI実装
- DynamoDBを使用した高パフォーマンスデータストレージ
- APIセキュリティ（認証・認可）の実装
- CORS設定とエラーハンドリング
- API版数管理とデプロイメント戦略

## 前提知識

### 必須の知識
- HTTPプロトコルとREST原則の理解
- JSONデータ形式の操作
- AWS Lambda の基礎（1.2.3セクション完了）
- DynamoDBの基本概念
- IAMロールとポリシーの理解

### あると望ましい知識
- Python或いはNode.jsの基礎プログラミング
- OpenAPI（Swagger）仕様
- データベース設計の基礎
- 認証・認可の仕組み（JWT、OAuth等）

## アーキテクチャ概要

### REST APIアーキテクチャ

```
┌─────────────────────────────────────────────────────────────┐
│                      Frontend Applications                  │
│                                                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
│  │   Web App       │  │   Mobile App    │  │   Third     │ │
│  │   (React)       │  │   (React       │  │   Party     │ │
│  │                 │  │    Native)      │  │   Apps      │ │
│  └─────────────────┘  └─────────────────┘  └─────────────┘ │
└────────────────────────┬────────────────────────────────────┘
                         │ HTTPS Requests
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                    Amazon API Gateway                       │
│                                                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
│  │    Authorizer   │  │     CORS        │  │    Rate     │ │
│  │   (Cognito/     │  │   Configuration │  │   Limiting  │ │
│  │    Lambda)      │  │                 │  │             │ │
│  └─────────────────┘  └─────────────────┘  └─────────────┘ │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              API Resources & Methods                    │ │
│  │  GET /users  POST /users  PUT /users/{id}  DELETE...   │ │
│  └─────────────────────────────────────────────────────────┘ │
└────────────────────────┬────────────────────────────────────┘
                         │ Lambda Proxy Integration
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                     AWS Lambda Functions                    │
│                                                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
│  │   User Service  │  │  Product Service│  │   Order     │ │
│  │   Functions     │  │   Functions     │  │  Service    │ │
│  │                 │  │                 │  │ Functions   │ │
│  │  • Create User  │  │  • List Products│  │ • Create    │ │
│  │  • Get User     │  │  • Get Product  │  │ • Update    │ │
│  │  • Update User  │  │  • Update Price │  │ • Delete    │ │
│  │  • Delete User  │  │  • Delete       │  │ • Get Orders│ │
│  └─────────────────┘  └─────────────────┘  └─────────────┘ │
└────────────────────────┬────────────────────────────────────┘
                         │ DynamoDB SDK
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                      Amazon DynamoDB                        │
│                                                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
│  │    Users        │  │    Products     │  │    Orders   │ │
│  │    Table        │  │     Table       │  │    Table    │ │
│  │                 │  │                 │  │             │ │
│  │ PK: user_id     │  │ PK: product_id  │  │ PK: order_id│ │
│  │ SK: profile     │  │ SK: category    │  │ SK: item_id │ │
│  └─────────────────┘  └─────────────────┘  └─────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### 主要コンポーネント
- **API Gateway**: RESTエンドポイントの管理とルーティング
- **Lambda Functions**: ビジネスロジックの実装
- **DynamoDB**: NoSQLデータベースによる高速データアクセス
- **IAM**: セキュリティとアクセス制御
- **CloudWatch**: ログ管理とモニタリング

## ハンズオン手順

### ステップ1: DynamoDBテーブルの設計と作成

1. **テーブル設計の検討**
```yaml
# dynamodb-tables.yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'DynamoDB tables for REST API'

Parameters:
  ProjectName:
    Type: String
    Default: 'REST-API-Demo'

Resources:
  # Users Table
  UsersTable:
    Type: AWS::DynamoDB::Table
    Properties:
      TableName: !Sub '${ProjectName}-Users'
      BillingMode: PAY_PER_REQUEST
      AttributeDefinitions:
        - AttributeName: user_id
          AttributeType: S
        - AttributeName: email
          AttributeType: S
        - AttributeName: created_at
          AttributeType: S
      KeySchema:
        - AttributeName: user_id
          KeyType: HASH
      GlobalSecondaryIndexes:
        - IndexName: EmailIndex
          KeySchema:
            - AttributeName: email
              KeyType: HASH
          Projection:
            ProjectionType: ALL
        - IndexName: CreatedAtIndex
          KeySchema:
            - AttributeName: created_at
              KeyType: HASH
          Projection:
            ProjectionType: ALL
      StreamSpecification:
        StreamViewType: NEW_AND_OLD_IMAGES
      Tags:
        - Key: Project
          Value: !Ref ProjectName

  # Products Table
  ProductsTable:
    Type: AWS::DynamoDB::Table
    Properties:
      TableName: !Sub '${ProjectName}-Products'
      BillingMode: PAY_PER_REQUEST
      AttributeDefinitions:
        - AttributeName: product_id
          AttributeType: S
        - AttributeName: category
          AttributeType: S
        - AttributeName: price
          AttributeType: N
      KeySchema:
        - AttributeName: product_id
          KeyType: HASH
      GlobalSecondaryIndexes:
        - IndexName: CategoryIndex
          KeySchema:
            - AttributeName: category
              KeyType: HASH
            - AttributeName: price
              KeyType: RANGE
          Projection:
            ProjectionType: ALL
      Tags:
        - Key: Project
          Value: !Ref ProjectName

  # Orders Table
  OrdersTable:
    Type: AWS::DynamoDB::Table
    Properties:
      TableName: !Sub '${ProjectName}-Orders'
      BillingMode: PAY_PER_REQUEST
      AttributeDefinitions:
        - AttributeName: order_id
          AttributeType: S
        - AttributeName: user_id
          AttributeType: S
        - AttributeName: created_at
          AttributeType: S
      KeySchema:
        - AttributeName: order_id
          KeyType: HASH
      GlobalSecondaryIndexes:
        - IndexName: UserOrdersIndex
          KeySchema:
            - AttributeName: user_id
              KeyType: HASH
            - AttributeName: created_at
              KeyType: RANGE
          Projection:
            ProjectionType: ALL
      Tags:
        - Key: Project
          Value: !Ref ProjectName
```

2. **テーブルのデプロイ**
```bash
cd /mnt/c/dev2/practice/02-Web三層アーキテクチャ編/2.2-アプリケーション層/2.2.1-REST-API/cloudformation

aws cloudformation create-stack \
  --stack-name rest-api-dynamodb \
  --template-body file://dynamodb-tables.yaml \
  --parameters ParameterKey=ProjectName,ParameterValue=REST-API-Demo
```

### ステップ2: Lambda関数の実装

1. **共通ライブラリの作成**
```python
# api/src/common/response.py
import json
from typing import Dict, Any, Optional

def create_response(
    status_code: int,
    body: Dict[str, Any],
    headers: Optional[Dict[str, str]] = None
) -> Dict[str, Any]:
    """統一されたAPIレスポンス形式を作成"""
    default_headers = {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
        'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
    }
    
    if headers:
        default_headers.update(headers)
    
    return {
        'statusCode': status_code,
        'headers': default_headers,
        'body': json.dumps(body, ensure_ascii=False, default=str)
    }

def success_response(data: Any = None, message: str = 'Success') -> Dict[str, Any]:
    """成功レスポンス"""
    body = {'success': True, 'message': message}
    if data is not None:
        body['data'] = data
    return create_response(200, body)

def error_response(
    status_code: int,
    message: str,
    error_code: Optional[str] = None
) -> Dict[str, Any]:
    """エラーレスポンス"""
    body = {
        'success': False,
        'message': message
    }
    if error_code:
        body['error_code'] = error_code
    
    return create_response(status_code, body)

def validation_error_response(errors: Dict[str, str]) -> Dict[str, Any]:
    """バリデーションエラーレスポンス"""
    return create_response(400, {
        'success': False,
        'message': 'Validation failed',
        'errors': errors
    })
```

2. **データベースアクセスレイヤー**
```python
# api/src/common/database.py
import boto3
import uuid
from datetime import datetime
from typing import Dict, List, Optional, Any
from botocore.exceptions import ClientError

class DynamoDBService:
    def __init__(self, region_name: str = 'us-east-1'):
        self.dynamodb = boto3.resource('dynamodb', region_name=region_name)
    
    def get_table(self, table_name: str):
        """DynamoDBテーブルを取得"""
        return self.dynamodb.Table(table_name)
    
    def create_item(self, table_name: str, item: Dict[str, Any]) -> Dict[str, Any]:
        """アイテムを作成"""
        table = self.get_table(table_name)
        
        # 共通フィールドの追加
        item['created_at'] = datetime.now().isoformat()
        item['updated_at'] = datetime.now().isoformat()
        
        try:
            table.put_item(Item=item)
            return item
        except ClientError as e:
            raise Exception(f"Failed to create item: {str(e)}")
    
    def get_item(self, table_name: str, key: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """アイテムを取得"""
        table = self.get_table(table_name)
        
        try:
            response = table.get_item(Key=key)
            return response.get('Item')
        except ClientError as e:
            raise Exception(f"Failed to get item: {str(e)}")
    
    def update_item(
        self,
        table_name: str,
        key: Dict[str, Any],
        update_expression: str,
        expression_attribute_values: Dict[str, Any],
        expression_attribute_names: Optional[Dict[str, str]] = None
    ) -> Dict[str, Any]:
        """アイテムを更新"""
        table = self.get_table(table_name)
        
        # updated_atを追加
        update_expression += ', updated_at = :updated_at'
        expression_attribute_values[':updated_at'] = datetime.now().isoformat()
        
        try:
            response = table.update_item(
                Key=key,
                UpdateExpression=update_expression,
                ExpressionAttributeValues=expression_attribute_values,
                ExpressionAttributeNames=expression_attribute_names,
                ReturnValues='ALL_NEW'
            )
            return response['Attributes']
        except ClientError as e:
            raise Exception(f"Failed to update item: {str(e)}")
    
    def delete_item(self, table_name: str, key: Dict[str, Any]) -> bool:
        """アイテムを削除"""
        table = self.get_table(table_name)
        
        try:
            table.delete_item(Key=key)
            return True
        except ClientError as e:
            raise Exception(f"Failed to delete item: {str(e)}")
    
    def query_items(
        self,
        table_name: str,
        key_condition_expression: str,
        expression_attribute_values: Dict[str, Any],
        index_name: Optional[str] = None,
        limit: Optional[int] = None
    ) -> List[Dict[str, Any]]:
        """アイテムをクエリ"""
        table = self.get_table(table_name)
        
        query_params = {
            'KeyConditionExpression': key_condition_expression,
            'ExpressionAttributeValues': expression_attribute_values
        }
        
        if index_name:
            query_params['IndexName'] = index_name
        if limit:
            query_params['Limit'] = limit
        
        try:
            response = table.query(**query_params)
            return response['Items']
        except ClientError as e:
            raise Exception(f"Failed to query items: {str(e)}")
    
    def scan_items(
        self,
        table_name: str,
        filter_expression: Optional[str] = None,
        expression_attribute_values: Optional[Dict[str, Any]] = None,
        limit: Optional[int] = None
    ) -> List[Dict[str, Any]]:
        """アイテムをスキャン"""
        table = self.get_table(table_name)
        
        scan_params = {}
        if filter_expression:
            scan_params['FilterExpression'] = filter_expression
        if expression_attribute_values:
            scan_params['ExpressionAttributeValues'] = expression_attribute_values
        if limit:
            scan_params['Limit'] = limit
        
        try:
            response = table.scan(**scan_params)
            return response['Items']
        except ClientError as e:
            raise Exception(f"Failed to scan items: {str(e)}")
```

3. **ユーザー管理API実装**
```python
# api/src/users/handler.py
import json
import uuid
import os
from typing import Dict, Any
from common.response import success_response, error_response, validation_error_response
from common.database import DynamoDBService

# 環境変数
USERS_TABLE = os.environ.get('USERS_TABLE', 'REST-API-Demo-Users')

# DynamoDBサービス
db = DynamoDBService()

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """ユーザー管理APIのメインハンドラー"""
    try:
        http_method = event['httpMethod']
        path_parameters = event.get('pathParameters') or {}
        query_parameters = event.get('queryStringParameters') or {}
        body = json.loads(event.get('body', '{}')) if event.get('body') else {}
        
        # ルーティング
        if http_method == 'GET':
            if 'user_id' in path_parameters:
                return get_user(path_parameters['user_id'])
            else:
                return list_users(query_parameters)
        elif http_method == 'POST':
            return create_user(body)
        elif http_method == 'PUT':
            return update_user(path_parameters['user_id'], body)
        elif http_method == 'DELETE':
            return delete_user(path_parameters['user_id'])
        else:
            return error_response(405, 'Method not allowed')
            
    except Exception as e:
        print(f"Error: {str(e)}")
        return error_response(500, 'Internal server error')

def create_user(user_data: Dict[str, Any]) -> Dict[str, Any]:
    """ユーザー作成"""
    # バリデーション
    validation_errors = validate_user_data(user_data)
    if validation_errors:
        return validation_error_response(validation_errors)
    
    try:
        # メールアドレスの重複チェック
        existing_users = db.query_items(
            USERS_TABLE,
            'email = :email',
            {':email': user_data['email']},
            index_name='EmailIndex'
        )
        
        if existing_users:
            return error_response(409, 'Email already exists')
        
        # ユーザー作成
        user_id = str(uuid.uuid4())
        user_item = {
            'user_id': user_id,
            'email': user_data['email'],
            'name': user_data['name'],
            'status': 'active'
        }
        
        if 'phone' in user_data:
            user_item['phone'] = user_data['phone']
        if 'address' in user_data:
            user_item['address'] = user_data['address']
        
        created_user = db.create_item(USERS_TABLE, user_item)
        
        return success_response(
            data=created_user,
            message='User created successfully'
        )
        
    except Exception as e:
        print(f"Create user error: {str(e)}")
        return error_response(500, 'Failed to create user')

def get_user(user_id: str) -> Dict[str, Any]:
    """ユーザー取得"""
    try:
        user = db.get_item(USERS_TABLE, {'user_id': user_id})
        
        if not user:
            return error_response(404, 'User not found')
        
        return success_response(data=user)
        
    except Exception as e:
        print(f"Get user error: {str(e)}")
        return error_response(500, 'Failed to get user')

def list_users(query_params: Dict[str, str]) -> Dict[str, Any]:
    """ユーザー一覧取得"""
    try:
        limit = int(query_params.get('limit', 50))
        limit = min(limit, 100)  # 最大100件
        
        users = db.scan_items(USERS_TABLE, limit=limit)
        
        return success_response(
            data={
                'users': users,
                'count': len(users)
            }
        )
        
    except Exception as e:
        print(f"List users error: {str(e)}")
        return error_response(500, 'Failed to list users')

def update_user(user_id: str, update_data: Dict[str, Any]) -> Dict[str, Any]:
    """ユーザー更新"""
    try:
        # ユーザー存在確認
        existing_user = db.get_item(USERS_TABLE, {'user_id': user_id})
        if not existing_user:
            return error_response(404, 'User not found')
        
        # 更新可能フィールドの検証
        allowed_fields = ['name', 'phone', 'address', 'status']
        update_expression_parts = []
        expression_attribute_values = {}
        
        for field, value in update_data.items():
            if field in allowed_fields and value is not None:
                update_expression_parts.append(f'{field} = :{field}')
                expression_attribute_values[f':{field}'] = value
        
        if not update_expression_parts:
            return error_response(400, 'No valid fields to update')
        
        update_expression = 'SET ' + ', '.join(update_expression_parts)
        
        updated_user = db.update_item(
            USERS_TABLE,
            {'user_id': user_id},
            update_expression,
            expression_attribute_values
        )
        
        return success_response(
            data=updated_user,
            message='User updated successfully'
        )
        
    except Exception as e:
        print(f"Update user error: {str(e)}")
        return error_response(500, 'Failed to update user')

def delete_user(user_id: str) -> Dict[str, Any]:
    """ユーザー削除"""
    try:
        # ユーザー存在確認
        existing_user = db.get_item(USERS_TABLE, {'user_id': user_id})
        if not existing_user:
            return error_response(404, 'User not found')
        
        # 論理削除（status を deleted に変更）
        updated_user = db.update_item(
            USERS_TABLE,
            {'user_id': user_id},
            'SET #status = :status',
            {':status': 'deleted'},
            {'#status': 'status'}
        )
        
        return success_response(message='User deleted successfully')
        
    except Exception as e:
        print(f"Delete user error: {str(e)}")
        return error_response(500, 'Failed to delete user')

def validate_user_data(user_data: Dict[str, Any]) -> Dict[str, str]:
    """ユーザーデータのバリデーション"""
    errors = {}
    
    # 必須フィールドチェック
    required_fields = ['email', 'name']
    for field in required_fields:
        if not user_data.get(field):
            errors[field] = f'{field} is required'
    
    # メールアドレス形式チェック
    email = user_data.get('email', '')
    if email and '@' not in email:
        errors['email'] = 'Invalid email format'
    
    # 名前の長さチェック
    name = user_data.get('name', '')
    if name and (len(name) < 2 or len(name) > 50):
        errors['name'] = 'Name must be between 2 and 50 characters'
    
    return errors
```

### ステップ3: API Gatewayの設定

1. **API Gatewayの構築**
```yaml
# api-gateway.yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'REST API Gateway configuration'

Parameters:
  ProjectName:
    Type: String
    Default: 'REST-API-Demo'
  
  LambdaFunctionArn:
    Type: String
    Description: 'Lambda function ARN for API backend'

Resources:
  # REST API
  RestApi:
    Type: AWS::ApiGateway::RestApi
    Properties:
      Name: !Sub '${ProjectName}-API'
      Description: 'REST API for demo application'
      EndpointConfiguration:
        Types:
          - REGIONAL
      Policy:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal: '*'
            Action: execute-api:Invoke
            Resource: '*'

  # API Gateway Request Validator
  RequestValidator:
    Type: AWS::ApiGateway::RequestValidator
    Properties:
      RestApiId: !Ref RestApi
      Name: 'Validate body and parameters'
      ValidateRequestBody: true
      ValidateRequestParameters: true

  # Users Resource
  UsersResource:
    Type: AWS::ApiGateway::Resource
    Properties:
      RestApiId: !Ref RestApi
      ParentId: !GetAtt RestApi.RootResourceId
      PathPart: users

  UserIdResource:
    Type: AWS::ApiGateway::Resource
    Properties:
      RestApiId: !Ref RestApi
      ParentId: !Ref UsersResource
      PathPart: '{user_id}'

  # GET /users - List Users
  UsersGetMethod:
    Type: AWS::ApiGateway::Method
    Properties:
      RestApiId: !Ref RestApi
      ResourceId: !Ref UsersResource
      HttpMethod: GET
      AuthorizationType: NONE
      RequestParameters:
        method.request.querystring.limit: false
      Integration:
        Type: AWS_PROXY
        IntegrationHttpMethod: POST
        Uri: !Sub 'arn:aws:apigateway:${AWS::Region}:lambda:path/2015-03-31/functions/${LambdaFunctionArn}/invocations'
      MethodResponses:
        - StatusCode: 200
          ResponseModels:
            application/json: Empty
          ResponseParameters:
            method.response.header.Access-Control-Allow-Origin: true

  # POST /users - Create User
  UsersPostMethod:
    Type: AWS::ApiGateway::Method
    Properties:
      RestApiId: !Ref RestApi
      ResourceId: !Ref UsersResource
      HttpMethod: POST
      AuthorizationType: NONE
      RequestValidator: !Ref RequestValidator
      RequestModels:
        application/json: !Ref UserCreateModel
      Integration:
        Type: AWS_PROXY
        IntegrationHttpMethod: POST
        Uri: !Sub 'arn:aws:apigateway:${AWS::Region}:lambda:path/2015-03-31/functions/${LambdaFunctionArn}/invocations'
      MethodResponses:
        - StatusCode: 201
          ResponseModels:
            application/json: Empty
        - StatusCode: 400
          ResponseModels:
            application/json: Empty

  # GET /users/{user_id} - Get User
  UserGetMethod:
    Type: AWS::ApiGateway::Method
    Properties:
      RestApiId: !Ref RestApi
      ResourceId: !Ref UserIdResource
      HttpMethod: GET
      AuthorizationType: NONE
      RequestParameters:
        method.request.path.user_id: true
      Integration:
        Type: AWS_PROXY
        IntegrationHttpMethod: POST
        Uri: !Sub 'arn:aws:apigateway:${AWS::Region}:lambda:path/2015-03-31/functions/${LambdaFunctionArn}/invocations'
      MethodResponses:
        - StatusCode: 200
        - StatusCode: 404

  # PUT /users/{user_id} - Update User
  UserPutMethod:
    Type: AWS::ApiGateway::Method
    Properties:
      RestApiId: !Ref RestApi
      ResourceId: !Ref UserIdResource
      HttpMethod: PUT
      AuthorizationType: NONE
      RequestParameters:
        method.request.path.user_id: true
      RequestValidator: !Ref RequestValidator
      RequestModels:
        application/json: !Ref UserUpdateModel
      Integration:
        Type: AWS_PROXY
        IntegrationHttpMethod: POST
        Uri: !Sub 'arn:aws:apigateway:${AWS::Region}:lambda:path/2015-03-31/functions/${LambdaFunctionArn}/invocations'
      MethodResponses:
        - StatusCode: 200
        - StatusCode: 404

  # DELETE /users/{user_id} - Delete User
  UserDeleteMethod:
    Type: AWS::ApiGateway::Method
    Properties:
      RestApiId: !Ref RestApi
      ResourceId: !Ref UserIdResource
      HttpMethod: DELETE
      AuthorizationType: NONE
      RequestParameters:
        method.request.path.user_id: true
      Integration:
        Type: AWS_PROXY
        IntegrationHttpMethod: POST
        Uri: !Sub 'arn:aws:apigateway:${AWS::Region}:lambda:path/2015-03-31/functions/${LambdaFunctionArn}/invocations'
      MethodResponses:
        - StatusCode: 200
        - StatusCode: 404

  # CORS Options Methods
  UsersOptionsMethod:
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

  UserOptionsMethod:
    Type: AWS::ApiGateway::Method
    Properties:
      RestApiId: !Ref RestApi
      ResourceId: !Ref UserIdResource
      HttpMethod: OPTIONS
      AuthorizationType: NONE
      Integration:
        Type: MOCK
        IntegrationResponses:
          - StatusCode: 200
            ResponseParameters:
              method.response.header.Access-Control-Allow-Headers: "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
              method.response.header.Access-Control-Allow-Methods: "'GET,PUT,DELETE,OPTIONS'"
              method.response.header.Access-Control-Allow-Origin: "'*'"
        RequestTemplates:
          application/json: '{"statusCode": 200}'
      MethodResponses:
        - StatusCode: 200
          ResponseParameters:
            method.response.header.Access-Control-Allow-Headers: true
            method.response.header.Access-Control-Allow-Methods: true
            method.response.header.Access-Control-Allow-Origin: true

  # Request/Response Models
  UserCreateModel:
    Type: AWS::ApiGateway::Model
    Properties:
      RestApiId: !Ref RestApi
      ContentType: application/json
      Name: UserCreateModel
      Schema:
        type: object
        required:
          - email
          - name
        properties:
          email:
            type: string
            format: email
          name:
            type: string
            minLength: 2
            maxLength: 50
          phone:
            type: string
          address:
            type: object
            properties:
              street:
                type: string
              city:
                type: string
              postal_code:
                type: string
              country:
                type: string

  UserUpdateModel:
    Type: AWS::ApiGateway::Model
    Properties:
      RestApiId: !Ref RestApi
      ContentType: application/json
      Name: UserUpdateModel
      Schema:
        type: object
        properties:
          name:
            type: string
            minLength: 2
            maxLength: 50
          phone:
            type: string
          address:
            type: object
          status:
            type: string
            enum: [active, inactive]

  # API Deployment
  ApiDeployment:
    Type: AWS::ApiGateway::Deployment
    DependsOn:
      - UsersGetMethod
      - UsersPostMethod
      - UserGetMethod
      - UserPutMethod
      - UserDeleteMethod
      - UsersOptionsMethod
      - UserOptionsMethod
    Properties:
      RestApiId: !Ref RestApi
      StageName: prod
      StageDescription:
        Description: 'Production stage'
        MethodSettings:
          - ResourcePath: '/*'
            HttpMethod: '*'
            LoggingLevel: INFO
            DataTraceEnabled: true
            MetricsEnabled: true
        Variables:
          environment: production

  # Usage Plan
  ApiUsagePlan:
    Type: AWS::ApiGateway::UsagePlan
    Properties:
      UsagePlanName: !Sub '${ProjectName}-UsagePlan'
      Description: 'Usage plan for REST API'
      ApiStages:
        - ApiId: !Ref RestApi
          Stage: prod
      Throttle:
        RateLimit: 1000
        BurstLimit: 2000
      Quota:
        Limit: 100000
        Period: DAY

Outputs:
  ApiUrl:
    Description: 'API Gateway endpoint URL'
    Value: !Sub 'https://${RestApi}.execute-api.${AWS::Region}.amazonaws.com/prod'
    Export:
      Name: !Sub '${ProjectName}-ApiUrl'

  RestApiId:
    Description: 'REST API ID'
    Value: !Ref RestApi
    Export:
      Name: !Sub '${ProjectName}-RestApiId'
```

### ステップ4: 認証・認可の実装

1. **JWT認証Lambda Authorizer**
```python
# authorizer/jwt_authorizer.py
import json
import jwt
import os
from typing import Dict, Any, Optional

# 環境変数
JWT_SECRET = os.environ.get('JWT_SECRET', 'your-secret-key')
JWT_ALGORITHM = os.environ.get('JWT_ALGORITHM', 'HS256')

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """JWT Lambda Authorizer"""
    try:
        # トークンの抽出
        token = extract_token(event)
        if not token:
            raise Exception('No token provided')
        
        # トークンの検証
        payload = verify_token(token)
        
        # ユーザー情報の取得
        user_id = payload.get('user_id')
        email = payload.get('email')
        
        # ポリシーの生成
        policy = generate_policy(
            user_id,
            'Allow',
            event['methodArn'],
            {
                'user_id': user_id,
                'email': email
            }
        )
        
        return policy
        
    except Exception as e:
        print(f"Authorization failed: {str(e)}")
        # Denyポリシーを返す
        return generate_policy('user', 'Deny', event['methodArn'])

def extract_token(event: Dict[str, Any]) -> Optional[str]:
    """リクエストからJWTトークンを抽出"""
    auth_header = event.get('authorizationToken', '')
    
    if auth_header.startswith('Bearer '):
        return auth_header[7:]  # "Bearer " を除去
    
    return None

def verify_token(token: str) -> Dict[str, Any]:
    """JWTトークンを検証"""
    try:
        payload = jwt.decode(
            token,
            JWT_SECRET,
            algorithms=[JWT_ALGORITHM]
        )
        return payload
    except jwt.ExpiredSignatureError:
        raise Exception('Token has expired')
    except jwt.InvalidTokenError:
        raise Exception('Invalid token')

def generate_policy(
    principal_id: str,
    effect: str,
    resource: str,
    context: Optional[Dict[str, Any]] = None
) -> Dict[str, Any]:
    """IAMポリシーを生成"""
    policy = {
        'principalId': principal_id,
        'policyDocument': {
            'Version': '2012-10-17',
            'Statement': [
                {
                    'Action': 'execute-api:Invoke',
                    'Effect': effect,
                    'Resource': resource
                }
            ]
        }
    }
    
    if context:
        policy['context'] = context
    
    return policy
```

2. **認証トークン生成エンドポイント**
```python
# auth/login.py
import json
import jwt
import hashlib
import hmac
import os
from datetime import datetime, timedelta
from typing import Dict, Any
from common.response import success_response, error_response
from common.database import DynamoDBService

# 環境変数
JWT_SECRET = os.environ.get('JWT_SECRET', 'your-secret-key')
JWT_ALGORITHM = os.environ.get('JWT_ALGORITHM', 'HS256')
USERS_TABLE = os.environ.get('USERS_TABLE', 'REST-API-Demo-Users')

db = DynamoDBService()

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """ログイン処理"""
    try:
        body = json.loads(event.get('body', '{}'))
        email = body.get('email')
        password = body.get('password')
        
        if not email or not password:
            return error_response(400, 'Email and password are required')
        
        # ユーザー認証
        user = authenticate_user(email, password)
        if not user:
            return error_response(401, 'Invalid email or password')
        
        # JWTトークンの生成
        token = generate_jwt_token(user)
        
        return success_response(
            data={
                'access_token': token,
                'token_type': 'Bearer',
                'expires_in': 3600,
                'user': {
                    'user_id': user['user_id'],
                    'email': user['email'],
                    'name': user['name']
                }
            },
            message='Login successful'
        )
        
    except Exception as e:
        print(f"Login error: {str(e)}")
        return error_response(500, 'Login failed')

def authenticate_user(email: str, password: str) -> Optional[Dict[str, Any]]:
    """ユーザー認証"""
    try:
        # メールアドレスでユーザーを検索
        users = db.query_items(
            USERS_TABLE,
            'email = :email',
            {':email': email},
            index_name='EmailIndex'
        )
        
        if not users:
            return None
        
        user = users[0]
        
        # パスワードの検証
        if verify_password(password, user.get('password_hash', '')):
            return user
        
        return None
        
    except Exception as e:
        print(f"Authentication error: {str(e)}")
        return None

def verify_password(password: str, password_hash: str) -> bool:
    """パスワードの検証"""
    # 実際の実装では、より安全なハッシュ化アルゴリズム（bcrypt等）を使用
    expected_hash = hashlib.sha256(password.encode()).hexdigest()
    return hmac.compare_digest(expected_hash, password_hash)

def generate_jwt_token(user: Dict[str, Any]) -> str:
    """JWTトークンの生成"""
    payload = {
        'user_id': user['user_id'],
        'email': user['email'],
        'name': user['name'],
        'exp': datetime.utcnow() + timedelta(hours=1),
        'iat': datetime.utcnow()
    }
    
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)
```

## 検証方法

### 1. API エンドポイントのテスト

1. **ユーザー作成のテスト**
```bash
# POST /users
curl -X POST https://your-api-endpoint/prod/users \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "name": "Test User",
    "phone": "090-1234-5678"
  }'
```

2. **ユーザー取得のテスト**
```bash
# GET /users/{user_id}
curl -X GET https://your-api-endpoint/prod/users/user-id-here

# GET /users (一覧取得)
curl -X GET "https://your-api-endpoint/prod/users?limit=10"
```

3. **ユーザー更新のテスト**
```bash
# PUT /users/{user_id}
curl -X PUT https://your-api-endpoint/prod/users/user-id-here \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Updated Name",
    "status": "active"
  }'
```

4. **認証付きリクエストのテスト**
```bash
# ログイン
TOKEN=$(curl -X POST https://your-api-endpoint/prod/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123"
  }' | jq -r '.data.access_token')

# 認証付きリクエスト
curl -X GET https://your-api-endpoint/prod/users \
  -H "Authorization: Bearer $TOKEN"
```

### 2. 負荷テストとパフォーマンス検証

1. **Apache Benchを使用した負荷テスト**
```bash
# 100並行で1000リクエスト
ab -n 1000 -c 100 -H "Content-Type: application/json" \
  https://your-api-endpoint/prod/users
```

2. **Artillery.jsを使用した高度な負荷テスト**
```yaml
# load-test.yml
config:
  target: 'https://your-api-endpoint/prod'
  phases:
    - duration: 60
      arrivalRate: 10
  defaults:
    headers:
      Content-Type: 'application/json'

scenarios:
  - name: 'User CRUD Operations'
    flow:
      - post:
          url: '/users'
          json:
            email: 'test{{ $randomInt() }}@example.com'
            name: 'Test User {{ $randomInt() }}'
      - get:
          url: '/users'
```

### 3. セキュリティテスト

1. **SQL/NoSQL インジェクション テスト**
```bash
# 不正な入力値でのテスト
curl -X POST https://your-api-endpoint/prod/users \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test'; DROP TABLE users; --@example.com",
    "name": "Malicious Input"
  }'
```

2. **認証バイパステスト**
```bash
# 認証なしでの保護されたリソースアクセス
curl -X GET https://your-api-endpoint/prod/admin/users

# 無効なトークンでのアクセス
curl -X GET https://your-api-endpoint/prod/users \
  -H "Authorization: Bearer invalid-token"
```

## トラブルシューティング

### よくある問題と解決策

#### 1. CORS エラー
**症状**: ブラウザから「CORS policy」エラー
**解決策**:
```yaml
# API Gateway で適切なCORSヘッダーを設定
ResponseParameters:
  method.response.header.Access-Control-Allow-Origin: "'*'"
  method.response.header.Access-Control-Allow-Methods: "'GET,POST,PUT,DELETE,OPTIONS'"
  method.response.header.Access-Control-Allow-Headers: "'Content-Type,Authorization'"
```

#### 2. Lambda Cold Start の遅延
**症状**: 初回リクエストが遅い
**解決策**:
- 予約済み同時実行数の設定
- レスポンス時間の最適化
```python
# 共通の初期化処理を関数外に移動
import boto3

# グローバルスコープで初期化
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('Users')

def lambda_handler(event, context):
    # ハンドラーでは処理のみ実行
    pass
```

#### 3. DynamoDB 読み取り/書き込み容量不足
**症状**: ProvisionedThroughputExceededException
**解決策**:
```yaml
# オンデマンド課金への変更
BillingMode: PAY_PER_REQUEST

# または容量の増加
ProvisionedThroughput:
  ReadCapacityUnits: 10
  WriteCapacityUnits: 10
```

### デバッグのベストプラクティス
```python
# 構造化ログの実装
import logging
import json

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    # リクエスト情報のログ出力
    logger.info(json.dumps({
        'event_type': 'request',
        'http_method': event.get('httpMethod'),
        'path': event.get('path'),
        'query_params': event.get('queryStringParameters'),
        'request_id': context.aws_request_id
    }))
    
    try:
        # 処理...
        result = process_request(event)
        
        # 成功時のログ
        logger.info(json.dumps({
            'event_type': 'response',
            'status': 'success',
            'request_id': context.aws_request_id
        }))
        
        return result
        
    except Exception as e:
        # エラー時のログ
        logger.error(json.dumps({
            'event_type': 'error',
            'error_message': str(e),
            'request_id': context.aws_request_id
        }))
        
        raise
```

## 学習リソース

### AWS公式ドキュメント
- [Amazon API Gateway Developer Guide](https://docs.aws.amazon.com/apigateway/latest/developerguide/)
- [AWS Lambda Developer Guide](https://docs.aws.amazon.com/lambda/latest/dg/)
- [Amazon DynamoDB Developer Guide](https://docs.aws.amazon.com/dynamodb/latest/developerguide/)
- [RESTful API Design Best Practices](https://aws.amazon.com/blogs/compute/)

### 追加学習教材
- [OpenAPI/Swagger Specification](https://swagger.io/specification/)
- [RESTful Web Services](https://restfulapi.net/)
- [HTTP Status Codes Reference](https://developer.mozilla.org/en-US/docs/Web/HTTP/Status)
- [JWT.io - JSON Web Tokens](https://jwt.io/)

### ハンズオンラボ
- [Building a REST API with Lambda](https://aws.amazon.com/getting-started/hands-on/build-serverless-web-app-lambda-apigateway-s3-dynamodb-cognito/)
- [API Gateway Workshop](https://github.com/aws-samples/amazon-api-gateway-url-shortener)

## セキュリティとコストの考慮事項

### セキュリティベストプラクティス
1. **API認証・認可**
   - Lambda Authorizer による JWT 検証
   - IAM ロールベースアクセス制御
   - API キーによるアクセス管理

2. **入力検証**
   - リクエストデータの厳密な検証
   - SQLインジェクション対策
   - XSS防止

3. **データ保護**
   - DynamoDB の暗号化
   - HTTPS 通信の強制
   - ログデータの適切な取り扱い

4. **監査とログ**
   - CloudTrail による API アクセスログ
   - CloudWatch Logs による詳細ログ
   - 異常アクセスの検知

### コスト最適化
1. **DynamoDB 最適化**
   - 適切な読み取り/書き込み容量設定
   - オンデマンド vs プロビジョニング済み
   - データの TTL 設定

2. **Lambda 最適化**
   - メモリ設定の最適化
   - 実行時間の短縮
   - 予約済み同時実行数の適切な設定

3. **API Gateway 最適化**
   - キャッシングの活用
   - レスポンス圧縮
   - 使用量プランによる制御

### AWS Well-Architected フレームワークとの関連
- **運用性の柱**: CloudWatch によるモニタリングとアラート
- **セキュリティの柱**: 多層防御によるセキュリティ実装
- **信頼性の柱**: 障害に強いアーキテクチャ設計
- **パフォーマンス効率の柱**: サーバーレスによる自動スケーリング
- **コスト最適化の柱**: 従量課金によるコスト効率

## 次のステップ

### 推奨される学習パス
1. **2.2.2 GraphQL API**: より柔軟なAPIアーキテクチャの学習
2. **2.3.1 RDSデータベース**: リレーショナルデータベースとの連携
3. **3.1.1 ユーザー管理システム**: 高度な認証・認可システム
4. **6.1.1 マルチステージビルド**: CI/CDパイプラインの構築

### 発展的な機能
1. **API バージョニング**: 下位互換性を保つ API 進化戦略
2. **API ドキュメント自動生成**: OpenAPI 仕様からの自動生成
3. **リアルタイム機能**: WebSocket や Server-Sent Events
4. **API ゲートウェイ**: レート制限、認証、ロードバランシング

### 実践プロジェクトのアイデア
1. **ブログ管理システム**: 記事の CRUD 操作
2. **在庫管理システム**: 商品・在庫の管理
3. **タスク管理アプリ**: プロジェクトとタスクの管理
4. **ソーシャルメディア API**: ユーザー、投稿、フォロー機能