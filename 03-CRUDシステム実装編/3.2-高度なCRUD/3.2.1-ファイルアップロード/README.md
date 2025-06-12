# 3.2.1 ファイルアップロード

## 学習目標

このセクションでは、S3を活用したセキュアで高性能なファイルアップロード機能を構築し、画像処理・ファイル変換・プログレス表示等の高度な機能を実装して、エンタープライズグレードのファイル管理システムを開発します。

### 習得できるスキル
- S3 Presigned URL によるセキュアアップロード
- マルチパートアップロードによる大容量ファイル処理
- Lambda による画像・動画変換処理
- CloudFront によるファイル配信最適化
- ファイルアップロードのプログレス表示実装
- ウイルススキャンとセキュリティ検証

## 前提知識

### 必須の知識
- Amazon S3 の基本操作
- Lambda 関数の開発（1.2.3セクション完了）
- API Gateway の理解（3.1.2セクション完了）
- JavaScript/TypeScript のファイル操作

### あると望ましい知識
- 画像・動画処理の基本概念
- CDN の仕組みと効果
- セキュリティベストプラクティス
- フロントエンド開発経験

## アーキテクチャ概要

### ファイルアップロード・処理アーキテクチャ

```
                    ┌─────────────────────┐
                    │   Client Apps       │
                    │ (Web/Mobile)        │
                    │                     │
                    │ ┌─────────────────┐ │
                    │ │  File Upload    │ │
                    │ │   Component     │ │
                    │ └─────────────────┘ │
                    └─────────┬───────────┘
                              │
                    ┌─────────┼───────────┐
                    │         │           │
                    ▼         ▼           ▼
          ┌─────────────────┐ ┌──────────┐ ┌─────────────────┐
          │   CloudFront    │ │  WAF     │ │   API Gateway   │
          │   (Download)    │ │(Security)│ │   (Upload API)  │
          └─────────┬───────┘ └────┬─────┘ └─────────┬───────┘
                    │              │                 │
                    └──────────────┼─────────────────┘
                                   │
                                   ▼
          ┌─────────────────────────────────────────────────────────┐
          │                Lambda Functions                         │
          │              (Upload Management)                        │
          │                                                         │
          │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │
          │  │ Presigned   │  │   Upload    │  │   File      │   │
          │  │ URL Gen.    │  │ Complete    │  │ Validation  │   │
          │  │             │  │             │  │             │   │
          │  │┌──────────┐ │  │┌──────────┐ │  │┌──────────┐ │   │
          │  ││Security  │ │  ││Metadata  │ │  ││Virus     │ │   │
          │  ││Check     │ │  ││Update    │ │  ││Scan      │ │   │
          │  ││Policy    │ │  ││Database  │ │  ││MIME Type │ │   │
          │  │└──────────┘ │  │└──────────┘ │  │└──────────┘ │   │
          │  └─────────────┘  └─────────────┘  └─────────────┘   │
          └─────────────────────────────────────────────────────────┘
                                   │
                                   ▼
          ┌─────────────────────────────────────────────────────────┐
          │                 S3 Buckets                              │
          │                                                         │
          │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │
          │  │   Upload    │  │ Processing  │  │   Final     │   │
          │  │   Bucket    │  │   Bucket    │  │  Storage    │   │
          │  │             │  │             │  │             │   │
          │  │┌──────────┐ │  │┌──────────┐ │  │┌──────────┐ │   │
          │  ││Temp      │ │  ││Transform │ │  ││Optimized │ │   │
          │  ││Files     │ │  ││Resize    │ │  ││Files     │ │   │
          │  ││Lifecycle │ │  ││Convert   │ │  ││CDN Ready │ │   │
          │  │└──────────┘ │  │└──────────┘ │  │└──────────┘ │   │
          │  └─────────────┘  └─────────────┘  └─────────────┘   │
          └─────────────────────────────────────────────────────────┘
                                   │
                                   ▼
          ┌─────────────────────────────────────────────────────────┐
          │               Processing Pipeline                       │
          │                (Event-Driven)                          │
          │                                                         │
          │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │
          │  │   Image     │  │   Video     │  │ Document    │   │
          │  │ Processing  │  │ Processing  │ │ Processing  │   │
          │  │             │  │             │  │             │   │
          │  │┌──────────┐ │  │┌──────────┐ │  │┌──────────┐ │   │
          │  ││Resize    │ │  ││Transcode │ │  ││OCR       │ │   │
          │  ││Compress  │ │  ││Thumbnail │ │  ││PDF       │ │   │
          │  ││Format    │ │  ││Watermark │ │  ││Conversion│ │   │
          │  │└──────────┘ │  │└──────────┘ │  │└──────────┘ │   │
          │  └─────────────┘  └─────────────┘  └─────────────┘   │
          └─────────────────────────────────────────────────────────┘
                                   │
                                   ▼
          ┌─────────────────────────────────────────────────────────┐
          │              Metadata & Database                        │
          │                                                         │
          │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │
          │  │  DynamoDB   │  │ElasticSearch│  │  CloudWatch │   │
          │  │ (Metadata)  │  │ (Search)    │  │(Monitoring) │   │
          │  │             │  │             │  │             │   │
          │  │┌──────────┐ │  │┌──────────┐ │  │┌──────────┐ │   │
          │  ││File Info │ │  ││Content   │ │  ││Upload    │ │   │
          │  ││Progress  │ │  ││Index     │ │  ││Metrics   │ │   │
          │  ││Access    │ │  ││Search    │ │  ││Alerts    │ │   │
          │  │└──────────┘ │  │└──────────┘ │  │└──────────┘ │   │
          │  └─────────────┘  └─────────────┘  └─────────────┘   │
          └─────────────────────────────────────────────────────────┘
```

### 主要コンポーネント
- **S3 Upload Bucket**: 一時アップロード先
- **Lambda Functions**: アップロード処理・変換・検証
- **CloudFront**: 高速ファイル配信
- **DynamoDB**: メタデータ・進捗管理
- **ElasticSearch**: ファイル検索インデックス
- **EventBridge**: イベント駆動処理

## ハンズオン手順

### ステップ1: S3バケット構成とCloudFormation

