# 3.1.1 ユーザー管理システム

## 学習目標

このセクションでは、Amazon Cognitoを活用したセキュアなユーザー認証・認可システムの構築を学習し、JWT トークン管理、MFA、ソーシャルログイン等の現代的な認証機能を実装します。

### 習得できるスキル
- Amazon Cognito User Pools による認証システム構築
- JWT トークンの検証と管理
- Multi-Factor Authentication (MFA) の実装
- ソーシャルログイン（Google、Facebook）の統合
- カスタム認証フローの設計
- 権限ベースアクセス制御（RBAC）の実装

## 前提知識

### 必須の知識
- HTTP認証の基本概念（Basic、Bearer認証）
- JWT（JSON Web Token）の仕組み
- AWS Lambda の基本操作（1.2.3セクション完了）
- REST API の設計（2.2.1セクション完了）

### あると望ましい知識
- OAuth 2.0 / OpenID Connect の理解
- セキュリティベストプラクティス
- フロントエンド認証フローの経験
- データベース設計（ユーザー情報管理）

## アーキテクチャ概要

### 認証・認可アーキテクチャ

```
                    ┌─────────────────────┐
                    │   Client Apps       │
                    │ (Web/Mobile/SPA)    │
                    │                     │
                    │ ┌─────────────────┐ │
                    │ │  Auth Library   │ │
                    │ │ (Amplify/SDK)   │ │
                    │ └─────────────────┘ │
                    └─────────┬───────────┘
                              │
                    ┌─────────┼───────────┐
                    │         │           │
                    ▼         ▼           ▼
          ┌─────────────────┐ ┌──────────┐ ┌─────────────────┐
          │   CloudFront    │ │API       │ │   Social IdP    │
          │   (Web App)     │ │Gateway   │ │ (Google/FB)     │
          └─────────┬───────┘ └────┬─────┘ └─────────┬───────┘
                    │              │                 │
                    └──────────────┼─────────────────┘
                                   │
                                   ▼
          ┌─────────────────────────────────────────────────────────┐
          │                Amazon Cognito                           │
          │                                                         │
          │  ┌─────────────────────────────────────────────────┐   │
          │  │              User Pools                         │   │
          │  │                                                  │   │
          │  │  ┌─────────────┐  ┌─────────────┐  ┌──────────┐ │   │
          │  │  │   Users     │  │   Groups    │  │   Roles  │ │   │
          │  │  │             │  │             │  │          │ │   │
          │  │  │ ┌─────────┐ │  │ ┌─────────┐ │  │┌────────┐│ │   │
          │  │  │ │User     │ │  │ │Admin    │ │  ││Admin   ││ │   │
          │  │  │ │Manager  │ │  │ │Group    │ │  ││Role    ││ │   │
          │  │  │ │Editor   │ │  │ │Editor   │ │  ││Editor  ││ │   │
          │  │  │ │Viewer   │ │  │ │Group    │ │  ││Role    ││ │   │
          │  │  │ └─────────┘ │  │ └─────────┘ │  │└────────┘│ │   │
          │  │  └─────────────┘  └─────────────┘  └──────────┘ │   │
          │  └─────────────────────────────────────────────────┘   │
          │                                                         │
          │  ┌─────────────────────────────────────────────────┐   │
          │  │           Authentication Flow                   │   │
          │  │                                                  │   │
          │  │  ┌─────────────┐  ┌─────────────┐  ┌──────────┐ │   │
          │  │  │   Sign Up   │  │   Sign In   │  │   MFA    │ │   │
          │  │  │             │  │             │  │          │ │   │
          │  │  │ ┌─────────┐ │  │ ┌─────────┐ │  │┌────────┐│ │   │
          │  │  │ │Email    │ │  │ │Email/   │ │  ││SMS/    ││ │   │
          │  │  │ │Confirm  │ │  │ │Username │ │  ││TOTP/   ││ │   │
          │  │  │ │         │ │  │ │+Password│ │  ││Email   ││ │   │
          │  │  │ └─────────┘ │  │ └─────────┘ │  │└────────┘│ │   │
          │  │  └─────────────┘  └─────────────┘  └──────────┘ │   │
          │  └─────────────────────────────────────────────────┘   │
          └─────────────────────────────────────────────────────────┘
                                   │
                                   ▼
          ┌─────────────────────────────────────────────────────────┐
          │                  Lambda Triggers                        │
          │                                                         │
          │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │
          │  │Pre Sign-up  │  │Post Confirm │  │Pre Auth     │   │
          │  │ Trigger     │  │ Trigger     │  │ Trigger     │   │
          │  │             │  │             │  │             │   │
          │  │┌──────────┐ │  │┌──────────┐ │  │┌──────────┐ │   │
          │  ││Custom    │ │  ││Welcome   │ │  ││Risk      │ │   │
          │  ││Validation│ │  ││Email     │ │  ││Assessment│ │   │
          │  ││          │ │  ││Send      │ │  ││          │ │   │
          │  │└──────────┘ │  │└──────────┘ │  │└──────────┘ │   │
          │  └─────────────┘  └─────────────┘  └─────────────┘   │
          └─────────────────────────────────────────────────────────┘
                                   │
                                   ▼
          ┌─────────────────────────────────────────────────────────┐
          │               Application Backend                       │
          │                                                         │
          │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │
          │  │   Lambda    │  │  DynamoDB   │  │   API GW    │   │
          │  │ (Protected  │  │(User Profiles│  │(JWT Valid.) │   │
          │  │ Resources)  │  │ & Settings) │  │             │   │
          │  └─────────────┘  └─────────────┘  └─────────────┘   │
          └─────────────────────────────────────────────────────────┘
```

### 主要コンポーネント
- **Cognito User Pools**: ユーザー認証サービス
- **Cognito Identity Pools**: 一時的AWS認証情報発行
- **Lambda Triggers**: カスタム認証ロジック
- **API Gateway Authorizer**: JWT トークン検証
- **DynamoDB**: ユーザープロファイル・設定管理
- **SES**: 認証メール送信

## ハンズオン手順

### ステップ1: Cognito User Pool の設定