1. **ファイルアップロード基盤の構築**
```yaml
# cloudformation/file-upload-infrastructure.yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Comprehensive file upload system with S3, Lambda, and processing pipeline'

Parameters:
  ProjectName:
    Type: String
    Default: 'file-upload'
  
  EnvironmentName:
    Type: String
    Default: 'dev'
    AllowedValues: [dev, staging, prod]
  
  MaxFileSize:
    Type: Number
    Default: 104857600  # 100MB
    Description: 'Maximum file size in bytes'
  
  AllowedFileTypes:
    Type: CommaDelimitedList
    Default: 'jpg,jpeg,png,gif,webp,mp4,avi,mov,pdf,doc,docx'
    Description: 'Allowed file extensions'

Conditions:
  IsProduction: !Equals [!Ref EnvironmentName, 'prod']

Resources:
  # S3 Buckets
  UploadBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Sub '${ProjectName}-${EnvironmentName}-uploads-${AWS::AccountId}'
      PublicAccessBlockConfiguration:
        BlockPublicAcls: true
        BlockPublicPolicy: true
        IgnorePublicAcls: true
        RestrictPublicBuckets: true
      VersioningConfiguration:
        Status: Enabled
      LifecycleConfiguration:
        Rules:
          - Id: DeleteIncompleteMultipartUploads
            Status: Enabled
            AbortIncompleteMultipartUpload:
              DaysAfterInitiation: 1
          - Id: DeleteTempFiles
            Status: Enabled
            ExpirationInDays: 7
            TagFilters:
              - Key: FileType
                Value: temporary
      NotificationConfiguration:
        LambdaConfigurations:
          - Event: s3:ObjectCreated:*
            Function: !GetAtt FileProcessorFunction.Arn
      CorsConfiguration:
        CorsRules:
          - AllowedHeaders: ['*']
            AllowedMethods: [GET, PUT, POST, DELETE, HEAD]
            AllowedOrigins: ['*']  # 本番では適切なオリジン制限
            ExposedHeaders: [ETag, x-amz-meta-*, x-amz-server-side-encryption, x-amz-request-id]
            MaxAge: 3000
      LoggingConfiguration:
        DestinationBucketName: !Ref AccessLogsBucket
        LogFilePrefix: 'upload-access-logs/'
      Tags:
        - Key: Environment
          Value: !Ref EnvironmentName
        - Key: Project
          Value: !Ref ProjectName

  ProcessingBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Sub '${ProjectName}-${EnvironmentName}-processing-${AWS::AccountId}'
      PublicAccessBlockConfiguration:
        BlockPublicAcls: true
        BlockPublicPolicy: true
        IgnorePublicAcls: true
        RestrictPublicBuckets: true
      LifecycleConfiguration:
        Rules:
          - Id: DeleteProcessingFiles
            Status: Enabled
            ExpirationInDays: 3

  FinalStorageBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Sub '${ProjectName}-${EnvironmentName}-storage-${AWS::AccountId}'
      PublicAccessBlockConfiguration:
        BlockPublicAcls: true
        BlockPublicPolicy: true
        IgnorePublicAcls: true
        RestrictPublicBuckets: true
      VersioningConfiguration:
        Status: !If [IsProduction, Enabled, Suspended]
      ReplicationConfiguration:
        !If
          - IsProduction
          - Role: !GetAtt S3ReplicationRole.Arn
            Rules:
              - Id: ReplicateToSecondaryRegion
                Status: Enabled
                Prefix: 'important/'
                Destination:
                  Bucket: !Sub 'arn:aws:s3:::${ProjectName}-${EnvironmentName}-backup-${AWS::AccountId}'
                  StorageClass: STANDARD_IA
          - !Ref AWS::NoValue

  AccessLogsBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Sub '${ProjectName}-${EnvironmentName}-access-logs-${AWS::AccountId}'
      LifecycleConfiguration:
        Rules:
          - Id: DeleteAccessLogs
            Status: Enabled
            ExpirationInDays: 90

  # CloudFront Distribution
  CloudFrontDistribution:
    Type: AWS::CloudFront::Distribution
    Properties:
      DistributionConfig:
        Origins:
          - Id: S3Origin
            DomainName: !GetAtt FinalStorageBucket.RegionalDomainName
            S3OriginConfig:
              OriginAccessIdentity: !Sub 'origin-access-identity/cloudfront/${OriginAccessIdentity}'
        Enabled: true
        HttpVersion: http2
        DefaultCacheBehavior:
          TargetOriginId: S3Origin
          ViewerProtocolPolicy: redirect-to-https
          AllowedMethods: [GET, HEAD, OPTIONS]
          CachedMethods: [GET, HEAD]
          ForwardedValues:
            QueryString: false
            Cookies:
              Forward: none
          Compress: true
          DefaultTTL: 86400  # 1 day
          MaxTTL: 31536000   # 1 year
        CacheBehaviors:
          - PathPattern: '/images/*'
            TargetOriginId: S3Origin
            ViewerProtocolPolicy: redirect-to-https
            AllowedMethods: [GET, HEAD]
            CachedMethods: [GET, HEAD]
            ForwardedValues:
              QueryString: false
              Cookies:
                Forward: none
            Compress: true
            DefaultTTL: 2592000  # 30 days
            MaxTTL: 31536000
        PriceClass: !If [IsProduction, PriceClass_All, PriceClass_100]
        Restrictions:
          GeoRestriction:
            RestrictionType: none

  OriginAccessIdentity:
    Type: AWS::CloudFront::CloudFrontOriginAccessIdentity
    Properties:
      CloudFrontOriginAccessIdentityConfig:
        Comment: !Sub 'Origin Access Identity for ${ProjectName}'

  # Lambda Functions
  PresignedUrlFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: !Sub '${ProjectName}-${EnvironmentName}-presigned-url'
      Runtime: nodejs18.x
      Handler: presigned-url.handler
      Role: !GetAtt LambdaExecutionRole.Arn
      Code:
        S3Bucket: !Ref ArtifactsBucket
        S3Key: 'lambda/presigned-url.zip'
      Environment:
        Variables:
          UPLOAD_BUCKET: !Ref UploadBucket
          MAX_FILE_SIZE: !Ref MaxFileSize
          ALLOWED_FILE_TYPES: !Join [',', !Ref AllowedFileTypes]
          DYNAMODB_TABLE: !Ref FileMetadataTable
      Timeout: 30
      MemorySize: 256

  FileProcessorFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: !Sub '${ProjectName}-${EnvironmentName}-file-processor'
      Runtime: nodejs18.x
      Handler: file-processor.handler
      Role: !GetAtt LambdaExecutionRole.Arn
      Code:
        S3Bucket: !Ref ArtifactsBucket
        S3Key: 'lambda/file-processor.zip'
      Environment:
        Variables:
          UPLOAD_BUCKET: !Ref UploadBucket
          PROCESSING_BUCKET: !Ref ProcessingBucket
          FINAL_BUCKET: !Ref FinalStorageBucket
          DYNAMODB_TABLE: !Ref FileMetadataTable
          VIRUS_SCAN_TOPIC: !Ref VirusScanTopic
      Timeout: 900  # 15 minutes
      MemorySize: 3008  # Maximum memory for processing

  ImageProcessorFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: !Sub '${ProjectName}-${EnvironmentName}-image-processor'
      Runtime: nodejs18.x
      Handler: image-processor.handler
      Role: !GetAtt LambdaExecutionRole.Arn
      Code:
        S3Bucket: !Ref ArtifactsBucket
        S3Key: 'lambda/image-processor.zip'
      Environment:
        Variables:
          PROCESSING_BUCKET: !Ref ProcessingBucket
          FINAL_BUCKET: !Ref FinalStorageBucket
          DYNAMODB_TABLE: !Ref FileMetadataTable
      Timeout: 300
      MemorySize: 1024
      Layers:
        - !Ref ImageProcessingLayer

  # Lambda Layer for image processing
  ImageProcessingLayer:
    Type: AWS::Lambda::LayerVersion
    Properties:
      LayerName: !Sub '${ProjectName}-${EnvironmentName}-image-processing'
      Description: 'Sharp library for image processing'
      Content:
        S3Bucket: !Ref ArtifactsBucket
        S3Key: 'layers/sharp-layer.zip'
      CompatibleRuntimes:
        - nodejs18.x
      LicenseInfo: 'Apache-2.0'

  # DynamoDB Table for file metadata
  FileMetadataTable:
    Type: AWS::DynamoDB::Table
    Properties:
      TableName: !Sub '${ProjectName}-${EnvironmentName}-file-metadata'
      BillingMode: PAY_PER_REQUEST
      AttributeDefinitions:
        - AttributeName: fileId
          AttributeType: S
        - AttributeName: userId
          AttributeType: S
        - AttributeName: uploadTimestamp
          AttributeType: S
        - AttributeName: fileType
          AttributeType: S
      KeySchema:
        - AttributeName: fileId
          KeyType: HASH
      GlobalSecondaryIndexes:
        - IndexName: user-files-index
          KeySchema:
            - AttributeName: userId
              KeyType: HASH
            - AttributeName: uploadTimestamp
              KeyType: RANGE
          Projection:
            ProjectionType: ALL
        - IndexName: filetype-index
          KeySchema:
            - AttributeName: fileType
              KeyType: HASH
            - AttributeName: uploadTimestamp
              KeyType: RANGE
          Projection:
            ProjectionType: ALL
      StreamSpecification:
        StreamViewType: NEW_AND_OLD_IMAGES
      PointInTimeRecoverySpecification:
        PointInTimeRecoveryEnabled: !If [IsProduction, true, false]
      SSESpecification:
        SSEEnabled: true
      Tags:
        - Key: Environment
          Value: !Ref EnvironmentName
        - Key: Project
          Value: !Ref ProjectName

  # SNS Topic for virus scanning
  VirusScanTopic:
    Type: AWS::SNS::Topic
    Properties:
      TopicName: !Sub '${ProjectName}-${EnvironmentName}-virus-scan'
      DisplayName: 'File Virus Scan Notifications'

  # EventBridge Rule for processing pipeline
  FileProcessingRule:
    Type: AWS::Events::Rule
    Properties:
      Name: !Sub '${ProjectName}-${EnvironmentName}-file-processing'
      Description: 'Trigger processing pipeline for uploaded files'
      EventPattern:
        source: ['aws.s3']
        detail:
          eventSource: ['s3.amazonaws.com']
          eventName: ['ObjectCreated:Put', 'ObjectCreated:Post']
          requestParameters:
            bucketName: [!Ref UploadBucket]
      State: ENABLED
      Targets:
        - Arn: !GetAtt FileProcessorFunction.Arn
          Id: FileProcessorTarget

  # Lambda Permission for S3
  S3InvokePermission:
    Type: AWS::Lambda::Permission
    Properties:
      FunctionName: !Ref FileProcessorFunction
      Action: lambda:InvokeFunction
      Principal: s3.amazonaws.com
      SourceArn: !Sub '${UploadBucket}/*'

  # IAM Roles
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
      Policies:
        - PolicyName: S3AccessPolicy
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - s3:GetObject
                  - s3:PutObject
                  - s3:DeleteObject
                  - s3:GetObjectVersion
                Resource:
                  - !Sub '${UploadBucket}/*'
                  - !Sub '${ProcessingBucket}/*'
                  - !Sub '${FinalStorageBucket}/*'
              - Effect: Allow
                Action:
                  - s3:ListBucket
                Resource:
                  - !GetAtt UploadBucket.Arn
                  - !GetAtt ProcessingBucket.Arn
                  - !GetAtt FinalStorageBucket.Arn
        - PolicyName: DynamoDBAccessPolicy
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
                  - !GetAtt FileMetadataTable.Arn
                  - !Sub '${FileMetadataTable.Arn}/index/*'
        - PolicyName: SNSPublishPolicy
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - sns:Publish
                Resource: !Ref VirusScanTopic

Outputs:
  UploadBucketName:
    Description: 'S3 Upload Bucket Name'
    Value: !Ref UploadBucket
    Export:
      Name: !Sub '${AWS::StackName}-UploadBucket'
  
  CloudFrontDistributionId:
    Description: 'CloudFront Distribution ID'
    Value: !Ref CloudFrontDistribution
    Export:
      Name: !Sub '${AWS::StackName}-CloudFrontDistribution'
  
  CloudFrontDomainName:
    Description: 'CloudFront Distribution Domain Name'
    Value: !GetAtt CloudFrontDistribution.DomainName
    Export:
      Name: !Sub '${AWS::StackName}-CloudFrontDomain'
  
  PresignedUrlFunctionArn:
    Description: 'Presigned URL Lambda Function ARN'
    Value: !GetAtt PresignedUrlFunction.Arn
    Export:
      Name: !Sub '${AWS::StackName}-PresignedUrlFunction'
```