1. **CloudFormation による Cognito 構築**
```yaml
# cloudformation/cognito-user-management.yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Complete user management system with Cognito'

Parameters:
  ProjectName:
    Type: String
    Default: 'user-management'
  
  EnvironmentName:
    Type: String
    Default: 'dev'
    AllowedValues: [dev, staging, prod]
  
  DomainName:
    Type: String
    Description: 'Domain name for the application'
    Default: 'example.com'

Conditions:
  IsProduction: !Equals [!Ref EnvironmentName, 'prod']

Resources:
  # Cognito User Pool
  UserPool:
    Type: AWS::Cognito::UserPool
    Properties:
      UserPoolName: !Sub '${ProjectName}-${EnvironmentName}-users'
      
      # サインアップ設定
      Policies:
        PasswordPolicy:
          MinimumLength: 8
          RequireLowercase: true
          RequireNumbers: true
          RequireSymbols: true
          RequireUppercase: true
          TemporaryPasswordValidityDays: 7
      
      # 属性設定
      Schema:
        - Name: email
          AttributeDataType: String
          Required: true
          Mutable: true
        - Name: given_name
          AttributeDataType: String
          Required: false
          Mutable: true
        - Name: family_name
          AttributeDataType: String
          Required: false
          Mutable: true
        - Name: phone_number
          AttributeDataType: String
          Required: false
          Mutable: true
        - Name: department
          AttributeDataType: String
          Required: false
          Mutable: true
          DeveloperOnlyAttribute: false
        - Name: role
          AttributeDataType: String
          Required: false
          Mutable: true
          DeveloperOnlyAttribute: false
      
      # サインアップ・サインイン設定
      UsernameAttributes:
        - email
      AutoVerifiedAttributes:
        - email
      AliasAttributes:
        - email
        - preferred_username
      
      # MFA設定
      MfaConfiguration: !If [IsProduction, 'ON', 'OPTIONAL']
      EnabledMfas:
        - SMS_MFA
        - SOFTWARE_TOKEN_MFA
      
      # デバイス記憶設定
      DeviceConfiguration:
        ChallengeRequiredOnNewDevice: true
        DeviceOnlyRememberedOnUserPrompt: false
      
      # メール設定
      EmailConfiguration:
        EmailSendingAccount: COGNITO_DEFAULT
        ReplyToEmailAddress: !Sub 'noreply@${DomainName}'
        SourceArn: !Sub 'arn:aws:ses:${AWS::Region}:${AWS::AccountId}:identity/${DomainName}'
      
      # SMS設定
      SmsConfiguration:
        ExternalId: !Sub '${ProjectName}-${EnvironmentName}-external-id'
        SnsCallerArn: !GetAtt CognitoSMSRole.Arn
      
      # ユーザープール削除保護
      DeletionProtection: !If [IsProduction, 'ACTIVE', 'INACTIVE']
      
      # Lambda Triggers
      LambdaConfig:
        PreSignUp: !GetAtt PreSignUpTrigger.Arn
        PostConfirmation: !GetAtt PostConfirmationTrigger.Arn
        PreAuthentication: !GetAtt PreAuthenticationTrigger.Arn
        PostAuthentication: !GetAtt PostAuthenticationTrigger.Arn
        CreateAuthChallenge: !GetAtt CreateAuthChallengeTrigger.Arn
        DefineAuthChallenge: !GetAtt DefineAuthChallengeTrigger.Arn
        VerifyAuthChallengeResponse: !GetAtt VerifyAuthChallengeTrigger.Arn
      
      # メッセージカスタマイズ
      EmailVerificationMessage: |
        ご登録ありがとうございます。
        以下のコードを入力して、メールアドレスを確認してください: {####}
      EmailVerificationSubject: 'メールアドレスの確認'
      SmsVerificationMessage: '確認コード: {####}'
      
      # アカウント復旧設定
      AccountRecoverySetting:
        RecoveryMechanisms:
          - Name: verified_email
            Priority: 1
          - Name: verified_phone_number
            Priority: 2
      
      # 管理者作成設定
      AdminCreateUserConfig:
        AllowAdminCreateUserOnly: false
        InviteMessageAction: EMAIL
        TemporaryPasswordValidityDays: 7
      
      UserPoolTags:
        Environment: !Ref EnvironmentName
        Project: !Ref ProjectName
  
  # User Pool Domain
  UserPoolDomain:
    Type: AWS::Cognito::UserPoolDomain
    Properties:
      Domain: !Sub '${ProjectName}-${EnvironmentName}-auth'
      UserPoolId: !Ref UserPool
  
  # User Pool Client (Web Application)
  UserPoolWebClient:
    Type: AWS::Cognito::UserPoolClient
    Properties:
      ClientName: !Sub '${ProjectName}-${EnvironmentName}-web-client'
      UserPoolId: !Ref UserPool
      GenerateSecret: false
      RefreshTokenValidity: 30
      AccessTokenValidity: 60
      IdTokenValidity: 60
      TokenValidityUnits:
        AccessToken: minutes
        IdToken: minutes
        RefreshToken: days
      
      # OAuth設定
      AllowedOAuthFlows:
        - code
        - implicit
      AllowedOAuthScopes:
        - email
        - openid
        - profile
        - aws.cognito.signin.user.admin
      AllowedOAuthFlowsUserPoolClient: true
      CallbackURLs:
        - !Sub 'https://${DomainName}/auth/callback'
        - 'http://localhost:3000/auth/callback'
      LogoutURLs:
        - !Sub 'https://${DomainName}/auth/logout'
        - 'http://localhost:3000/auth/logout'
      
      # セキュリティ設定
      PreventUserExistenceErrors: ENABLED
      EnableTokenRevocation: true
      
      # 属性読み書き権限
      ReadAttributes:
        - email
        - email_verified
        - given_name
        - family_name
        - phone_number
        - phone_number_verified
        - custom:department
        - custom:role
      WriteAttributes:
        - email
        - given_name
        - family_name
        - phone_number
        - custom:department
  
  # User Pool Client (Mobile Application)
  UserPoolMobileClient:
    Type: AWS::Cognito::UserPoolClient
    Properties:
      ClientName: !Sub '${ProjectName}-${EnvironmentName}-mobile-client'
      UserPoolId: !Ref UserPool
      GenerateSecret: true
      RefreshTokenValidity: 30
      AccessTokenValidity: 60
      IdTokenValidity: 60
      
      # モバイル専用設定
      AllowedOAuthFlows:
        - code
      AllowedOAuthScopes:
        - email
        - openid
        - profile
      CallbackURLs:
        - !Sub '${ProjectName}://auth/callback'
      LogoutURLs:
        - !Sub '${ProjectName}://auth/logout'
      
      # セキュリティ設定
      PreventUserExistenceErrors: ENABLED
      EnableTokenRevocation: true
      AuthSessionValidity: 3
  
  # Identity Pool (for AWS resource access)
  IdentityPool:
    Type: AWS::Cognito::IdentityPool
    Properties:
      IdentityPoolName: !Sub '${ProjectName}-${EnvironmentName}-identity'
      AllowUnauthenticatedIdentities: false
      CognitoIdentityProviders:
        - ClientId: !Ref UserPoolWebClient
          ProviderName: !GetAtt UserPool.ProviderName
        - ClientId: !Ref UserPoolMobileClient
          ProviderName: !GetAtt UserPool.ProviderName
      
      # ソーシャルログイン設定
      SupportedLoginProviders:
        'accounts.google.com': !Ref GoogleClientId
        'graph.facebook.com': !Ref FacebookAppId
  
  # User Groups
  AdminGroup:
    Type: AWS::Cognito::UserPoolGroup
    Properties:
      GroupName: Administrators
      UserPoolId: !Ref UserPool
      Description: 'System administrators with full access'
      Precedence: 1
      RoleArn: !GetAtt CognitoAdminRole.Arn
  
  EditorGroup:
    Type: AWS::Cognito::UserPoolGroup
    Properties:
      GroupName: Editors
      UserPoolId: !Ref UserPool
      Description: 'Content editors with read/write access'
      Precedence: 2
      RoleArn: !GetAtt CognitoEditorRole.Arn
  
  ViewerGroup:
    Type: AWS::Cognito::UserPoolGroup
    Properties:
      GroupName: Viewers
      UserPoolId: !Ref UserPool
      Description: 'Read-only users'
      Precedence: 3
      RoleArn: !GetAtt CognitoViewerRole.Arn
  
  # Lambda Triggers
  PreSignUpTrigger:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: !Sub '${ProjectName}-${EnvironmentName}-pre-signup'
      Runtime: python3.9
      Handler: index.lambda_handler
      Role: !GetAtt CognitoLambdaRole.Arn
      Code:
        ZipFile: |
          import json
          import re
          import logging
          
          logger = logging.getLogger()
          logger.setLevel(logging.INFO)
          
          def lambda_handler(event, context):
              logger.info(f"Pre-signup event: {json.dumps(event)}")
              
              # メールドメイン検証
              email = event['request']['userAttributes'].get('email', '')
              allowed_domains = ['example.com', 'company.com']  # 許可ドメイン
              
              if email:
                  domain = email.split('@')[1].lower()
                  if domain not in allowed_domains:
                      raise Exception(f"Email domain {domain} is not allowed")
              
              # パスワード強度追加検証
              password = event['request']['password']
              if len(password) < 10:
                  raise Exception("Password must be at least 10 characters long")
              
              # 自動確認設定（管理者承認制の場合）
              event['response']['autoConfirmUser'] = False
              event['response']['autoVerifyEmail'] = True
              
              return event
      Timeout: 30
  
  PostConfirmationTrigger:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: !Sub '${ProjectName}-${EnvironmentName}-post-confirmation'
      Runtime: python3.9
      Handler: index.lambda_handler
      Role: !GetAtt CognitoLambdaRole.Arn
      Environment:
        Variables:
          USER_PROFILE_TABLE: !Ref UserProfileTable
          WELCOME_EMAIL_TOPIC: !Ref WelcomeEmailTopic
      Code:
        ZipFile: |
          import json
          import boto3
          import os
          from datetime import datetime
          
          dynamodb = boto3.resource('dynamodb')
          sns = boto3.client('sns')
          
          def lambda_handler(event, context):
              user_attributes = event['request']['userAttributes']
              user_id = user_attributes['sub']
              
              # ユーザープロファイル作成
              table = dynamodb.Table(os.environ['USER_PROFILE_TABLE'])
              table.put_item(
                  Item={
                      'userId': user_id,
                      'email': user_attributes.get('email'),
                      'firstName': user_attributes.get('given_name', ''),
                      'lastName': user_attributes.get('family_name', ''),
                      'status': 'ACTIVE',
                      'createdAt': datetime.utcnow().isoformat(),
                      'lastLoginAt': None,
                      'preferences': {
                          'emailNotifications': True,
                          'smsNotifications': False
                      }
                  }
              )
              
              # ウェルカムメール送信
              sns.publish(
                  TopicArn=os.environ['WELCOME_EMAIL_TOPIC'],
                  Message=json.dumps({
                      'userId': user_id,
                      'email': user_attributes.get('email'),
                      'firstName': user_attributes.get('given_name', 'User')
                  }),
                  Subject='New User Welcome Email'
              )
              
              return event
      Timeout: 30
  
  # Lambda Permissions
  PreSignUpTriggerPermission:
    Type: AWS::Lambda::Permission
    Properties:
      FunctionName: !Ref PreSignUpTrigger
      Action: lambda:InvokeFunction
      Principal: cognito-idp.amazonaws.com
      SourceArn: !GetAtt UserPool.Arn
  
  PostConfirmationTriggerPermission:
    Type: AWS::Lambda::Permission
    Properties:
      FunctionName: !Ref PostConfirmationTrigger
      Action: lambda:InvokeFunction
      Principal: cognito-idp.amazonaws.com
      SourceArn: !GetAtt UserPool.Arn
  
  # DynamoDB for User Profiles
  UserProfileTable:
    Type: AWS::DynamoDB::Table
    Properties:
      TableName: !Sub '${ProjectName}-${EnvironmentName}-user-profiles'
      BillingMode: PAY_PER_REQUEST
      AttributeDefinitions:
        - AttributeName: userId
          AttributeType: S
        - AttributeName: email
          AttributeType: S
      KeySchema:
        - AttributeName: userId
          KeyType: HASH
      GlobalSecondaryIndexes:
        - IndexName: email-index
          KeySchema:
            - AttributeName: email
              KeyType: HASH
          Projection:
            ProjectionType: ALL
      
      StreamSpecification:
        StreamViewType: NEW_AND_OLD_IMAGES
      
      PointInTimeRecoverySpecification:
        PointInTimeRecoveryEnabled: true
      
      Tags:
        - Key: Environment
          Value: !Ref EnvironmentName
        - Key: Project
          Value: !Ref ProjectName
  
  # SNS Topic for Welcome Emails
  WelcomeEmailTopic:
    Type: AWS::SNS::Topic
    Properties:
      TopicName: !Sub '${ProjectName}-${EnvironmentName}-welcome-emails'
  
  # IAM Roles
  CognitoSMSRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: cognito-idp.amazonaws.com
            Action: sts:AssumeRole
      Policies:
        - PolicyName: SNSPublishPolicy
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - sns:Publish
                Resource: '*'
  
  CognitoLambdaRole:
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
      Policies:
        - PolicyName: DynamoDBUserProfileAccess
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - dynamodb:PutItem
                  - dynamodb:GetItem
                  - dynamodb:UpdateItem
                  - dynamodb:DeleteItem
                Resource: !GetAtt UserProfileTable.Arn
        - PolicyName: SNSPublishPolicy
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - sns:Publish
                Resource: !Ref WelcomeEmailTopic

Outputs:
  UserPoolId:
    Description: 'Cognito User Pool ID'
    Value: !Ref UserPool
    Export:
      Name: !Sub '${AWS::StackName}-UserPoolId'
  
  UserPoolArn:
    Description: 'Cognito User Pool ARN'
    Value: !GetAtt UserPool.Arn
    Export:
      Name: !Sub '${AWS::StackName}-UserPoolArn'
  
  UserPoolWebClientId:
    Description: 'User Pool Web Client ID'
    Value: !Ref UserPoolWebClient
    Export:
      Name: !Sub '${AWS::StackName}-UserPoolWebClientId'
  
  UserPoolMobileClientId:
    Description: 'User Pool Mobile Client ID'
    Value: !Ref UserPoolMobileClient
    Export:
      Name: !Sub '${AWS::StackName}-UserPoolMobileClientId'
  
  IdentityPoolId:
    Description: 'Cognito Identity Pool ID'
    Value: !Ref IdentityPool
    Export:
      Name: !Sub '${AWS::StackName}-IdentityPoolId'
  
  AuthDomain:
    Description: 'Cognito Auth Domain'
    Value: !Sub 'https://${UserPoolDomain}.auth.${AWS::Region}.amazoncognito.com'
    Export:
      Name: !Sub '${AWS::StackName}-AuthDomain'
```