### ステップ2: Presigned URL生成Lambda関数

1. **セキュアなアップロードURL生成**
```javascript
// src/lambda/presigned-url.js
const AWS = require('aws-sdk');
const { v4: uuidv4 } = require('uuid');
const crypto = require('crypto');

const s3 = new AWS.S3();
const dynamodb = new AWS.DynamoDB.DocumentClient();

const UPLOAD_BUCKET = process.env.UPLOAD_BUCKET;
const MAX_FILE_SIZE = parseInt(process.env.MAX_FILE_SIZE);
const ALLOWED_FILE_TYPES = process.env.ALLOWED_FILE_TYPES.split(',');
const DYNAMODB_TABLE = process.env.DYNAMODB_TABLE;

exports.handler = async (event) => {
    console.log('Presigned URL request:', JSON.stringify(event, null, 2));
    
    try {
        const { body } = event;
        const requestData = JSON.parse(body);
        
        // リクエストデータ検証
        const validation = validateUploadRequest(requestData);
        if (!validation.isValid) {
            return createResponse(400, {
                error: 'Invalid request',
                details: validation.errors
            });
        }
        
        const { 
            fileName, 
            fileSize, 
            fileType, 
            contentType,
            userId,
            metadata = {} 
        } = requestData;
        
        // ファイル拡張子チェック
        const fileExtension = fileName.split('.').pop().toLowerCase();
        if (!ALLOWED_FILE_TYPES.includes(fileExtension)) {
            return createResponse(400, {
                error: 'File type not allowed',
                allowedTypes: ALLOWED_FILE_TYPES
            });
        }
        
        // ファイルサイズチェック
        if (fileSize > MAX_FILE_SIZE) {
            return createResponse(400, {
                error: 'File size too large',
                maxSize: MAX_FILE_SIZE,
                receivedSize: fileSize
            });
        }
        
        // ユニークファイルID生成
        const fileId = uuidv4();
        const sanitizedFileName = sanitizeFileName(fileName);
        const s3Key = `uploads/${userId}/${fileId}/${sanitizedFileName}`;
        
        // セキュリティポリシー定義
        const uploadPolicy = {
            Bucket: UPLOAD_BUCKET,
            Key: s3Key,
            Expires: 300, // 5分間有効
            Conditions: [
                ['content-length-range', 1, MAX_FILE_SIZE],
                ['starts-with', '$Content-Type', contentType.split('/')[0]],
                ['eq', '$x-amz-meta-user-id', userId],
                ['eq', '$x-amz-meta-file-id', fileId]
            ],
            Fields: {
                'x-amz-meta-user-id': userId,
                'x-amz-meta-file-id': fileId,
                'x-amz-meta-original-name': fileName,
                'x-amz-meta-upload-timestamp': new Date().toISOString(),
                'x-amz-meta-file-hash': crypto.createHash('sha256').update(fileName + Date.now()).digest('hex'),
                'Content-Type': contentType
            }
        };
        
        // 追加メタデータ
        Object.keys(metadata).forEach(key => {
            if (isValidMetadataKey(key)) {
                uploadPolicy.Fields[`x-amz-meta-${key}`] = metadata[key];
            }
        });
        
        // Presigned POST生成
        const presignedPost = s3.createPresignedPost(uploadPolicy);
        
        // DynamoDBにファイルメタデータ保存
        const fileMetadata = {
            fileId: fileId,
            fileName: sanitizedFileName,
            originalFileName: fileName,
            fileSize: fileSize,
            fileType: fileExtension,
            contentType: contentType,
            userId: userId,
            s3Key: s3Key,
            status: 'PENDING_UPLOAD',
            uploadTimestamp: new Date().toISOString(),
            expiresAt: new Date(Date.now() + 300000).toISOString(), // 5分後
            metadata: metadata,
            uploadUrl: presignedPost.url,
            securityHash: crypto.createHash('sha256').update(fileId + userId + fileName).digest('hex')
        };
        
        await dynamodb.put({
            TableName: DYNAMODB_TABLE,
            Item: fileMetadata,
            ConditionExpression: 'attribute_not_exists(fileId)'
        }).promise();
        
        // レスポンス構築
        const response = {
            fileId: fileId,
            uploadUrl: presignedPost.url,
            fields: presignedPost.fields,
            expiresIn: 300,
            maxFileSize: MAX_FILE_SIZE,
            allowedTypes: ALLOWED_FILE_TYPES,
            instructions: {
                method: 'POST',
                enctype: 'multipart/form-data',
                note: 'Include all fields in the form data before the file field'
            }
        };
        
        return createResponse(200, response);
        
    } catch (error) {
        console.error('Error generating presigned URL:', error);
        
        if (error.code === 'ConditionalCheckFailedException') {
            return createResponse(409, {
                error: 'File ID collision',
                message: 'Please retry the request'
            });
        }
        
        return createResponse(500, {
            error: 'Internal server error',
            message: 'Failed to generate upload URL'
        });
    }
};

function validateUploadRequest(data) {
    const errors = [];
    
    if (!data.fileName || typeof data.fileName !== 'string') {
        errors.push('fileName is required and must be a string');
    }
    
    if (!data.fileSize || typeof data.fileSize !== 'number' || data.fileSize <= 0) {
        errors.push('fileSize is required and must be a positive number');
    }
    
    if (!data.contentType || typeof data.contentType !== 'string') {
        errors.push('contentType is required and must be a string');
    }
    
    if (!data.userId || typeof data.userId !== 'string') {
        errors.push('userId is required and must be a string');
    }
    
    // ファイル名のセキュリティチェック
    if (data.fileName && /[<>:"/\\|?*\x00-\x1f]/.test(data.fileName)) {
        errors.push('fileName contains invalid characters');
    }
    
    // Content-Type検証
    const allowedContentTypes = [
        'image/jpeg', 'image/png', 'image/gif', 'image/webp',
        'video/mp4', 'video/avi', 'video/mov',
        'application/pdf', 'application/msword', 
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
    ];
    
    if (data.contentType && !allowedContentTypes.includes(data.contentType)) {
        errors.push('contentType not allowed');
    }
    
    return {
        isValid: errors.length === 0,
        errors: errors
    };
}

function sanitizeFileName(fileName) {
    // ファイル名の安全化
    return fileName
        .replace(/[^a-zA-Z0-9._-]/g, '_')  // 特殊文字をアンダースコアに置換
        .replace(/_+/g, '_')              // 連続するアンダースコアを1つに
        .replace(/^_|_$/g, '')            // 先頭・末尾のアンダースコア削除
        .substring(0, 100);               // 長さ制限
}

function isValidMetadataKey(key) {
    // メタデータキーの検証（英数字とハイフンのみ）
    return /^[a-zA-Z0-9-]+$/.test(key) && key.length <= 50;
}

function createResponse(statusCode, body) {
    return {
        statusCode,
        headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,Authorization',
            'Access-Control-Allow-Methods': 'POST,OPTIONS'
        },
        body: JSON.stringify(body)
    };
}
```

### ステップ3: ファイル処理パイプライン

1. **ファイル検証・処理Lambda関数**
```javascript
// src/lambda/file-processor.js
const AWS = require('aws-sdk');
const sharp = require('sharp');
const ffmpeg = require('fluent-ffmpeg');
const crypto = require('crypto');

const s3 = new AWS.S3();
const dynamodb = new AWS.DynamoDB.DocumentClient();
const sns = new AWS.SNS();

const UPLOAD_BUCKET = process.env.UPLOAD_BUCKET;
const PROCESSING_BUCKET = process.env.PROCESSING_BUCKET;
const FINAL_BUCKET = process.env.FINAL_BUCKET;
const DYNAMODB_TABLE = process.env.DYNAMODB_TABLE;
const VIRUS_SCAN_TOPIC = process.env.VIRUS_SCAN_TOPIC;

exports.handler = async (event) => {
    console.log('File processing event:', JSON.stringify(event, null, 2));
    
    // S3イベントまたはDirect Lambda実行を処理
    const records = event.Records || [event];
    
    for (const record of records) {
        try {
            let bucketName, objectKey;
            
            if (record.s3) {
                // S3イベント経由
                bucketName = record.s3.bucket.name;
                objectKey = decodeURIComponent(record.s3.object.key.replace(/\+/g, ' '));
            } else {
                // Direct実行
                bucketName = record.bucketName;
                objectKey = record.objectKey;
            }
            
            console.log(`Processing file: ${objectKey} from bucket: ${bucketName}`);
            
            // ファイルメタデータ取得
            const fileMetadata = await getFileMetadata(objectKey);
            if (!fileMetadata) {
                console.error(`File metadata not found for: ${objectKey}`);
                continue;
            }
            
            // ステータス更新: 処理開始
            await updateFileStatus(fileMetadata.fileId, 'PROCESSING', {
                processingStartTime: new Date().toISOString()
            });
            
            // ファイル内容取得
            const fileObject = await s3.getObject({
                Bucket: bucketName,
                Key: objectKey
            }).promise();
            
            // ファイル検証
            const validationResult = await validateFile(fileObject, fileMetadata);
            if (!validationResult.isValid) {
                await updateFileStatus(fileMetadata.fileId, 'VALIDATION_FAILED', {
                    error: validationResult.error,
                    processingEndTime: new Date().toISOString()
                });
                continue;
            }
            
            // ウイルススキャン通知
            await notifyVirusScan(fileMetadata, objectKey);
            
            // ファイルタイプ別処理
            const processingResult = await processFileByType(fileObject, fileMetadata, objectKey);
            
            if (processingResult.success) {
                // 最終保存場所にコピー
                await copyToFinalBucket(processingResult.processedFiles, fileMetadata);
                
                // メタデータ更新
                await updateFileStatus(fileMetadata.fileId, 'COMPLETED', {
                    processingEndTime: new Date().toISOString(),
                    finalLocation: processingResult.finalKey,
                    processedVariants: processingResult.variants,
                    fileHash: processingResult.fileHash,
                    compressionRatio: processingResult.compressionRatio
                });
                
                // 一時ファイル削除
                await cleanupTempFiles(objectKey, processingResult.tempFiles);
                
            } else {
                await updateFileStatus(fileMetadata.fileId, 'PROCESSING_FAILED', {
                    error: processingResult.error,
                    processingEndTime: new Date().toISOString()
                });
            }
            
        } catch (error) {
            console.error('Error processing file:', error);
            
            // エラー状態更新
            if (record.fileId) {
                await updateFileStatus(record.fileId, 'ERROR', {
                    error: error.message,
                    processingEndTime: new Date().toISOString()
                });
            }
        }
    }
    
    return { statusCode: 200, body: 'Processing completed' };
};

async function getFileMetadata(s3Key) {
    try {
        // S3キーからfileId抽出（uploads/userId/fileId/filename形式）
        const keyParts = s3Key.split('/');
        if (keyParts.length < 4) return null;
        
        const fileId = keyParts[2];
        
        const result = await dynamodb.get({
            TableName: DYNAMODB_TABLE,
            Key: { fileId: fileId }
        }).promise();
        
        return result.Item;
    } catch (error) {
        console.error('Error getting file metadata:', error);
        return null;
    }
}

async function updateFileStatus(fileId, status, additionalData = {}) {
    try {
        const updateExpression = 'SET #status = :status, #updatedAt = :updatedAt';
        const expressionAttributeNames = {
            '#status': 'status',
            '#updatedAt': 'updatedAt'
        };
        const expressionAttributeValues = {
            ':status': status,
            ':updatedAt': new Date().toISOString()
        };
        
        // 追加データを動的に追加
        Object.keys(additionalData).forEach((key, index) => {
            const attrName = `#attr${index}`;
            const attrValue = `:val${index}`;
            updateExpression += `, ${attrName} = ${attrValue}`;
            expressionAttributeNames[attrName] = key;
            expressionAttributeValues[attrValue] = additionalData[key];
        });
        
        await dynamodb.update({
            TableName: DYNAMODB_TABLE,
            Key: { fileId: fileId },
            UpdateExpression: updateExpression,
            ExpressionAttributeNames: expressionAttributeNames,
            ExpressionAttributeValues: expressionAttributeValues
        }).promise();
        
    } catch (error) {
        console.error('Error updating file status:', error);
        throw error;
    }
}