### ステップ2: JWT検証機能の実装

1. **API Gateway JWT Authorizer**
```javascript
// src/auth/jwt-authorizer.js
const jwt = require('jsonwebtoken');
const jwksClient = require('jwks-rsa');

const client = jwksClient({
    jwksUri: `https://cognito-idp.${process.env.AWS_REGION}.amazonaws.com/${process.env.USER_POOL_ID}/.well-known/jwks.json`,
    cache: true,
    cacheMaxAge: 300000, // 5分キャッシュ
    rateLimit: true,
    jwksRequestsPerMinute: 10
});

function getKey(header, callback) {
    client.getSigningKey(header.kid, (err, key) => {
        if (err) {
            return callback(err);
        }
        const signingKey = key.publicKey || key.rsaPublicKey;
        callback(null, signingKey);
    });
}

exports.handler = async (event) => {
    const token = event.authorizationToken;
    
    if (!token) {
        throw new Error('Unauthorized');
    }
    
    // Bearer トークン抽出
    const tokenMatch = token.match(/^Bearer (.+)$/);
    if (!tokenMatch) {
        throw new Error('Invalid token format');
    }
    
    const accessToken = tokenMatch[1];
    
    try {
        // JWT検証
        const decoded = await verifyJWT(accessToken);
        
        // ユーザー情報とグループ情報取得
        const userInfo = await getUserInfo(decoded);
        
        // IAMポリシー生成
        const policy = generatePolicy(decoded.sub, 'Allow', event.methodArn, userInfo);
        
        return policy;
    } catch (error) {
        console.error('JWT verification failed:', error);
        throw new Error('Unauthorized');
    }
};