async function validateFile(fileObject, metadata) {
    try {
        const fileBuffer = fileObject.Body;
        
        // ファイルサイズ検証
        if (fileBuffer.length !== metadata.fileSize) {
            return {
                isValid: false,
                error: 'File size mismatch'
            };
        }
        
        // ファイルハッシュ検証
        const fileHash = crypto.createHash('sha256').update(fileBuffer).digest('hex');
        
        // マジックナンバー検証（ファイルタイプ偽装防止）
        const magicNumbers = {
            'jpg': [0xFF, 0xD8, 0xFF],
            'jpeg': [0xFF, 0xD8, 0xFF],
            'png': [0x89, 0x50, 0x4E, 0x47],
            'gif': [0x47, 0x49, 0x46, 0x38],
            'pdf': [0x25, 0x50, 0x44, 0x46],
            'mp4': [0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70] // ftyp
        };
        
        const expectedMagic = magicNumbers[metadata.fileType];
        if (expectedMagic) {
            const fileMagic = Array.from(fileBuffer.slice(0, expectedMagic.length));
            if (!arraysEqual(fileMagic, expectedMagic)) {
                return {
                    isValid: false,
                    error: 'File type mismatch - possible file extension spoofing'
                };
            }
        }
        
        // 悪意のあるコンテンツ検証（簡易版）
        const suspiciousPatterns = [
            /<script/i,
            /javascript:/i,
            /vbscript:/i,
            /onload=/i,
            /onerror=/i
        ];
        
        const fileString = fileBuffer.toString('utf8', 0, Math.min(1024, fileBuffer.length));
        for (const pattern of suspiciousPatterns) {
            if (pattern.test(fileString)) {
                return {
                    isValid: false,
                    error: 'Suspicious content detected'
                };
            }
        }
        
        return {
            isValid: true,
            fileHash: fileHash
        };
        
    } catch (error) {
        return {
            isValid: false,
            error: `Validation error: ${error.message}`
        };
    }
}

async function processFileByType(fileObject, metadata, originalKey) {
    const fileType = metadata.fileType.toLowerCase();
    const fileBuffer = fileObject.Body;
    
    try {
        switch (true) {
            case ['jpg', 'jpeg', 'png', 'gif', 'webp'].includes(fileType):
                return await processImage(fileBuffer, metadata, originalKey);
            
            case ['mp4', 'avi', 'mov'].includes(fileType):
                return await processVideo(fileBuffer, metadata, originalKey);
            
            case ['pdf', 'doc', 'docx'].includes(fileType):
                return await processDocument(fileBuffer, metadata, originalKey);
            
            default:
                // その他のファイルはそのまま保存
                return await processGenericFile(fileBuffer, metadata, originalKey);
        }
    } catch (error) {
        return {
            success: false,
            error: error.message
        };
    }
}

async function processImage(fileBuffer, metadata, originalKey) {
    const variants = [];
    const tempFiles = [];
    
    try {
        // 元画像情報取得
        const imageInfo = await sharp(fileBuffer).metadata();
        
        // サムネイル生成（複数サイズ）
        const thumbnailSizes = [
            { name: 'thumbnail', width: 150, height: 150 },
            { name: 'small', width: 400, height: 400 },
            { name: 'medium', width: 800, height: 600 },
            { name: 'large', width: 1200, height: 900 }
        ];
        
        for (const size of thumbnailSizes) {
            if (imageInfo.width > size.width || imageInfo.height > size.height) {
                const resizedBuffer = await sharp(fileBuffer)
                    .resize(size.width, size.height, {
                        fit: 'inside',
                        withoutEnlargement: true
                    })
                    .jpeg({ quality: 85, progressive: true })
                    .toBuffer();
                
                const variantKey = `processed/${metadata.userId}/${metadata.fileId}/${size.name}.jpg`;
                
                await s3.putObject({
                    Bucket: PROCESSING_BUCKET,
                    Key: variantKey,
                    Body: resizedBuffer,
                    ContentType: 'image/jpeg',
                    Metadata: {
                        'original-file-id': metadata.fileId,
                        'variant-type': size.name,
                        'processing-timestamp': new Date().toISOString()
                    }
                }).promise();
                
                variants.push({
                    type: size.name,
                    key: variantKey,
                    size: resizedBuffer.length,
                    dimensions: `${size.width}x${size.height}`
                });
                
                tempFiles.push(variantKey);
            }
        }
        
        // WebP変換（最適化）
        const webpBuffer = await sharp(fileBuffer)
            .webp({ quality: 85, effort: 4 })
            .toBuffer();
        
        const webpKey = `processed/${metadata.userId}/${metadata.fileId}/optimized.webp`;
        
        await s3.putObject({
            Bucket: PROCESSING_BUCKET,
            Key: webpKey,
            Body: webpBuffer,
            ContentType: 'image/webp',
            Metadata: {
                'original-file-id': metadata.fileId,
                'variant-type': 'optimized',
                'processing-timestamp': new Date().toISOString()
            }
        }).promise();
        
        variants.push({
            type: 'optimized',
            key: webpKey,
            size: webpBuffer.length,
            format: 'webp'
        });
        
        tempFiles.push(webpKey);
        
        // ファイルハッシュ計算
        const fileHash = crypto.createHash('sha256').update(fileBuffer).digest('hex');
        
        return {
            success: true,
            processedFiles: variants,
            finalKey: `images/${metadata.userId}/${metadata.fileId}/${metadata.fileName}`,
            variants: variants,
            tempFiles: tempFiles,
            fileHash: fileHash,
            compressionRatio: (1 - (webpBuffer.length / fileBuffer.length)).toFixed(2)
        };
        
    } catch (error) {
        // クリーンアップ
        await cleanupTempFiles(originalKey, tempFiles);
        throw error;
    }
}

async function processVideo(fileBuffer, metadata, originalKey) {
    // 動画処理（簡易実装）
    const fileHash = crypto.createHash('sha256').update(fileBuffer).digest('hex');
    
    return {
        success: true,
        processedFiles: [],
        finalKey: `videos/${metadata.userId}/${metadata.fileId}/${metadata.fileName}`,
        variants: [],
        tempFiles: [],
        fileHash: fileHash,
        compressionRatio: 0
    };
}

async function processDocument(fileBuffer, metadata, originalKey) {
    // 文書処理（簡易実装）
    const fileHash = crypto.createHash('sha256').update(fileBuffer).digest('hex');
    
    return {
        success: true,
        processedFiles: [],
        finalKey: `documents/${metadata.userId}/${metadata.fileId}/${metadata.fileName}`,
        variants: [],
        tempFiles: [],
        fileHash: fileHash,
        compressionRatio: 0
    };
}

async function processGenericFile(fileBuffer, metadata, originalKey) {
    const fileHash = crypto.createHash('sha256').update(fileBuffer).digest('hex');
    
    return {
        success: true,
        processedFiles: [],
        finalKey: `files/${metadata.userId}/${metadata.fileId}/${metadata.fileName}`,
        variants: [],
        tempFiles: [],
        fileHash: fileHash,
        compressionRatio: 0
    };
}

async function copyToFinalBucket(processedFiles, metadata) {
    // 処理済みファイルを最終保存場所にコピー
    for (const file of processedFiles) {
        await s3.copyObject({
            Bucket: FINAL_BUCKET,
            CopySource: `${PROCESSING_BUCKET}/${file.key}`,
            Key: file.key.replace('processed/', ''),
            MetadataDirective: 'COPY'
        }).promise();
    }
}

async function cleanupTempFiles(originalKey, tempFiles) {
    // 一時ファイル削除
    try {
        const deletePromises = tempFiles.map(key => 
            s3.deleteObject({
                Bucket: PROCESSING_BUCKET,
                Key: key
            }).promise()
        );
        
        await Promise.all(deletePromises);
    } catch (error) {
        console.error('Error cleaning up temp files:', error);
    }
}

async function notifyVirusScan(metadata, objectKey) {
    try {
        await sns.publish({
            TopicArn: VIRUS_SCAN_TOPIC,
            Message: JSON.stringify({
                fileId: metadata.fileId,
                s3Bucket: UPLOAD_BUCKET,
                s3Key: objectKey,
                userId: metadata.userId,
                fileName: metadata.fileName,
                fileSize: metadata.fileSize,
                timestamp: new Date().toISOString()
            }),
            Subject: 'File uploaded - virus scan required'
        }).promise();
    } catch (error) {
        console.error('Error notifying virus scan:', error);
    }
}

function arraysEqual(a, b) {
    return a.length === b.length && a.every((val, index) => val === b[index]);
}
```

### ステップ4: フロントエンドアップロードコンポーネント

1. **React ファイルアップロードコンポーネント**
```jsx
// src/components/FileUpload.jsx
import React, { useState, useCallback, useRef } from 'react';
import { useDropzone } from 'react-dropzone';