function verifyJWT(token) {
    return new Promise((resolve, reject) => {
        jwt.verify(token, getKey, {
            audience: process.env.USER_POOL_CLIENT_ID,
            issuer: `https://cognito-idp.${process.env.AWS_REGION}.amazonaws.com/${process.env.USER_POOL_ID}`,
            algorithms: ['RS256']
        }, (err, decoded) => {
            if (err) {
                return reject(err);
            }
            resolve(decoded);
        });
    });
}

async function getUserInfo(decoded) {
    // トークンからユーザー情報抽出
    return {
        userId: decoded.sub,
        username: decoded.username || decoded['cognito:username'],
        email: decoded.email,
        groups: decoded['cognito:groups'] || [],
        roles: decoded['custom:role'] ? [decoded['custom:role']] : [],
        department: decoded['custom:department'],
        emailVerified: decoded.email_verified === 'true'
    };
}

function generatePolicy(principalId, effect, resource, userInfo) {
    const policy = {
        principalId: principalId,
        policyDocument: {
            Version: '2012-10-17',
            Statement: [
                {
                    Action: 'execute-api:Invoke',
                    Effect: effect,
                    Resource: resource
                }
            ]
        },
        context: {
            userId: userInfo.userId,
            username: userInfo.username,
            email: userInfo.email,
            groups: JSON.stringify(userInfo.groups),
            roles: JSON.stringify(userInfo.roles),
            department: userInfo.department || '',
            emailVerified: userInfo.emailVerified.toString()
        }
    };
    
    return policy;
}
```

2. **ロールベースアクセス制御ミドルウェア**
```javascript
// src/auth/rbac-middleware.js
class RBACMiddleware {
    constructor() {
        // 権限定義
        this.permissions = {
            'ADMIN': ['*'],
            'EDITOR': [
                'users:read',
                'users:update',
                'content:read',
                'content:write',
                'content:update'
            ],
            'VIEWER': [
                'users:read',
                'content:read'
            ]
        };
        
        // リソース別権限マッピング
        this.resourcePermissions = {
            'GET:/users': ['users:read'],
            'POST:/users': ['users:create'],
            'PUT:/users/*': ['users:update'],
            'DELETE:/users/*': ['users:delete'],
            'GET:/content': ['content:read'],
            'POST:/content': ['content:write'],
            'PUT:/content/*': ['content:update'],
            'DELETE:/content/*': ['content:delete']
        };
    }
    