const FileUpload = ({ 
    userId, 
    onUploadComplete, 
    onUploadError,
    maxFileSize = 100 * 1024 * 1024, // 100MB
    allowedTypes = ['jpg', 'jpeg', 'png', 'gif', 'pdf', 'mp4'],
    multiple = false
}) => {
    const [uploads, setUploads] = useState([]);
    const [isDragging, setIsDragging] = useState(false);
    const abortControllersRef = useRef(new Map());

    const onDrop = useCallback(async (acceptedFiles, rejectedFiles) => {
        // 拒否されたファイルの処理
        rejectedFiles.forEach(file => {
            console.error('File rejected:', file.file.name, file.errors);
            onUploadError?.(file.file.name, file.errors[0].message);
        });

        // 受け入れられたファイルのアップロード開始
        for (const file of acceptedFiles) {
            await startUpload(file);
        }
    }, [userId, onUploadComplete, onUploadError]);

    const { getRootProps, getInputProps, isDragActive } = useDropzone({
        onDrop,
        onDragEnter: () => setIsDragging(true),
        onDragLeave: () => setIsDragging(false),
        accept: allowedTypes.reduce((acc, type) => {
            acc[getMimeType(type)] = [`.${type}`];
            return acc;
        }, {}),
        maxSize: maxFileSize,
        multiple,
        disabled: uploads.some(upload => upload.status === 'uploading')
    });

    const startUpload = async (file) => {
        const uploadId = `${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
        
        // アップロード状態を初期化
        setUploads(prev => [...prev, {
            id: uploadId,
            file,
            status: 'preparing',
            progress: 0,
            error: null,
            fileId: null
        }]);

        try {
            // Presigned URL取得
            const presignedData = await getPresignedUrl(file, userId);
            
            // ファイルIDを更新
            setUploads(prev => prev.map(upload => 
                upload.id === uploadId 
                    ? { ...upload, fileId: presignedData.fileId, status: 'uploading' }
                    : upload
            ));

            // ファイルアップロード実行
            await uploadFileToS3(file, presignedData, uploadId);

        } catch (error) {
            console.error('Upload error:', error);
            setUploads(prev => prev.map(upload => 
                upload.id === uploadId 
                    ? { ...upload, status: 'error', error: error.message }
                    : upload
            ));
            onUploadError?.(file.name, error.message);
        }
    };

    const getPresignedUrl = async (file, userId) => {
        const response = await fetch('/api/files/presigned-url', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${localStorage.getItem('accessToken')}`
            },
            body: JSON.stringify({
                fileName: file.name,
                fileSize: file.size,
                fileType: file.name.split('.').pop().toLowerCase(),
                contentType: file.type,
                userId: userId,
                metadata: {
                    uploadSource: 'web-app',
                    userAgent: navigator.userAgent,
                    timestamp: new Date().toISOString()
                }
            })
        });

        if (!response.ok) {
            const error = await response.json();
            throw new Error(error.message || 'Failed to get upload URL');
        }

        return response.json();
    };

    const uploadFileToS3 = async (file, presignedData, uploadId) => {
        return new Promise((resolve, reject) => {
            const formData = new FormData();
            
            // Presigned URLのフィールドを追加
            Object.keys(presignedData.fields).forEach(key => {
                formData.append(key, presignedData.fields[key]);
            });
            
            // ファイルを最後に追加
            formData.append('file', file);

            const xhr = new XMLHttpRequest();
            
            // AbortController for cancellation
            const abortController = new AbortController();
            abortControllersRef.current.set(uploadId, abortController);

            // Progress tracking
            xhr.upload.addEventListener('progress', (event) => {
                if (event.lengthComputable) {
                    const progress = Math.round((event.loaded / event.total) * 100);
                    setUploads(prev => prev.map(upload => 
                        upload.id === uploadId 
                            ? { ...upload, progress }
                            : upload
                    ));
                }
            });

            // Success handler
            xhr.addEventListener('load', () => {
                abortControllersRef.current.delete(uploadId);
                
                if (xhr.status === 204) {
                    // アップロード完了 - 処理状況を監視
                    monitorProcessing(uploadId, presignedData.fileId);
                    resolve();
                } else {
                    const error = new Error(`Upload failed with status: ${xhr.status}`);
                    reject(error);
                }
            });

            // Error handler
            xhr.addEventListener('error', () => {
                abortControllersRef.current.delete(uploadId);
                reject(new Error('Network error during upload'));
            });

            // Abort handler
            xhr.addEventListener('abort', () => {
                abortControllersRef.current.delete(uploadId);
                setUploads(prev => prev.map(upload => 
                    upload.id === uploadId 
                        ? { ...upload, status: 'cancelled' }
                        : upload
                ));
            });

            // Cancellation support
            abortController.signal.addEventListener('abort', () => {
                xhr.abort();
            });

            xhr.open('POST', presignedData.uploadUrl);
            xhr.send(formData);
        });
    };

    const monitorProcessing = async (uploadId, fileId) => {
        const maxAttempts = 30; // 5分間監視
        let attempts = 0;

        const checkStatus = async () => {
            try {
                const response = await fetch(`/api/files/${fileId}/status`, {
                    headers: {
                        'Authorization': `Bearer ${localStorage.getItem('accessToken')}`
                    }
                });

                if (response.ok) {
                    const fileData = await response.json();
                    const status = fileData.status;

                    setUploads(prev => prev.map(upload => 
                        upload.id === uploadId 
                            ? { ...upload, status: status.toLowerCase(), fileData }
                            : upload
                    ));

                    if (status === 'COMPLETED') {
                        onUploadComplete?.(fileData);
                        return;
                    } else if (status === 'VALIDATION_FAILED' || status === 'PROCESSING_FAILED' || status === 'ERROR') {
                        throw new Error(fileData.error || 'Processing failed');
                    }
                }

                // 処理中の場合は再試行
                attempts++;
                if (attempts < maxAttempts) {
                    setTimeout(checkStatus, 10000); // 10秒後に再チェック
                } else {
                    throw new Error('Processing timeout');
                }

            } catch (error) {
                setUploads(prev => prev.map(upload => 
                    upload.id === uploadId 
                        ? { ...upload, status: 'error', error: error.message }
                        : upload
                ));
                onUploadError?.(fileId, error.message);
            }
        };

        // 初回チェックは3秒後
        setTimeout(checkStatus, 3000);
    };

    const cancelUpload = (uploadId) => {
        const abortController = abortControllersRef.current.get(uploadId);
        if (abortController) {
            abortController.abort();
        }
    };

    const removeUpload = (uploadId) => {
        setUploads(prev => prev.filter(upload => upload.id !== uploadId));
        cancelUpload(uploadId);
    };

    const getMimeType = (extension) => {
        const mimeTypes = {
            jpg: 'image/jpeg',
            jpeg: 'image/jpeg',
            png: 'image/png',
            gif: 'image/gif',
            webp: 'image/webp',
            mp4: 'video/mp4',
            avi: 'video/avi',
            mov: 'video/mov',
            pdf: 'application/pdf',
            doc: 'application/msword',
            docx: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
        };
        return mimeTypes[extension] || 'application/octet-stream';
    };

    return (
        <div className="file-upload-container">
            {/* Drop Zone */}
            <div
                {...getRootProps()}
                className={`drop-zone ${isDragActive ? 'drag-active' : ''} ${isDragging ? 'dragging' : ''}`}
            >
                <input {...getInputProps()} />
                <div className="drop-zone-content">
                    <div className="upload-icon">📁</div>
                    <p className="upload-text">
                        {isDragActive
                            ? 'ファイルをここにドロップしてください'
                            : 'ファイルをドラッグ&ドロップするか、クリックして選択してください'
                        }
                    </p>
                    <p className="upload-info">
                        最大サイズ: {(maxFileSize / 1024 / 1024).toFixed(0)}MB | 
                        対応形式: {allowedTypes.join(', ')}
                    </p>
                </div>
            </div>

            {/* Upload Progress */}
            {uploads.length > 0 && (
                <div className="upload-list">
                    <h3>アップロード状況</h3>
                    {uploads.map((upload) => (
                        <UploadItem
                            key={upload.id}
                            upload={upload}
                            onCancel={() => cancelUpload(upload.id)}
                            onRemove={() => removeUpload(upload.id)}
                        />
                    ))}
                </div>
            )}
        </div>
    );
};

const UploadItem = ({ upload, onCancel, onRemove }) => {
    const getStatusColor = (status) => {
        const colors = {
            preparing: '#f39c12',
            uploading: '#3498db',
            processing: '#9b59b6',
            completed: '#2ecc71',
            error: '#e74c3c',
            cancelled: '#95a5a6'
        };
        return colors[status] || '#bdc3c7';
    };

    const getStatusText = (status) => {
        const texts = {
            preparing: '準備中...',
            uploading: 'アップロード中...',
            processing: '処理中...',
            completed: '完了',
            error: 'エラー',
            cancelled: 'キャンセル済み'
        };
        return texts[status] || status;
    };

    return (
        <div className="upload-item">
            <div className="upload-info">
                <div className="file-name">{upload.file.name}</div>
                <div className="file-size">
                    {(upload.file.size / 1024 / 1024).toFixed(2)} MB
                </div>
            </div>
            
            <div className="upload-progress">
                <div className="progress-bar">
                    <div 
                        className="progress-fill"
                        style={{ 
                            width: `${upload.progress}%`,
                            backgroundColor: getStatusColor(upload.status)
                        }}
                    />
                </div>
                <div className="progress-text">
                    {upload.progress}% - {getStatusText(upload.status)}
                </div>
            </div>

            {upload.error && (
                <div className="error-message">
                    エラー: {upload.error}
                </div>
            )}

            <div className="upload-actions">
                {upload.status === 'uploading' && (
                    <button onClick={onCancel} className="cancel-button">
                        キャンセル
                    </button>
                )}
                {(['error', 'cancelled', 'completed'].includes(upload.status)) && (
                    <button onClick={onRemove} className="remove-button">
                        削除
                    </button>
                )}
            </div>
        </div>
    );
};

export default FileUpload;
```

2. **CSS スタイル**
```css
/* src/components/FileUpload.css */
.file-upload-container {
    max-width: 600px;
    margin: 0 auto;
    padding: 20px;
}