    /**
     * 権限チェックミドルウェア
     */
    authorize(requiredPermissions) {
        return (event, context, callback) => {
            try {
                const userContext = this.extractUserContext(event);
                const hasPermission = this.checkPermissions(userContext, requiredPermissions);
                
                if (!hasPermission) {
                    return callback(null, {
                        statusCode: 403,
                        headers: {
                            'Content-Type': 'application/json',
                            'Access-Control-Allow-Origin': '*'
                        },
                        body: JSON.stringify({
                            error: 'Forbidden',
                            message: 'Insufficient permissions'
                        })
                    });
                }
                
                // 権限チェック通過 - 次のハンドラーへ
                return callback(null, event);
            } catch (error) {
                console.error('Authorization error:', error);
                return callback(null, {
                    statusCode: 401,
                    headers: {
                        'Content-Type': 'application/json',
                        'Access-Control-Allow-Origin': '*'
                    },
                    body: JSON.stringify({
                        error: 'Unauthorized',
                        message: 'Invalid authentication'
                    })
                });
            }
        };
    }
    
    extractUserContext(event) {
        const requestContext = event.requestContext;
        const authorizer = requestContext.authorizer;
        
        return {
            userId: authorizer.userId,
            username: authorizer.username,
            email: authorizer.email,
            groups: JSON.parse(authorizer.groups || '[]'),
            roles: JSON.parse(authorizer.roles || '[]'),
            department: authorizer.department,
            emailVerified: authorizer.emailVerified === 'true'
        };
    }
    
    checkPermissions(userContext, requiredPermissions) {
        const userPermissions = this.getUserPermissions(userContext);
        
        // 管理者は全権限
        if (userPermissions.includes('*')) {
            return true;
        }
        
        // 必要な権限がすべて含まれているかチェック
        return requiredPermissions.every(permission => 
            userPermissions.includes(permission)
        );
    }
    
    getUserPermissions(userContext) {
        let allPermissions = [];
        
        // グループベースの権限
        userContext.groups.forEach(group => {
            const groupPermissions = this.permissions[group.toUpperCase()];
            if (groupPermissions) {
                allPermissions.push(...groupPermissions);
            }
        });
        
        // ロールベースの権限
        userContext.roles.forEach(role => {
            const rolePermissions = this.permissions[role.toUpperCase()];
            if (rolePermissions) {
                allPermissions.push(...rolePermissions);
            }
        });
        
        // 重複除去
        return [...new Set(allPermissions)];
    }
    
    /**
     * リソースベース権限チェック
     */
    checkResourcePermission(userContext, httpMethod, resourcePath) {
        const resourceKey = `${httpMethod}:${resourcePath}`;
        const requiredPermissions = this.resourcePermissions[resourceKey];
        
        if (!requiredPermissions) {
            // 定義されていないリソースはデフォルト拒否
            return false;
        }
        
        return this.checkPermissions(userContext, requiredPermissions);
    }
}

module.exports = new RBACMiddleware();
```

### ステップ3: フロントエンド認証統合

1. **React認証コンポーネント**
```jsx
// src/components/Auth/AuthProvider.jsx
import React, { createContext, useContext, useReducer, useEffect } from 'react';
import { Auth } from 'aws-amplify';

const AuthContext = createContext();

const authReducer = (state, action) => {
    switch (action.type) {
        case 'SIGN_IN_START':
            return { ...state, loading: true, error: null };
        case 'SIGN_IN_SUCCESS':
            return { 
                ...state, 
                loading: false, 
                isAuthenticated: true, 
                user: action.payload,
                error: null 
            };
        case 'SIGN_IN_FAILURE':
            return { 
                ...state, 
                loading: false, 
                isAuthenticated: false, 
                user: null,
                error: action.payload 
            };
        case 'SIGN_OUT':
            return { 
                ...state, 
                isAuthenticated: false, 
                user: null, 
                loading: false,
                error: null 
            };
        case 'SET_USER':
            return { 
                ...state, 
                user: action.payload, 
                isAuthenticated: !!action.payload 
            };
        default:
            return state;
    }
};

const initialState = {
    isAuthenticated: false,
    user: null,
    loading: true,
    error: null
};

export const AuthProvider = ({ children }) => {
    const [state, dispatch] = useReducer(authReducer, initialState);
    
    useEffect(() => {
        checkAuthState();
    }, []);
    
    const checkAuthState = async () => {
        try {
            const user = await Auth.currentAuthenticatedUser();
            const session = await Auth.currentSession();
            
            // JWTトークンからユーザー情報抽出
            const idToken = session.getIdToken();
            const payload = idToken.payload;
            
            const userInfo = {
                userId: payload.sub,
                username: payload['cognito:username'],
                email: payload.email,
                firstName: payload.given_name,
                lastName: payload.family_name,
                groups: payload['cognito:groups'] || [],
                roles: payload['custom:role'] ? [payload['custom:role']] : [],
                department: payload['custom:department'],
                emailVerified: payload.email_verified,
                accessToken: session.getAccessToken().getJwtToken(),
                idToken: idToken.getJwtToken(),
                refreshToken: session.getRefreshToken().getToken()
            };
            
            dispatch({ type: 'SET_USER', payload: userInfo });
        } catch (error) {
            console.log('User not authenticated');
            dispatch({ type: 'SIGN_OUT' });
        }
    };
    
    const signIn = async (username, password) => {
        dispatch({ type: 'SIGN_IN_START' });
        try {
            const cognitoUser = await Auth.signIn(username, password);
            
            // MFAチャレンジ処理
            if (cognitoUser.challengeName === 'SMS_MFA' || 
                cognitoUser.challengeName === 'SOFTWARE_TOKEN_MFA') {
                return { 
                    success: false, 
                    challengeName: cognitoUser.challengeName,
                    user: cognitoUser 
                };
            }
            
            await checkAuthState();
            return { success: true };
        } catch (error) {
            dispatch({ type: 'SIGN_IN_FAILURE', payload: error.message });
            return { success: false, error: error.message };
        }
    };
    
    const confirmSignIn = async (user, code, mfaType = 'SMS_MFA') => {
        try {
            const result = await Auth.confirmSignIn(user, code, mfaType);
            await checkAuthState();
            return { success: true };
        } catch (error) {
            dispatch({ type: 'SIGN_IN_FAILURE', payload: error.message });
            return { success: false, error: error.message };
        }
    };
    
    const signUp = async (username, password, attributes) => {
        try {
            const result = await Auth.signUp({
                username,
                password,
                attributes: {
                    email: attributes.email,
                    given_name: attributes.firstName,
                    family_name: attributes.lastName,
                    phone_number: attributes.phoneNumber,
                    'custom:department': attributes.department || '',
                    'custom:role': attributes.role || 'VIEWER'
                }
            });
            
            return { 
                success: true, 
                userSub: result.userSub,
                codeDeliveryDetails: result.codeDeliveryDetails 
            };
        } catch (error) {
            return { success: false, error: error.message };
        }
    };
    
    const confirmSignUp = async (username, code) => {
        try {
            await Auth.confirmSignUp(username, code);
            return { success: true };
        } catch (error) {
            return { success: false, error: error.message };
        }
    };
    
    const signOut = async () => {
        try {
            await Auth.signOut();
            dispatch({ type: 'SIGN_OUT' });
            return { success: true };
        } catch (error) {
            console.error('Sign out error:', error);
            return { success: false, error: error.message };
        }
    };
    
    const forgotPassword = async (username) => {
        try {
            const result = await Auth.forgotPassword(username);
            return { 
                success: true, 
                codeDeliveryDetails: result.CodeDeliveryDetails 
            };
        } catch (error) {
            return { success: false, error: error.message };
        }
    };
    
    const forgotPasswordSubmit = async (username, code, newPassword) => {
        try {
            await Auth.forgotPasswordSubmit(username, code, newPassword);
            return { success: true };
        } catch (error) {
            return { success: false, error: error.message };
        }
    };
    
    const changePassword = async (oldPassword, newPassword) => {
        try {
            const user = await Auth.currentAuthenticatedUser();
            await Auth.changePassword(user, oldPassword, newPassword);
            return { success: true };
        } catch (error) {
            return { success: false, error: error.message };
        }
    };
    
    const updateUserAttributes = async (attributes) => {
        try {
            const user = await Auth.currentAuthenticatedUser();
            await Auth.updateUserAttributes(user, attributes);
            await checkAuthState(); // ユーザー情報再取得
            return { success: true };
        } catch (error) {
            return { success: false, error: error.message };
        }
    };
    
    const hasPermission = (permission) => {
        if (!state.user) return false;
        
        // 管理者は全権限
        if (state.user.groups.includes('Administrators')) {
            return true;
        }
        
        // 権限チェックロジック（簡略版）
        const userPermissions = [];
        if (state.user.groups.includes('Editors')) {
            userPermissions.push('users:read', 'users:update', 'content:read', 'content:write');
        }
        if (state.user.groups.includes('Viewers')) {
            userPermissions.push('users:read', 'content:read');
        }
        
        return userPermissions.includes(permission);
    };
    
    const value = {
        ...state,
        signIn,
        confirmSignIn,
        signUp,
        confirmSignUp,
        signOut,
        forgotPassword,
        forgotPasswordSubmit,
        changePassword,
        updateUserAttributes,
        hasPermission,
        checkAuthState
    };
    
    return (
        <AuthContext.Provider value={value}>
            {children}
        </AuthContext.Provider>
    );
};

export const useAuth = () => {
    const context = useContext(AuthContext);
    if (!context) {
        throw new Error('useAuth must be used within an AuthProvider');
    }
    return context;
};
```

### ステップ4: ユーザー管理APIの実装

1. **ユーザーCRUD API Lambda関数**
```javascript
// src/lambda/user-management-api.js
const AWS = require('aws-sdk');
const rbac = require('../auth/rbac-middleware');

const cognito = new AWS.CognitoIdentityServiceProvider();
const dynamodb = new AWS.DynamoDB.DocumentClient();

const USER_POOL_ID = process.env.USER_POOL_ID;
const USER_PROFILE_TABLE = process.env.USER_PROFILE_TABLE;

exports.handler = async (event) => {
    console.log('Event:', JSON.stringify(event, null, 2));
    
    const { httpMethod, pathParameters, body } = event;
    const userContext = rbac.extractUserContext(event);
    
    try {
        switch (httpMethod) {
            case 'GET':
                if (pathParameters && pathParameters.userId) {
                    return await getUser(pathParameters.userId, userContext);
                } else {
                    return await listUsers(event.queryStringParameters, userContext);
                }
            case 'POST':
                return await createUser(JSON.parse(body), userContext);
            case 'PUT':
                return await updateUser(pathParameters.userId, JSON.parse(body), userContext);
            case 'DELETE':
                return await deleteUser(pathParameters.userId, userContext);
            default:
                return createResponse(405, { error: 'Method not allowed' });
        }
    } catch (error) {
        console.error('Error:', error);
        return createResponse(500, { 
            error: 'Internal server error',
            message: error.message 
        });
    }
};