.drop-zone {
    border: 2px dashed #bdc3c7;
    border-radius: 10px;
    padding: 40px 20px;
    text-align: center;
    cursor: pointer;
    transition: all 0.3s ease;
    background-color: #f8f9fa;
}

.drop-zone:hover {
    border-color: #3498db;
    background-color: #ebf3fd;
}

.drop-zone.drag-active {
    border-color: #2ecc71;
    background-color: #d5f4e6;
}

.drop-zone.dragging {
    transform: scale(1.02);
}

.drop-zone-content {
    pointer-events: none;
}

.upload-icon {
    font-size: 48px;
    margin-bottom: 16px;
}

.upload-text {
    font-size: 16px;
    font-weight: 500;
    margin-bottom: 8px;
    color: #2c3e50;
}

.upload-info {
    font-size: 14px;
    color: #7f8c8d;
}

.upload-list {
    margin-top: 30px;
}

.upload-list h3 {
    margin-bottom: 20px;
    color: #2c3e50;
}

.upload-item {
    border: 1px solid #e0e0e0;
    border-radius: 8px;
    padding: 16px;
    margin-bottom: 12px;
    background-color: white;
    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

.upload-info {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 12px;
}

.file-name {
    font-weight: 500;
    color: #2c3e50;
    flex: 1;
    text-overflow: ellipsis;
    overflow: hidden;
    white-space: nowrap;
    margin-right: 12px;
}

.file-size {
    font-size: 12px;
    color: #7f8c8d;
    white-space: nowrap;
}

.upload-progress {
    margin-bottom: 12px;
}

.progress-bar {
    width: 100%;
    height: 8px;
    background-color: #ecf0f1;
    border-radius: 4px;
    overflow: hidden;
    margin-bottom: 8px;
}

.progress-fill {
    height: 100%;
    transition: width 0.3s ease;
    border-radius: 4px;
}

.progress-text {
    font-size: 12px;
    color: #7f8c8d;
}

.error-message {
    background-color: #fdedec;
    border: 1px solid #f1948a;
    border-radius: 4px;
    padding: 8px 12px;
    font-size: 12px;
    color: #c0392b;
    margin-bottom: 12px;
}

.upload-actions {
    display: flex;
    gap: 8px;
    justify-content: flex-end;
}

.cancel-button, .remove-button {
    padding: 6px 12px;
    border: none;
    border-radius: 4px;
    font-size: 12px;
    cursor: pointer;
    transition: background-color 0.3s ease;
}

.cancel-button {
    background-color: #e74c3c;
    color: white;
}

.cancel-button:hover {
    background-color: #c0392b;
}

.remove-button {
    background-color: #95a5a6;
    color: white;
}

.remove-button:hover {
    background-color: #7f8c8d;
}

/* レスポンシブ対応 */
@media (max-width: 768px) {
    .file-upload-container {
        padding: 16px;
    }
    
    .drop-zone {
        padding: 30px 16px;
    }
    
    .upload-info {
        flex-direction: column;
        align-items: flex-start;
        gap: 4px;
    }
    
    .file-name {
        margin-right: 0;
    }
}
```

## 検証方法

### 1. アップロード機能テスト
```bash
# ファイルアップロードAPIテスト
curl -X POST https://api.example.com/files/presigned-url \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "fileName": "test.jpg",
    "fileSize": 1024000,
    "fileType": "jpg",
    "contentType": "image/jpeg",
    "userId": "user123"
  }'

# ファイル状態確認
curl -X GET https://api.example.com/files/FILE_ID/status \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### 2. 画像処理テスト
```javascript
// 画像処理結果確認
const testImageProcessing = async (fileId) => {
    const response = await fetch(`/api/files/${fileId}`);
    const fileData = await response.json();
    
    console.log('Original file:', fileData.originalFile);
    console.log('Processed variants:', fileData.variants);
    console.log('Compression ratio:', fileData.compressionRatio);
};
```

### 3. セキュリティテスト
```bash
# 悪意のあるファイルアップロードテスト
# (テスト環境でのみ実行)
echo '<script>alert("xss")</script>' > malicious.jpg
curl -X POST PRESIGNED_URL -F file=@malicious.jpg
```

## トラブルシューティング

### よくある問題と解決策

#### 1. アップロード失敗
**症状**: 403 Forbidden エラー
**解決策**:
- Presigned URLの有効期限確認
- CORS設定の確認
- S3バケットポリシーの確認

#### 2. 画像処理エラー
**症状**: Lambda関数でメモリ不足
**解決策**:
- Lambda関数のメモリ設定増加
- 画像サイズ制限の実装
- ストリーミング処理の導入

#### 3. 処理時間超過
**症状**: Lambda関数タイムアウト
**解決策**:
- Step Functionsによる非同期処理
- SQSキューによる分散処理
- 大容量ファイルの分割処理

## 学習リソース

### AWS公式ドキュメント
- [Amazon S3 User Guide](https://docs.aws.amazon.com/s3/latest/userguide/)
- [Lambda Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html)
- [CloudFront Developer Guide](https://docs.aws.amazon.com/cloudfront/latest/developerguide/)

### 追加学習教材
- [Sharp Image Processing Library](https://sharp.pixelplumbing.com/)
- [FFmpeg Video Processing](https://ffmpeg.org/documentation.html)

## セキュリティとコストの考慮事項

### セキュリティベストプラクティス
1. **ファイル検証**: マジックナンバー・ウイルススキャン
2. **アクセス制御**: IAMロール・Presigned URL期限
3. **ネットワーク分離**: VPC・プライベートサブネット
4. **監査ログ**: CloudTrail・S3アクセスログ

### コスト最適化
1. **ストレージクラス**: 適切なS3ストレージクラス選択
2. **ライフサイクル**: 自動削除・アーカイブポリシー
3. **Lambda最適化**: 適切なメモリ・タイムアウト設定
4. **CloudFront**: キャッシュ戦略とPriceClass選択

### AWS Well-Architectedフレームワークとの関連
- **運用性の柱**: CloudWatch監視・自動化・ログ管理
- **セキュリティの柱**: 暗号化・アクセス制御・ファイル検証
- **信頼性の柱**: Multi-AZ・レプリケーション・エラーハンドリング
- **パフォーマンス効率の柱**: CloudFront・適切なインスタンスサイズ
- **コスト最適化の柱**: ストレージ最適化・ライフサイクル・適切なリソース設定

## 次のステップ

### 推奨される学習パス
1. **3.2.2 リアルタイム更新**: WebSocketによるリアルタイム通知
2. **4.1.2 ETLパイプライン**: 大規模ファイル処理
3. **5.2.3 画像生成機能**: AI連携ファイル処理
4. **6.1.1 マルチステージビルド**: ファイル処理CI/CD

### 発展的な機能
1. **Step Functions**: 複雑な処理ワークフロー
2. **MediaConvert**: プロフェッショナル動画処理
3. **Rekognition**: AI画像解析
4. **Textract**: OCR・文書解析

### 実践プロジェクトのアイデア
1. **写真共有アプリ**: SNS型ファイル共有
2. **動画配信プラットフォーム**: ストリーミング配信
3. **文書管理システム**: OCR・検索機能付き
4. **デジタルアセット管理**: 企業向けファイル管理