async function getUser(userId, userContext) {
    // 権限チェック：自分の情報または管理者/編集者権限
    if (userId !== userContext.userId && 
        !rbac.checkPermissions(userContext, ['users:read'])) {
        return createResponse(403, { error: 'Forbidden' });
    }
    
    try {
        // Cognito からユーザー情報取得
        const cognitoParams = {
            UserPoolId: USER_POOL_ID,
            Username: userId
        };
        
        const cognitoUser = await cognito.adminGetUser(cognitoParams).promise();
        
        // DynamoDB からプロファイル情報取得
        const dynamoParams = {
            TableName: USER_PROFILE_TABLE,
            Key: { userId: userId }
        };
        
        const profileResult = await dynamodb.get(dynamoParams).promise();
        
        // ユーザー情報統合
        const userInfo = {
            userId: userId,
            username: cognitoUser.Username,
            email: getAttribute(cognitoUser.UserAttributes, 'email'),
            firstName: getAttribute(cognitoUser.UserAttributes, 'given_name'),
            lastName: getAttribute(cognitoUser.UserAttributes, 'family_name'),
            phoneNumber: getAttribute(cognitoUser.UserAttributes, 'phone_number'),
            department: getAttribute(cognitoUser.UserAttributes, 'custom:department'),
            role: getAttribute(cognitoUser.UserAttributes, 'custom:role'),
            emailVerified: getAttribute(cognitoUser.UserAttributes, 'email_verified') === 'true',
            phoneVerified: getAttribute(cognitoUser.UserAttributes, 'phone_number_verified') === 'true',
            status: cognitoUser.UserStatus,
            enabled: cognitoUser.Enabled,
            createdDate: cognitoUser.UserCreateDate,
            lastModifiedDate: cognitoUser.UserLastModifiedDate,
            mfaEnabled: cognitoUser.MFAOptions && cognitoUser.MFAOptions.length > 0,
            profile: profileResult.Item || {}
        };
        
        return createResponse(200, userInfo);
    } catch (error) {
        if (error.code === 'UserNotFoundException') {
            return createResponse(404, { error: 'User not found' });
        }
        throw error;
    }
}

async function listUsers(queryParams, userContext) {
    // 管理者/編集者権限チェック
    if (!rbac.checkPermissions(userContext, ['users:read'])) {
        return createResponse(403, { error: 'Forbidden' });
    }
    
    const limit = parseInt(queryParams?.limit || '50');
    const paginationToken = queryParams?.nextToken;
    const filter = queryParams?.filter;
    
    const params = {
        UserPoolId: USER_POOL_ID,
        Limit: Math.min(limit, 100)
    };
    
    if (paginationToken) {
        params.PaginationToken = paginationToken;
    }
    
    if (filter) {
        params.Filter = `email ^= "${filter}" or given_name ^= "${filter}" or family_name ^= "${filter}"`;
    }
    
    try {
        const result = await cognito.listUsers(params).promise();
        
        const users = result.Users.map(user => ({
            userId: getAttribute(user.Attributes, 'sub'),
            username: user.Username,
            email: getAttribute(user.Attributes, 'email'),
            firstName: getAttribute(user.Attributes, 'given_name'),
            lastName: getAttribute(user.Attributes, 'family_name'),
            department: getAttribute(user.Attributes, 'custom:department'),
            role: getAttribute(user.Attributes, 'custom:role'),
            status: user.UserStatus,
            enabled: user.Enabled,
            createdDate: user.UserCreateDate,
            lastModifiedDate: user.UserLastModifiedDate
        }));
        
        const response = {
            users: users,
            nextToken: result.PaginationToken,
            count: users.length
        };
        
        return createResponse(200, response);
    } catch (error) {
        throw error;
    }
}

async function createUser(userData, userContext) {
    // 管理者権限チェック
    if (!rbac.checkPermissions(userContext, ['users:create'])) {
        return createResponse(403, { error: 'Forbidden' });
    }
    
    const { email, firstName, lastName, phoneNumber, department, role, temporaryPassword } = userData;
    
    // バリデーション
    if (!email || !firstName || !lastName) {
        return createResponse(400, { 
            error: 'Missing required fields',
            required: ['email', 'firstName', 'lastName']
        });
    }
    
    const params = {
        UserPoolId: USER_POOL_ID,
        Username: email,
        UserAttributes: [
            { Name: 'email', Value: email },
            { Name: 'given_name', Value: firstName },
            { Name: 'family_name', Value: lastName },
            { Name: 'email_verified', Value: 'true' }
        ],
        MessageAction: 'SUPPRESS', // メール送信しない（管理者作成）
        TemporaryPassword: temporaryPassword || generateTemporaryPassword()
    };
    
    if (phoneNumber) {
        params.UserAttributes.push({ Name: 'phone_number', Value: phoneNumber });
    }
    if (department) {
        params.UserAttributes.push({ Name: 'custom:department', Value: department });
    }
    if (role) {
        params.UserAttributes.push({ Name: 'custom:role', Value: role });
    }
    
    try {
        const result = await cognito.adminCreateUser(params).promise();
        
        // グループ追加（ロールに基づく）
        if (role) {
            const groupName = getGroupNameFromRole(role);
            if (groupName) {
                await cognito.adminAddUserToGroup({
                    UserPoolId: USER_POOL_ID,
                    Username: email,
                    GroupName: groupName
                }).promise();
            }
        }
        
        return createResponse(201, {
            message: 'User created successfully',
            userId: getAttribute(result.User.Attributes, 'sub'),
            username: result.User.Username
        });
    } catch (error) {
        if (error.code === 'UsernameExistsException') {
            return createResponse(409, { error: 'User already exists' });
        }
        throw error;
    }
}

async function updateUser(userId, updateData, userContext) {
    // 権限チェック：自分の情報または管理者権限
    if (userId !== userContext.userId && 
        !rbac.checkPermissions(userContext, ['users:update'])) {
        return createResponse(403, { error: 'Forbidden' });
    }
    
    const { firstName, lastName, phoneNumber, department, role } = updateData;
    
    const attributeUpdates = [];
    
    if (firstName) attributeUpdates.push({ Name: 'given_name', Value: firstName });
    if (lastName) attributeUpdates.push({ Name: 'family_name', Value: lastName });
    if (phoneNumber) attributeUpdates.push({ Name: 'phone_number', Value: phoneNumber });
    if (department) attributeUpdates.push({ Name: 'custom:department', Value: department });
    if (role) attributeUpdates.push({ Name: 'custom:role', Value: role });
    
    if (attributeUpdates.length === 0) {
        return createResponse(400, { error: 'No valid attributes to update' });
    }
    
    try {
        await cognito.adminUpdateUserAttributes({
            UserPoolId: USER_POOL_ID,
            Username: userId,
            UserAttributes: attributeUpdates
        }).promise();
        
        return createResponse(200, { message: 'User updated successfully' });
    } catch (error) {
        if (error.code === 'UserNotFoundException') {
            return createResponse(404, { error: 'User not found' });
        }
        throw error;
    }
}

async function deleteUser(userId, userContext) {
    // 管理者権限チェック
    if (!rbac.checkPermissions(userContext, ['users:delete'])) {
        return createResponse(403, { error: 'Forbidden' });
    }
    
    // 自分自身の削除は禁止
    if (userId === userContext.userId) {
        return createResponse(400, { error: 'Cannot delete your own account' });
    }
    
    try {
        await cognito.adminDeleteUser({
            UserPoolId: USER_POOL_ID,
            Username: userId
        }).promise();
        
        // DynamoDBからプロファイル削除
        await dynamodb.delete({
            TableName: USER_PROFILE_TABLE,
            Key: { userId: userId }
        }).promise();
        
        return createResponse(200, { message: 'User deleted successfully' });
    } catch (error) {
        if (error.code === 'UserNotFoundException') {
            return createResponse(404, { error: 'User not found' });
        }
        throw error;
    }
}

// ヘルパー関数
function getAttribute(attributes, name) {
    const attr = attributes.find(a => a.Name === name);
    return attr ? attr.Value : null;
}

function generateTemporaryPassword() {
    const length = 12;
    const charset = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*';
    let password = '';
    for (let i = 0; i < length; i++) {
        password += charset.charAt(Math.floor(Math.random() * charset.length));
    }
    return password;
}

function getGroupNameFromRole(role) {
    const roleGroupMap = {
        'ADMIN': 'Administrators',
        'EDITOR': 'Editors',
        'VIEWER': 'Viewers'
    };
    return roleGroupMap[role.toUpperCase()];
}

function createResponse(statusCode, body) {
    return {
        statusCode,
        headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,Authorization',
            'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
        },
        body: JSON.stringify(body)
    };
}
```

## 検証方法

### 1. 認証フローテスト
```bash
# ユーザー作成
aws cognito-idp admin-create-user \
  --user-pool-id us-east-1_XXXXXXXXX \
  --username testuser@example.com \
  --user-attributes Name=email,Value=testuser@example.com \
  --temporary-password TempPass123! \
  --message-action SUPPRESS

# ユーザー確認
aws cognito-idp admin-set-user-password \
  --user-pool-id us-east-1_XXXXXXXXX \
  --username testuser@example.com \
  --password NewPass123! \
  --permanent
```

### 2. JWT トークン検証テスト
```javascript
// JWT検証テスト
const jwt = require('jsonwebtoken');
const jwksClient = require('jwks-rsa');

async function testJWTVerification(token) {
    // JWT検証ロジックのテスト
    console.log('Testing JWT verification...');
    // 実装は上記の JWT Authorizer を参照
}
```

### 3. 権限チェックテスト
```javascript
// RBAC テスト
const rbac = require('./src/auth/rbac-middleware');

const testUserContext = {
    userId: 'test-user-id',
    groups: ['Editors'],
    roles: ['EDITOR']
};

console.log('Can read users:', rbac.checkPermissions(testUserContext, ['users:read']));
console.log('Can delete users:', rbac.checkPermissions(testUserContext, ['users:delete']));
```

## トラブルシューティング

### よくある問題と解決策

#### 1. JWT検証エラー
**症状**: Token validation failed
**解決策**:
- JWKSエンドポイントの確認
- トークンの形式確認
- クロック同期の確認

#### 2. MFA設定問題
**症状**: MFA認証が動作しない
**解決策**:
- SMS設定の確認
- TOTP設定の確認
- IAMロール権限の確認

#### 3. 権限エラー
**症状**: Insufficient permissions
**解決策**:
- ユーザーグループの確認
- IAMロール・ポリシーの確認
- カスタム属性の確認

## 学習リソース

### AWS公式ドキュメント
- [Amazon Cognito Developer Guide](https://docs.aws.amazon.com/cognito/latest/developerguide/)
- [Cognito User Pool Lambda Triggers](https://docs.aws.amazon.com/cognito/latest/developerguide/user-pool-lambda-triggers.html)
- [JWT and JWS Overview](https://docs.aws.amazon.com/cognito/latest/developerguide/amazon-cognito-user-pools-using-tokens-with-identity-providers.html)

### 追加学習教材
- [OAuth 2.0 Simplified](https://aaronparecki.com/oauth-2-simplified/)
- [JWT.io Debugger](https://jwt.io/)

## セキュリティとコストの考慮事項

### セキュリティベストプラクティス
1. **強力なパスワードポリシー**: 複雑性要件の設定
2. **MFA強制**: 本番環境での必須化
3. **トークン管理**: 適切な有効期限設定
4. **監査ログ**: CloudTrailによる認証イベント記録

### コスト最適化
1. **MAU課金**: 月間アクティブユーザー数の最適化
2. **MFAコスト**: SMS vs TOTP選択
3. **Lambda実行回数**: トリガー最適化
4. **ログ保持**: CloudWatch Logsの適切な設定

### AWS Well-Architectedフレームワークとの関連
- **運用性の柱**: CloudWatch監視・Lambda Triggers
- **セキュリティの柱**: IAM・Cognito・JWT・MFA
- **信頼性の柱**: Multi-AZ・バックアップ・フェイルオーバー
- **パフォーマンス効率の柱**: JWKSキャッシュ・接続プール
- **コスト最適化の柱**: MAU最適化・適切なトークン期限

## 次のステップ

### 推奨される学習パス
1. **3.1.2 データ操作API**: 認証されたAPIの実装
2. **3.2.1 ファイルアップロード**: S3認証付きアップロード
3. **5.2.1 チャットボット作成**: 認証統合型AI機能
4. **6.1.1 マルチステージビルド**: セキュアなCI/CD

### 発展的な機能
1. **Federated Identity**: SAML・Active Directory統合
2. **Custom Auth Challenge**: 生体認証・カスタムMFA
3. **Advanced Security**: 異常検知・リスクベース認証
4. **Cross-Platform SSO**: 複数アプリ間のSSO

### 実践プロジェクトのアイデア
1. **エンタープライズポータル**: 組織階層・権限管理
2. **SaaSマルチテナント**: テナント分離認証
3. **モバイルアプリ**: バイオメトリクス認証
4. **IoTデバイス管理**: デバイス認証・証明書管理