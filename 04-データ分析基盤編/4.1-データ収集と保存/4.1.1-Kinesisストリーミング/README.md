# 4.1.1 Kinesisストリーミング

## 学習目標

このセクションでは、Amazon Kinesis Data Streamsを活用したリアルタイムデータストリーミング基盤の構築を学習し、大量データの収集・配信・分析を行う高性能なデータパイプラインの実装方法を習得します。

### 習得できるスキル
- Kinesis Data Streams によるリアルタイムデータ収集
- Lambda と Kinesis の統合によるストリーム処理
- Kinesis Analytics を活用したリアルタイム分析
- Kinesis Firehose による S3・Redshift への配信
- CloudWatch を使用したストリーミング監視
- バックプレッシャー対応とエラーハンドリング

## 前提知識

### 必須の知識
- AWS Lambda の基本操作（1.2.3セクション完了）
- JSON データ形式の理解
- ストリーミングデータの基本概念
- CloudFormation の基本操作（1.1.1セクション完了）

### あると望ましい知識
- Apache Kafka などのストリーミング技術
- リアルタイム分析の概念
- 時系列データの処理
- 分散システムの基本理解

## アーキテクチャ概要

### Kinesis ストリーミングアーキテクチャ

```
                    ┌─────────────────────┐
                    │   Data Sources      │
                    │ (Web/Mobile/IoT/    │
                    │  APIs/Logs)         │
                    └─────────┬───────────┘
                              │
                    ┌─────────┼───────────┐
                    │         │           │
                    ▼         ▼           ▼
          ┌─────────────────┐ ┌──────────┐ ┌─────────────────┐
          │   Web Apps      │ │  Mobile  │ │   IoT Devices   │
          │   (Kinesis      │ │  Apps    │ │   (SDK/Agent)   │
          │    SDK)         │ │          │ │                 │
          └─────────┬───────┘ └────┬─────┘ └─────────┬───────┘
                    │              │                 │
                    └──────────────┼─────────────────┘
                                   │
                                   ▼
          ┌─────────────────────────────────────────────────────────┐
          │              Amazon Kinesis Data Streams                │
          │                                                         │
          │  ┌─────────────────────────────────────────────────┐   │
          │  │                 Stream Shards                   │   │
          │  │                                                  │   │
          │  │  ┌─────────────┐  ┌─────────────┐  ┌──────────┐ │   │
          │  │  │   Shard 1   │  │   Shard 2   │  │ Shard N  │ │   │
          │  │  │             │  │             │  │          │ │   │
          │  │  │ ┌─────────┐ │  │ ┌─────────┐ │  │┌────────┐│ │   │
          │  │  │ │Records  │ │  │ │Records  │ │  ││Records ││ │   │
          │  │  │ │Queue    │ │  │ │Queue    │ │  ││Queue   ││ │   │
          │  │  │ │(24hrs)  │ │  │ │(24hrs)  │ │  ││(24hrs) ││ │   │
          │  │  │ └─────────┘ │  │ └─────────┘ │  │└────────┘│ │   │
          │  │  └─────────────┘  └─────────────┘  └──────────┘ │   │
          │  └─────────────────────────────────────────────────┘   │
          └─────────────────────────────────────────────────────────┘
                                   │
                    ┌──────────────┼──────────────┐
                    │              │              │
                    ▼              ▼              ▼
          ┌─────────────────┐ ┌──────────┐ ┌─────────────────┐
          │   Lambda        │ │Kinesis   │ │   Kinesis       │
          │ (Real-time      │ │Analytics │ │   Firehose      │
          │  Processing)    │ │          │ │                 │
          │                 │ │┌────────┐│ │ ┌─────────────┐ │
          │ ┌─────────────┐ │ ││SQL     ││ │ │   S3        │ │
          │ │Filtering    │ │ ││Queries ││ │ │   Redshift  │ │
          │ │Enrichment   │ │ ││Windows ││ │ │   OpenSearch│ │
          │ │Aggregation  │ │ │└────────┘│ │ │   Splunk    │ │
          │ │Transform    │ │ └──────────┘ │ └─────────────┘ │
          │ └─────────────┘ │              └─────────────────┘
          └─────────┬───────┘                       │
                    │                               │
                    ▼                               ▼
          ┌─────────────────────────────────────────────────────────┐
          │               Downstream Systems                        │
          │                                                         │
          │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │
          │  │   DynamoDB  │  │   RDS       │  │   SQS       │   │
          │  │  (Real-time │  │ (Analytics  │  │ (Async      │   │
          │  │   Updates)  │  │   Store)    │  │Processing)  │   │
          │  └─────────────┘  └─────────────┘  └─────────────┘   │
          │                                                         │
          │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │
          │  │   SNS       │  │CloudWatch   │  │   Custom    │   │
          │  │(Notifications)│ │  Metrics    │  │ Applications│   │
          │  └─────────────┘  └─────────────┘  └─────────────┘   │
          └─────────────────────────────────────────────────────────┘
```

### 主要コンポーネント
- **Kinesis Data Streams**: リアルタイムデータストリーミング
- **Kinesis Data Analytics**: SQL によるリアルタイム分析
- **Kinesis Data Firehose**: バッチ配信サービス
- **Lambda Functions**: ストリーム処理とデータ変換
- **CloudWatch**: 監視・アラート・メトリクス
- **Auto Scaling**: 動的シャード調整

## ハンズオン手順

### ステップ1: Kinesis Data Streams の構築

1. **CloudFormation による Kinesis インフラ**
```yaml
# cloudformation/kinesis-streaming.yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Kinesis Data Streaming Infrastructure'

Parameters:
  ProjectName:
    Type: String
    Default: 'kinesis-streaming'
  
  EnvironmentName:
    Type: String
    Default: 'dev'
    AllowedValues: [dev, staging, prod]
  
  InitialShardCount:
    Type: Number
    Default: 2
    MinValue: 1
    MaxValue: 100
    Description: 'Initial number of shards for the Kinesis stream'
  
  RetentionPeriod:
    Type: Number
    Default: 24
    MinValue: 24
    MaxValue: 168
    Description: 'Data retention period in hours'

Conditions:
  IsProduction: !Equals [!Ref EnvironmentName, 'prod']

Resources:
  # Kinesis Data Stream
  DataStream:
    Type: AWS::Kinesis::Stream
    Properties:
      Name: !Sub '${ProjectName}-${EnvironmentName}-data-stream'
      ShardCount: !Ref InitialShardCount
      RetentionPeriodHours: !Ref RetentionPeriod
      
      # サーバーサイド暗号化
      StreamEncryption:
        EncryptionType: KMS
        KeyId: !Ref KinesisKMSKey
      
      # ストリーム設定
      StreamModeDetails:
        StreamMode: PROVISIONED
      
      Tags:
        - Key: Environment
          Value: !Ref EnvironmentName
        - Key: Project
          Value: !Ref ProjectName
        - Key: Purpose
          Value: 'Real-time data streaming'
  
  # Kinesis Data Analytics Application
  AnalyticsApplication:
    Type: AWS::KinesisAnalytics::Application
    Properties:
      ApplicationName: !Sub '${ProjectName}-${EnvironmentName}-analytics'
      ApplicationDescription: 'Real-time stream analytics application'
      
      # アプリケーション設定
      ApplicationCode: |
        CREATE OR REPLACE STREAM "DESTINATION_SQL_STREAM" (
          event_time TIMESTAMP,
          user_id VARCHAR(32),
          event_type VARCHAR(64),
          event_count INTEGER,
          avg_value DOUBLE
        );
        
        CREATE OR REPLACE PUMP "STREAM_PUMP" AS INSERT INTO "DESTINATION_SQL_STREAM"
        SELECT STREAM 
          ROWTIME_TO_TIMESTAMP(ROWTIME) as event_time,
          user_id,
          event_type,
          COUNT(*) as event_count,
          AVG(event_value) as avg_value
        FROM "SOURCE_SQL_STREAM_001"
        WHERE event_type IS NOT NULL
        GROUP BY 
          user_id, 
          event_type,
          ROWTIME RANGE INTERVAL '1' MINUTE;
      
      # 入力設定
      Inputs:
        - NamePrefix: "SOURCE_SQL_STREAM"
          InputSchema:
            RecordColumns:
              - Name: "event_time"
                SqlType: "TIMESTAMP"
                Mapping: "$.timestamp"
              - Name: "user_id" 
                SqlType: "VARCHAR(32)"
                Mapping: "$.userId"
              - Name: "event_type"
                SqlType: "VARCHAR(64)"
                Mapping: "$.eventType"
              - Name: "event_value"
                SqlType: "DOUBLE"
                Mapping: "$.value"
              - Name: "metadata"
                SqlType: "VARCHAR(1024)"
                Mapping: "$.metadata"
            RecordFormat:
              RecordFormatType: "JSON"
              MappingParameters:
                JSONMappingParameters:
                  RecordRowPath: "$"
          KinesisStreamsInput:
            ResourceARN: !GetAtt DataStream.Arn
            RoleARN: !GetAtt AnalyticsRole.Arn
  
  # Kinesis Data Firehose
  DeliveryStream:
    Type: AWS::KinesisFirehose::DeliveryStream
    Properties:
      DeliveryStreamName: !Sub '${ProjectName}-${EnvironmentName}-delivery-stream'
      DeliveryStreamType: KinesisStreamAsSource
      
      # Kinesis Stream設定
      KinesisStreamSourceConfiguration:
        KinesisStreamARN: !GetAtt DataStream.Arn
        RoleARN: !GetAtt FirehoseRole.Arn
      
      # S3配信設定
      S3DestinationConfiguration:
        BucketARN: !GetAtt DataLakeBucket.Arn
        Prefix: 'year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/'
        ErrorOutputPrefix: 'errors/'
        RoleARN: !GetAtt FirehoseRole.Arn
        
        # バッファリング設定
        BufferingHints:
          SizeInMBs: 5
          IntervalInSeconds: 300
        
        # 圧縮設定
        CompressionFormat: GZIP
        
        # データ変換設定
        ProcessingConfiguration:
          Enabled: true
          Processors:
            - Type: Lambda
              Parameters:
                - ParameterName: LambdaArn
                  ParameterValue: !GetAtt DataTransformFunction.Arn
        
        # CloudWatch ログ設定
        CloudWatchLoggingOptions:
          Enabled: true
          LogGroupName: !Ref FirehoseLogGroup
          LogStreamName: !Sub '${ProjectName}-${EnvironmentName}-delivery-stream'

  # Lambda Functions
  StreamProcessorFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: !Sub '${ProjectName}-${EnvironmentName}-stream-processor'
      Runtime: python3.9
      Handler: index.lambda_handler
      Role: !GetAtt LambdaExecutionRole.Arn
      Code:
        ZipFile: |
          import json
          import boto3
          import base64
          import logging
          from datetime import datetime
          
          logger = logging.getLogger()
          logger.setLevel(logging.INFO)
          
          dynamodb = boto3.resource('dynamodb')
          cloudwatch = boto3.client('cloudwatch')
          
          def lambda_handler(event, context):
              logger.info(f"Processing {len(event['Records'])} records")
              
              processed_records = 0
              failed_records = 0
              
              for record in event['Records']:
                  try:
                      # Kinesisデータのデコード
                      payload = base64.b64decode(record['kinesis']['data'])
                      data = json.loads(payload)
                      
                      # データ処理
                      processed_data = process_record(data)
                      
                      # DynamoDBへの保存
                      save_to_dynamodb(processed_data)
                      
                      # カスタムメトリクス送信
                      send_metrics(processed_data)
                      
                      processed_records += 1
                      
                  except Exception as e:
                      logger.error(f"Error processing record: {e}")
                      failed_records += 1
              
              logger.info(f"Processed: {processed_records}, Failed: {failed_records}")
              
              return {
                  'batchItemFailures': []  # 全件成功の場合
              }
          
          def process_record(data):
              # データエンリッチメント
              processed = {
                  **data,
                  'processed_at': datetime.utcnow().isoformat(),
                  'processing_version': '1.0'
              }
              
              # データバリデーション
              if 'user_id' not in data:
                  raise ValueError("Missing user_id")
              if 'event_type' not in data:
                  raise ValueError("Missing event_type")
              
              # データ正規化
              processed['user_id'] = str(data['user_id']).strip()
              processed['event_type'] = data['event_type'].upper()
              
              return processed
          
          def save_to_dynamodb(data):
              table_name = os.environ['DYNAMODB_TABLE_NAME']
              table = dynamodb.Table(table_name)
              
              table.put_item(Item=data)
          
          def send_metrics(data):
              cloudwatch.put_metric_data(
                  Namespace='KinesisProcessing',
                  MetricData=[
                      {
                          'MetricName': 'RecordsProcessed',
                          'Value': 1,
                          'Unit': 'Count',
                          'Dimensions': [
                              {
                                  'Name': 'EventType',
                                  'Value': data.get('event_type', 'unknown')
                              }
                          ]
                      }
                  ]
              )
      
      Environment:
        Variables:
          DYNAMODB_TABLE_NAME: !Ref ProcessedDataTable
      
      Timeout: 60
      MemorySize: 512
      ReservedConcurrencyLimit: !If [IsProduction, 100, 10]
      
      # デッドレターキュー設定
      DeadLetterQueue:
        TargetArn: !GetAtt DeadLetterQueue.Arn
      
      # X-Ray トレーシング
      TracingConfig:
        Mode: Active

  # Kinesis Trigger
  StreamEventSourceMapping:
    Type: AWS::Lambda::EventSourceMapping
    Properties:
      EventSourceArn: !GetAtt DataStream.Arn
      FunctionName: !Ref StreamProcessorFunction
      StartingPosition: LATEST
      BatchSize: 100
      MaximumBatchingWindowInSeconds: 5
      ParallelizationFactor: 2
      
      # エラーハンドリング
      MaximumRetryAttempts: 3
      BisectBatchOnFunctionError: true
      MaximumRecordAgeInSeconds: 3600
      
      # 送信先設定
      DestinationConfig:
        OnFailure:
          Destination: !GetAtt FailureQueue.Arn

  # Data Transform Function (for Firehose)
  DataTransformFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: !Sub '${ProjectName}-${EnvironmentName}-data-transform'
      Runtime: python3.9
      Handler: index.lambda_handler
      Role: !GetAtt LambdaExecutionRole.Arn
      Code:
        ZipFile: |
          import json
          import base64
          import gzip
          from datetime import datetime
          
          def lambda_handler(event, context):
              output = []
              
              for record in event['records']:
                  # データのデコード
                  payload = base64.b64decode(record['data'])
                  data = json.loads(payload)
                  
                  # データ変換
                  transformed_data = {
                      **data,
                      'transform_timestamp': datetime.utcnow().isoformat(),
                      'partition_key': data.get('event_type', 'unknown')
                  }
                  
                  # 変換後データのエンコード
                  transformed_payload = json.dumps(transformed_data) + '\n'
                  encoded_data = base64.b64encode(transformed_payload.encode('utf-8')).decode('utf-8')
                  
                  output.append({
                      'recordId': record['recordId'],
                      'result': 'Ok',
                      'data': encoded_data
                  })
              
              return {'records': output}
      
      Timeout: 60
      MemorySize: 128

  # DynamoDB Table for processed data
  ProcessedDataTable:
    Type: AWS::DynamoDB::Table
    Properties:
      TableName: !Sub '${ProjectName}-${EnvironmentName}-processed-data'
      BillingMode: PAY_PER_REQUEST
      
      AttributeDefinitions:
        - AttributeName: user_id
          AttributeType: S
        - AttributeName: timestamp
          AttributeType: S
        - AttributeName: event_type
          AttributeType: S
      
      KeySchema:
        - AttributeName: user_id
          KeyType: HASH
        - AttributeName: timestamp
          KeyType: RANGE
      
      GlobalSecondaryIndexes:
        - IndexName: event-type-index
          KeySchema:
            - AttributeName: event_type
              KeyType: HASH
            - AttributeName: timestamp
              KeyType: RANGE
          Projection:
            ProjectionType: ALL
      
      # TTL設定（30日後自動削除）
      TimeToLiveSpecification:
        AttributeName: ttl
        Enabled: true
      
      # Point-in-Time Recovery
      PointInTimeRecoverySpecification:
        PointInTimeRecoveryEnabled: true
      
      # ストリーム設定
      StreamSpecification:
        StreamViewType: NEW_AND_OLD_IMAGES

  # S3 Bucket for Data Lake
  DataLakeBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Sub '${ProjectName}-${EnvironmentName}-data-lake-${AWS::AccountId}'
      
      # バージョニング
      VersioningConfiguration:
        Status: Enabled
      
      # 暗号化
      BucketEncryption:
        ServerSideEncryptionConfiguration:
          - ServerSideEncryptionByDefault:
              SSEAlgorithm: aws:kms
              KMSMasterKeyID: !Ref S3KMSKey
            BucketKeyEnabled: true
      
      # ライフサイクル管理
      LifecycleConfiguration:
        Rules:
          - Id: DataArchiving
            Status: Enabled
            Transitions:
              - TransitionInDays: 30
                StorageClass: STANDARD_IA
              - TransitionInDays: 90
                StorageClass: GLACIER
              - TransitionInDays: 365
                StorageClass: DEEP_ARCHIVE
      
      # パブリックアクセスブロック
      PublicAccessBlockConfiguration:
        BlockPublicAcls: true
        BlockPublicPolicy: true
        IgnorePublicAcls: true
        RestrictPublicBuckets: true

  # CloudWatch Monitoring
  StreamMetricsAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: !Sub '${ProjectName}-${EnvironmentName}-stream-incoming-records'
      AlarmDescription: 'Monitor incoming records to Kinesis stream'
      MetricName: IncomingRecords
      Namespace: AWS/Kinesis
      Statistic: Sum
      Period: 300
      EvaluationPeriods: 2
      Threshold: 1000
      ComparisonOperator: GreaterThanThreshold
      Dimensions:
        - Name: StreamName
          Value: !Ref DataStream
      AlarmActions:
        - !Ref SNSAlarmTopic

  # KMS Keys
  KinesisKMSKey:
    Type: AWS::KMS::Key
    Properties:
      Description: 'KMS key for Kinesis stream encryption'
      KeyPolicy:
        Version: '2012-10-17'
        Statement:
          - Sid: Enable IAM User Permissions
            Effect: Allow
            Principal:
              AWS: !Sub 'arn:aws:iam::${AWS::AccountId}:root'
            Action: 'kms:*'
            Resource: '*'
          - Sid: Allow Kinesis Service
            Effect: Allow
            Principal:
              Service: kinesis.amazonaws.com
            Action:
              - kms:Encrypt
              - kms:Decrypt
              - kms:ReEncrypt*
              - kms:GenerateDataKey*
              - kms:DescribeKey
            Resource: '*'

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
        - arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess
      Policies:
        - PolicyName: KinesisAccess
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - kinesis:DescribeStream
                  - kinesis:GetShardIterator
                  - kinesis:GetRecords
                  - kinesis:ListStreams
                Resource: !GetAtt DataStream.Arn
        - PolicyName: DynamoDBAccess
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - dynamodb:PutItem
                  - dynamodb:GetItem
                  - dynamodb:UpdateItem
                  - dynamodb:DeleteItem
                  - dynamodb:Query
                  - dynamodb:Scan
                Resource: 
                  - !GetAtt ProcessedDataTable.Arn
                  - !Sub '${ProcessedDataTable.Arn}/index/*'

Outputs:
  DataStreamName:
    Description: 'Kinesis Data Stream Name'
    Value: !Ref DataStream
    Export:
      Name: !Sub '${AWS::StackName}-DataStreamName'
  
  DataStreamArn:
    Description: 'Kinesis Data Stream ARN'
    Value: !GetAtt DataStream.Arn
    Export:
      Name: !Sub '${AWS::StackName}-DataStreamArn'
  
  AnalyticsApplicationName:
    Description: 'Kinesis Analytics Application Name'
    Value: !Ref AnalyticsApplication
    Export:
      Name: !Sub '${AWS::StackName}-AnalyticsApp'
```

### ステップ2: データ生成と送信クライアント

1. **Python データ生成スクリプト**
```python
# src/data-generator/kinesis_producer.py
import boto3
import json
import random
import time
import uuid
from datetime import datetime, timezone
from concurrent.futures import ThreadPoolExecutor
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class KinesisDataGenerator:
    def __init__(self, stream_name, region='ap-northeast-1'):
        self.kinesis_client = boto3.client('kinesis', region_name=region)
        self.stream_name = stream_name
        self.user_ids = [f"user_{i:04d}" for i in range(1, 1001)]  # 1000ユーザー
        self.event_types = [
            'page_view', 'click', 'purchase', 'login', 'logout',
            'search', 'add_to_cart', 'checkout', 'review', 'share'
        ]
        
    def generate_event(self):
        """単一イベントデータの生成"""
        event = {
            'event_id': str(uuid.uuid4()),
            'timestamp': datetime.now(timezone.utc).isoformat(),
            'user_id': random.choice(self.user_ids),
            'event_type': random.choice(self.event_types),
            'value': round(random.uniform(1.0, 100.0), 2),
            'metadata': {
                'device': random.choice(['desktop', 'mobile', 'tablet']),
                'browser': random.choice(['chrome', 'firefox', 'safari', 'edge']),
                'country': random.choice(['JP', 'US', 'UK', 'DE', 'FR']),
                'session_id': str(uuid.uuid4())[:8]
            }
        }
        return event
    
    def put_record(self, event):
        """単一レコードの送信"""
        try:
            response = self.kinesis_client.put_record(
                StreamName=self.stream_name,
                Data=json.dumps(event),
                PartitionKey=event['user_id']
            )
            return {
                'success': True,
                'sequence_number': response['SequenceNumber'],
                'shard_id': response['ShardId']
            }
        except Exception as e:
            logger.error(f"Failed to put record: {e}")
            return {'success': False, 'error': str(e)}
    
    def put_records_batch(self, events):
        """バッチレコード送信"""
        records = []
        for event in events:
            records.append({
                'Data': json.dumps(event),
                'PartitionKey': event['user_id']
            })
        
        try:
            response = self.kinesis_client.put_records(
                Records=records,
                StreamName=self.stream_name
            )
            
            # 失敗レコードの確認
            failed_count = response['FailedRecordCount']
            if failed_count > 0:
                logger.warning(f"Failed to send {failed_count} records")
                
                # 失敗レコードの再試行ロジック
                failed_records = []
                for i, record in enumerate(response['Records']):
                    if 'ErrorCode' in record:
                        failed_records.append(records[i])
                
                if failed_records:
                    self._retry_failed_records(failed_records)
            
            return {
                'success': True,
                'processed_count': len(records) - failed_count,
                'failed_count': failed_count
            }
            
        except Exception as e:
            logger.error(f"Failed to put records batch: {e}")
            return {'success': False, 'error': str(e)}
    
    def _retry_failed_records(self, failed_records, max_retries=3):
        """失敗レコードの再試行"""
        for attempt in range(max_retries):
            try:
                response = self.kinesis_client.put_records(
                    Records=failed_records,
                    StreamName=self.stream_name
                )
                
                if response['FailedRecordCount'] == 0:
                    logger.info(f"Successfully retried all failed records on attempt {attempt + 1}")
                    break
                    
            except Exception as e:
                logger.error(f"Retry attempt {attempt + 1} failed: {e}")
                time.sleep(2 ** attempt)  # 指数バックオフ
    
    def generate_continuous_stream(self, events_per_second=10, duration_seconds=60):
        """継続的なデータストリーム生成"""
        logger.info(f"Starting continuous stream: {events_per_second} events/sec for {duration_seconds} seconds")
        
        total_events = 0
        batch_size = min(500, events_per_second)  # Kinesis put_records の制限
        
        start_time = time.time()
        end_time = start_time + duration_seconds
        
        with ThreadPoolExecutor(max_workers=5) as executor:
            while time.time() < end_time:
                batch_start = time.time()
                
                # バッチイベント生成
                events = [self.generate_event() for _ in range(batch_size)]
                
                # 非同期送信
                future = executor.submit(self.put_records_batch, events)
                result = future.result(timeout=30)
                
                if result['success']:
                    total_events += result['processed_count']
                    logger.info(f"Sent batch: {result['processed_count']} events, Total: {total_events}")
                
                # レート制限
                batch_duration = time.time() - batch_start
                target_duration = batch_size / events_per_second
                
                if batch_duration < target_duration:
                    time.sleep(target_duration - batch_duration)
        
        logger.info(f"Completed: {total_events} events sent in {duration_seconds} seconds")
        return total_events
    
    def generate_burst_traffic(self, burst_events=1000, burst_duration=10):
        """バーストトラフィック生成"""
        logger.info(f"Generating burst traffic: {burst_events} events in {burst_duration} seconds")
        
        events_per_batch = 500
        total_sent = 0
        
        with ThreadPoolExecutor(max_workers=10) as executor:
            futures = []
            
            for i in range(0, burst_events, events_per_batch):
                batch_size = min(events_per_batch, burst_events - i)
                events = [self.generate_event() for _ in range(batch_size)]
                
                future = executor.submit(self.put_records_batch, events)
                futures.append(future)
            
            # 結果収集
            for future in futures:
                try:
                    result = future.result(timeout=60)
                    if result['success']:
                        total_sent += result['processed_count']
                except Exception as e:
                    logger.error(f"Burst batch failed: {e}")
        
        logger.info(f"Burst completed: {total_sent} events sent")
        return total_sent

# 使用例
if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='Kinesis Data Generator')
    parser.add_argument('--stream-name', required=True, help='Kinesis stream name')
    parser.add_argument('--mode', choices=['continuous', 'burst', 'single'], default='continuous')
    parser.add_argument('--events-per-second', type=int, default=10)
    parser.add_argument('--duration', type=int, default=60)
    parser.add_argument('--burst-events', type=int, default=1000)
    
    args = parser.parse_args()
    
    generator = KinesisDataGenerator(args.stream_name)
    
    if args.mode == 'continuous':
        generator.generate_continuous_stream(args.events_per_second, args.duration)
    elif args.mode == 'burst':
        generator.generate_burst_traffic(args.burst_events, 10)
    elif args.mode == 'single':
        event = generator.generate_event()
        result = generator.put_record(event)
        print(f"Single event result: {result}")
```

### ステップ3: リアルタイム監視と分析

1. **CloudWatch カスタムメトリクス**
```python
# src/monitoring/kinesis_monitor.py
import boto3
import json
import time
from datetime import datetime, timedelta

class KinesisMonitor:
    def __init__(self, stream_name, region='ap-northeast-1'):
        self.cloudwatch = boto3.client('cloudwatch', region_name=region)
        self.kinesis = boto3.client('kinesis', region_name=region)
        self.stream_name = stream_name
    
    def get_stream_metrics(self, period_minutes=5):
        """ストリームメトリクスの取得"""
        end_time = datetime.utcnow()
        start_time = end_time - timedelta(minutes=period_minutes)
        
        metrics = {}
        
        # 基本メトリクス
        metric_names = [
            'IncomingRecords',
            'IncomingBytes', 
            'OutgoingRecords',
            'OutgoingBytes',
            'WriteProvisionedThroughputExceeded',
            'ReadProvisionedThroughputExceeded'
        ]
        
        for metric_name in metric_names:
            response = self.cloudwatch.get_metric_statistics(
                Namespace='AWS/Kinesis',
                MetricName=metric_name,
                Dimensions=[
                    {
                        'Name': 'StreamName',
                        'Value': self.stream_name
                    }
                ],
                StartTime=start_time,
                EndTime=end_time,
                Period=300,
                Statistics=['Sum', 'Average', 'Maximum']
            )
            
            metrics[metric_name] = response['Datapoints']
        
        return metrics
    
    def get_shard_level_metrics(self):
        """シャードレベルメトリクス"""
        response = self.kinesis.describe_stream(StreamName=self.stream_name)
        shards = response['StreamDescription']['Shards']
        
        shard_metrics = {}
        
        for shard in shards:
            shard_id = shard['ShardId']
            
            # シャードレベルメトリクス取得
            end_time = datetime.utcnow()
            start_time = end_time - timedelta(minutes=5)
            
            response = self.cloudwatch.get_metric_statistics(
                Namespace='AWS/Kinesis',
                MetricName='IncomingRecords',
                Dimensions=[
                    {
                        'Name': 'StreamName',
                        'Value': self.stream_name
                    },
                    {
                        'Name': 'ShardId',
                        'Value': shard_id
                    }
                ],
                StartTime=start_time,
                EndTime=end_time,
                Period=300,
                Statistics=['Sum']
            )
            
            shard_metrics[shard_id] = {
                'metrics': response['Datapoints'],
                'hash_key_range': shard['HashKeyRange']
            }
        
        return shard_metrics
    
    def send_custom_metric(self, metric_name, value, unit='Count', dimensions=None):
        """カスタムメトリクス送信"""
        metric_data = {
            'MetricName': metric_name,
            'Value': value,
            'Unit': unit,
            'Timestamp': datetime.utcnow()
        }
        
        if dimensions:
            metric_data['Dimensions'] = dimensions
        
        self.cloudwatch.put_metric_data(
            Namespace='KinesisCustom',
            MetricData=[metric_data]
        )
    
    def check_stream_health(self):
        """ストリーム健全性チェック"""
        health_status = {
            'overall_status': 'HEALTHY',
            'issues': [],
            'recommendations': []
        }
        
        # メトリクス取得
        metrics = self.get_stream_metrics(15)  # 15分間
        
        # スループット制限チェック
        write_throttle = metrics.get('WriteProvisionedThroughputExceeded', [])
        read_throttle = metrics.get('ReadProvisionedThroughputExceeded', [])
        
        if any(point['Sum'] > 0 for point in write_throttle):
            health_status['overall_status'] = 'WARNING'
            health_status['issues'].append('Write throughput exceeded')
            health_status['recommendations'].append('Consider increasing shard count')
        
        if any(point['Sum'] > 0 for point in read_throttle):
            health_status['overall_status'] = 'WARNING'
            health_status['issues'].append('Read throughput exceeded')
            health_status['recommendations'].append('Optimize consumer applications')
        
        # レコード処理レートチェック
        incoming_records = metrics.get('IncomingRecords', [])
        outgoing_records = metrics.get('OutgoingRecords', [])
        
        if incoming_records and outgoing_records:
            avg_incoming = sum(p['Sum'] for p in incoming_records) / len(incoming_records)
            avg_outgoing = sum(p['Sum'] for p in outgoing_records) / len(outgoing_records)
            
            if avg_incoming > avg_outgoing * 1.5:
                health_status['overall_status'] = 'WARNING'
                health_status['issues'].append('Consumer lag detected')
                health_status['recommendations'].append('Scale consumer applications')
        
        return health_status

# 使用例
def main():
    monitor = KinesisMonitor('your-stream-name')
    
    # ストリーム健全性チェック
    health = monitor.check_stream_health()
    print(f"Stream Health: {health}")
    
    # メトリクス取得
    metrics = monitor.get_stream_metrics()
    print(f"Stream Metrics: {json.dumps(metrics, default=str, indent=2)}")

if __name__ == "__main__":
    main()
```

## 検証方法

### 1. データ送信テスト
```bash
# 継続的データ生成
python src/data-generator/kinesis_producer.py \
  --stream-name kinesis-streaming-dev-data-stream \
  --mode continuous \
  --events-per-second 50 \
  --duration 300

# バーストトラフィックテスト
python src/data-generator/kinesis_producer.py \
  --stream-name kinesis-streaming-dev-data-stream \
  --mode burst \
  --burst-events 5000
```

### 2. コンシューマーテスト
```python
# src/testing/kinesis_consumer_test.py
import boto3
import json
import time

def test_kinesis_consumer(stream_name):
    kinesis = boto3.client('kinesis')
    
    # ストリーム情報取得
    response = kinesis.describe_stream(StreamName=stream_name)
    shards = response['StreamDescription']['Shards']
    
    for shard in shards:
        shard_id = shard['ShardId']
        
        # シャードイテレータ取得
        iterator_response = kinesis.get_shard_iterator(
            StreamName=stream_name,
            ShardId=shard_id,
            ShardIteratorType='LATEST'
        )
        
        shard_iterator = iterator_response['ShardIterator']
        
        # レコード読み取り
        records_response = kinesis.get_records(ShardIterator=shard_iterator)
        records = records_response['Records']
        
        print(f"Shard {shard_id}: {len(records)} records")
        
        for record in records[:5]:  # 最初の5件を表示
            data = json.loads(record['Data'])
            print(f"  Record: {data}")

if __name__ == "__main__":
    test_kinesis_consumer('kinesis-streaming-dev-data-stream')
```

### 3. パフォーマンステスト
```bash
# CloudWatch メトリクス確認
aws cloudwatch get-metric-statistics \
  --namespace AWS/Kinesis \
  --metric-name IncomingRecords \
  --dimensions Name=StreamName,Value=kinesis-streaming-dev-data-stream \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-01T23:59:59Z \
  --period 3600 \
  --statistics Sum
```

## トラブルシューティング

### よくある問題と解決策

#### 1. スループット制限
**症状**: ProvisionedThroughputExceededException
**解決策**:
```bash
# シャード数増加
aws kinesis update-shard-count \
  --stream-name kinesis-streaming-dev-data-stream \
  --target-shard-count 4 \
  --scaling-type UNIFORM_SCALING
```

#### 2. コンシューマーラグ
**症状**: データ処理の遅延
**解決策**:
- Lambda 同時実行数の調整
- バッチサイズの最適化
- 並列処理ファクターの調整

#### 3. レコード順序の問題
**症状**: 順序保証が必要なデータの順序崩れ
**解決策**:
```python
# パーティションキーの最適化
partition_key = f"{user_id}#{session_id}"  # より細かい単位での順序保証
```

## 学習リソース

### AWS公式ドキュメント
- [Amazon Kinesis Data Streams Developer Guide](https://docs.aws.amazon.com/kinesis/latest/dev/)
- [Kinesis Data Analytics Developer Guide](https://docs.aws.amazon.com/kinesisanalytics/latest/dev/)
- [Kinesis Data Firehose Developer Guide](https://docs.aws.amazon.com/firehose/latest/dev/)

### 追加学習教材
- [Apache Kafka vs Amazon Kinesis](https://aws.amazon.com/kinesis/data-streams/faqs/)
- [Stream Processing Design Patterns](https://docs.aws.amazon.com/wellarchitected/latest/analytics-lens/)

## セキュリティとコストの考慮事項

### セキュリティベストプラクティス
1. **暗号化**: 保存時・転送時暗号化の実装
2. **IAM**: 最小権限アクセス制御
3. **VPCエンドポイント**: プライベート通信経路
4. **監査ログ**: CloudTrail による API コール記録

### コスト最適化
1. **シャード数**: ワークロードに応じた適切な設定
2. **保持期間**: データ保持要件に応じた設定
3. **オンデマンド**: オンデマンドモードの検討
4. **データ変換**: 効率的なデータ変換とフィルタリング

### AWS Well-Architectedフレームワークとの関連
- **運用性の柱**: CloudWatch監視・自動スケーリング
- **セキュリティの柱**: IAM・KMS・VPC・暗号化
- **信頼性の柱**: 複数AZ・エラーハンドリング・再試行
- **パフォーマンス効率の柱**: 適切なシャード数・バッチング
- **コスト最適化の柱**: オンデマンド・適切な保持期間・データ変換

## 次のステップ

### 推奨される学習パス
1. **4.1.2 ETLパイプライン**: データ変換・前処理
2. **4.2.1 QuickSightダッシュボード**: リアルタイム可視化
3. **5.2.2 RAGシステム構築**: ストリーミングデータ活用
4. **6.2.1 APM実装**: ストリーミング監視強化

### 発展的な機能
1. **Kinesis Scaling Utility**: 自動スケーリング
2. **Multi-Region Replication**: 災害復旧
3. **Amazon MSK**: Apache Kafka マネージドサービス
4. **Real-time ML**: SageMaker との統合

### 実践プロジェクトのアイデア
1. **IoTデータ処理**: センサーデータリアルタイム分析
2. **ログ分析基盤**: アプリケーションログ集約・分析
3. **リアルタイム推奨**: ユーザー行動ベース推奨システム
4. **異常検知**: リアルタイム異常検知・アラート

## 🚀 高度な実装パターン

### エンタープライズ級データパイプライン
複数のデータソースからの統合ストリーミング処理を実装します。

```python
# src/advanced/enterprise_pipeline.py
import boto3
import json
import asyncio
from concurrent.futures import ThreadPoolExecutor
from typing import Dict, List, Optional
import logging

class EnterpriseKinesisHandler:
    """エンタープライズ級Kinesisハンドラー"""
    
    def __init__(self, config: Dict):
        self.kinesis = boto3.client('kinesis')
        self.cloudwatch = boto3.client('cloudwatch')
        self.config = config
        self.logger = logging.getLogger(__name__)
        self.executor = ThreadPoolExecutor(max_workers=10)
    
    async def multi_source_ingestion(self, sources: List[Dict]):
        """複数ソースからの並列データ取り込み"""
        tasks = []
        for source in sources:
            task = asyncio.create_task(
                self._process_source(source)
            )
            tasks.append(task)
        
        results = await asyncio.gather(*tasks, return_exceptions=True)
        return self._aggregate_results(results)
    
    async def _process_source(self, source: Dict):
        """個別ソースの処理"""
        source_type = source['type']
        
        if source_type == 'database':
            return await self._process_database_source(source)
        elif source_type == 'api':
            return await self._process_api_source(source)
        elif source_type == 'file':
            return await self._process_file_source(source)
        else:
            raise ValueError(f"Unsupported source type: {source_type}")
    
    def advanced_partitioning_strategy(self, record: Dict) -> str:
        """高度なパーティショニング戦略"""
        # ビジネス要件に基づいた複合パーティションキー
        user_tier = record.get('user_tier', 'standard')
        geo_region = record.get('geo_region', 'unknown')
        event_priority = record.get('priority', 'normal')
        
        # 負荷分散とデータ局所性を考慮
        partition_components = [
            user_tier[:3],  # ユーザー階層
            geo_region[:2], # 地理的リージョン
            str(hash(record.get('user_id', '')) % 1000).zfill(3)  # 分散ハッシュ
        ]
        
        return '-'.join(partition_components)
    
    def intelligent_batching(self, records: List[Dict]) -> List[List[Dict]]:
        """インテリジェントバッチング"""
        batches = []
        current_batch = []
        current_size = 0
        max_batch_size = self.config.get('max_batch_size', 500)
        max_payload_size = self.config.get('max_payload_size', 1024 * 1024)  # 1MB
        
        for record in records:
            record_size = len(json.dumps(record).encode('utf-8'))
            
            # サイズまたは件数の制限チェック
            if (current_size + record_size > max_payload_size or 
                len(current_batch) >= max_batch_size):
                if current_batch:
                    batches.append(current_batch)
                    current_batch = []
                    current_size = 0
            
            current_batch.append(record)
            current_size += record_size
        
        if current_batch:
            batches.append(current_batch)
        
        return batches
    
    def circuit_breaker_pattern(self, func, max_failures=5, timeout=60):
        """サーキットブレーカーパターンの実装"""
        failure_count = 0
        last_failure_time = 0
        
        def wrapper(*args, **kwargs):
            nonlocal failure_count, last_failure_time
            
            # サーキットブレーカーが開いている場合
            if failure_count >= max_failures:
                if time.time() - last_failure_time < timeout:
                    raise Exception("Circuit breaker is OPEN")
                else:
                    # タイムアウト後にリセット
                    failure_count = 0
            
            try:
                result = func(*args, **kwargs)
                failure_count = 0  # 成功時にリセット
                return result
            except Exception as e:
                failure_count += 1
                last_failure_time = time.time()
                raise e
        
        return wrapper

# 使用例
async def main():
    config = {
        'max_batch_size': 500,
        'max_payload_size': 1024 * 1024,
        'stream_name': 'enterprise-data-stream'
    }
    
    handler = EnterpriseKinesisHandler(config)
    
    sources = [
        {'type': 'database', 'connection': 'postgres://...'},
        {'type': 'api', 'endpoint': 'https://api.example.com/data'},
        {'type': 'file', 'path': 's3://bucket/data/'}
    ]
    
    results = await handler.multi_source_ingestion(sources)
    print(f"Processed {len(results)} sources")

if __name__ == "__main__":
    asyncio.run(main())
```

### データ品質監視システム

```python
# src/advanced/data_quality_monitor.py
import boto3
import pandas as pd
from datetime import datetime, timedelta
import numpy as np
from typing import Dict, List, Tuple
import logging

class DataQualityMonitor:
    """データ品質リアルタイム監視"""
    
    def __init__(self, stream_name: str):
        self.stream_name = stream_name
        self.kinesis = boto3.client('kinesis')
        self.cloudwatch = boto3.client('cloudwatch')
        self.logger = logging.getLogger(__name__)
        
        # 品質メトリクス閾値
        self.quality_thresholds = {
            'completeness': 0.95,      # 完全性: 95%以上
            'uniqueness': 0.98,        # 一意性: 98%以上
            'validity': 0.99,          # 妥当性: 99%以上
            'consistency': 0.97,       # 一貫性: 97%以上
            'timeliness': 300          # 適時性: 5分以内
        }
    
    def evaluate_data_quality(self, records: List[Dict]) -> Dict:
        """データ品質評価の実行"""
        if not records:
            return self._empty_quality_report()
        
        df = pd.DataFrame(records)
        
        quality_metrics = {
            'completeness': self._check_completeness(df),
            'uniqueness': self._check_uniqueness(df),
            'validity': self._check_validity(df),
            'consistency': self._check_consistency(df),
            'timeliness': self._check_timeliness(df),
            'sample_size': len(records),
            'evaluation_time': datetime.utcnow().isoformat()
        }
        
        # 総合品質スコア計算
        quality_metrics['overall_score'] = self._calculate_overall_score(quality_metrics)
        
        # 異常検知
        anomalies = self._detect_anomalies(quality_metrics)
        quality_metrics['anomalies'] = anomalies
        
        # CloudWatchメトリクス送信
        self._send_quality_metrics(quality_metrics)
        
        return quality_metrics
    
    def _check_completeness(self, df: pd.DataFrame) -> float:
        """完全性チェック: 必須フィールドの欠損率"""
        required_fields = ['user_id', 'timestamp', 'event_type']
        
        if df.empty:
            return 0.0
        
        total_cells = len(df) * len(required_fields)
        missing_cells = 0
        
        for field in required_fields:
            if field in df.columns:
                missing_cells += df[field].isna().sum()
            else:
                missing_cells += len(df)  # フィールド自体が存在しない
        
        completeness = 1 - (missing_cells / total_cells)
        return max(0.0, completeness)
    
    def _check_uniqueness(self, df: pd.DataFrame) -> float:
        """一意性チェック: 重複レコードの検出"""
        if df.empty or 'user_id' not in df.columns:
            return 1.0
        
        unique_combinations = df.drop_duplicates(
            subset=['user_id', 'timestamp', 'event_type']
        )
        
        uniqueness = len(unique_combinations) / len(df)
        return uniqueness
    
    def _check_validity(self, df: pd.DataFrame) -> float:
        """妥当性チェック: データ形式・範囲の検証"""
        if df.empty:
            return 1.0
        
        valid_count = 0
        total_checks = 0
        
        # タイムスタンプの妥当性
        if 'timestamp' in df.columns:
            valid_timestamps = pd.to_datetime(df['timestamp'], errors='coerce').notna()
            valid_count += valid_timestamps.sum()
            total_checks += len(df)
        
        # 数値フィールドの妥当性
        if 'amount' in df.columns:
            valid_amounts = (
                pd.to_numeric(df['amount'], errors='coerce').notna() &
                (pd.to_numeric(df['amount'], errors='coerce') >= 0)
            )
            valid_count += valid_amounts.sum()
            total_checks += len(df)
        
        # イベントタイプの妥当性
        if 'event_type' in df.columns:
            valid_event_types = [
                'login', 'logout', 'purchase', 'view', 'click', 'search'
            ]
            valid_events = df['event_type'].isin(valid_event_types)
            valid_count += valid_events.sum()
            total_checks += len(df)
        
        return valid_count / total_checks if total_checks > 0 else 1.0
    
    def _check_consistency(self, df: pd.DataFrame) -> float:
        """一貫性チェック: ビジネスルールの検証"""
        if df.empty:
            return 1.0
        
        consistent_count = 0
        total_checks = 0
        
        # 購入イベントにはamountが必要
        purchase_events = df[df['event_type'] == 'purchase'] if 'event_type' in df.columns else pd.DataFrame()
        if not purchase_events.empty:
            has_amount = purchase_events['amount'].notna() if 'amount' in purchase_events.columns else pd.Series([False] * len(purchase_events))
            consistent_count += has_amount.sum()
            total_checks += len(purchase_events)
        
        # ログインとログアウトの対応
        user_sessions = df.groupby('user_id')['event_type'].apply(list) if 'user_id' in df.columns and 'event_type' in df.columns else pd.Series([])
        for session_events in user_sessions:
            login_count = session_events.count('login')
            logout_count = session_events.count('logout')
            if login_count > 0:
                consistent_count += 1 if logout_count <= login_count else 0
                total_checks += 1
        
        return consistent_count / total_checks if total_checks > 0 else 1.0
    
    def _check_timeliness(self, df: pd.DataFrame) -> float:
        """適時性チェック: データの遅延時間"""
        if df.empty or 'timestamp' in df.columns:
            return 1.0
        
        current_time = datetime.utcnow()
        timestamps = pd.to_datetime(df['timestamp'], errors='coerce')
        
        # 遅延時間計算（秒）
        delays = [(current_time - ts).total_seconds() for ts in timestamps if pd.notna(ts)]
        
        if not delays:
            return 1.0
        
        avg_delay = np.mean(delays)
        timeliness_score = max(0, 1 - (avg_delay / 3600))  # 1時間を基準
        
        return timeliness_score
    
    def _detect_anomalies(self, metrics: Dict) -> List[Dict]:
        """異常検知"""
        anomalies = []
        
        for metric_name, threshold in self.quality_thresholds.items():
            if metric_name in metrics:
                value = metrics[metric_name]
                
                if metric_name == 'timeliness':
                    if value < (1 - threshold / 3600):  # 遅延が閾値を超える
                        anomalies.append({
                            'type': 'timeliness_violation',
                            'metric': metric_name,
                            'value': value,
                            'threshold': threshold,
                            'severity': 'high' if value < 0.5 else 'medium'
                        })
                else:
                    if value < threshold:
                        anomalies.append({
                            'type': 'quality_degradation',
                            'metric': metric_name,
                            'value': value,
                            'threshold': threshold,
                            'severity': 'high' if value < threshold * 0.8 else 'medium'
                        })
        
        return anomalies

# 実用的な品質監視Lambda関数
def quality_monitor_lambda_handler(event, context):
    """Kinesisストリーム品質監視Lambda"""
    monitor = DataQualityMonitor('enterprise-data-stream')
    
    # Kinesisレコードからデータ抽出
    records = []
    for record in event['Records']:
        try:
            data = json.loads(base64.b64decode(record['kinesis']['data']))
            records.append(data)
        except Exception as e:
            print(f"Error processing record: {e}")
    
    # 品質評価実行
    quality_report = monitor.evaluate_data_quality(records)
    
    # 異常があればアラート送信
    if quality_report['anomalies']:
        send_quality_alert(quality_report)
    
    return {
        'statusCode': 200,
        'body': json.dumps(quality_report, default=str)
    }
```

### 🔧 運用自動化スクリプト

```bash
#!/bin/bash
# scripts/kinesis_operations.sh - Kinesis運用自動化スクリプト

set -e

STREAM_NAME="${1:-kinesis-streaming-dev-data-stream}"
ENVIRONMENT="${2:-dev}"

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ストリーム健全性チェック
check_stream_health() {
    print_status "Checking stream health for: $STREAM_NAME"
    
    # ストリーム存在確認
    if ! aws kinesis describe-stream --stream-name "$STREAM_NAME" >/dev/null 2>&1; then
        print_error "Stream $STREAM_NAME does not exist!"
        return 1
    fi
    
    # ストリーム状態確認
    status=$(aws kinesis describe-stream --stream-name "$STREAM_NAME" \
        --query 'StreamDescription.StreamStatus' --output text)
    
    if [ "$status" != "ACTIVE" ]; then
        print_warning "Stream status is $status (expected: ACTIVE)"
        return 1
    fi
    
    print_status "Stream $STREAM_NAME is healthy (status: $status)"
    return 0
}

# メトリクス収集と分析
collect_metrics() {
    print_status "Collecting metrics for stream: $STREAM_NAME"
    
    end_time=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    start_time=$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ)
    
    # 受信レコード数
    incoming_records=$(aws cloudwatch get-metric-statistics \
        --namespace AWS/Kinesis \
        --metric-name IncomingRecords \
        --dimensions Name=StreamName,Value="$STREAM_NAME" \
        --start-time "$start_time" \
        --end-time "$end_time" \
        --period 3600 \
        --statistics Sum \
        --query 'Datapoints[0].Sum' \
        --output text)
    
    # 送信レコード数
    outgoing_records=$(aws cloudwatch get-metric-statistics \
        --namespace AWS/Kinesis \
        --metric-name OutgoingRecords \
        --dimensions Name=StreamName,Value="$STREAM_NAME" \
        --start-time "$start_time" \
        --end-time "$end_time" \
        --period 3600 \
        --statistics Sum \
        --query 'Datapoints[0].Sum' \
        --output text)
    
    echo "=== Stream Metrics (Last 1 Hour) ==="
    echo "Incoming Records: ${incoming_records:-0}"
    echo "Outgoing Records: ${outgoing_records:-0}"
    
    # スロットリングチェック
    throttled_records=$(aws cloudwatch get-metric-statistics \
        --namespace AWS/Kinesis \
        --metric-name WriteProvisionedThroughputExceeded \
        --dimensions Name=StreamName,Value="$STREAM_NAME" \
        --start-time "$start_time" \
        --end-time "$end_time" \
        --period 3600 \
        --statistics Sum \
        --query 'Datapoints[0].Sum' \
        --output text)
    
    if [ "$throttled_records" != "None" ] && [ "$throttled_records" -gt 0 ]; then
        print_warning "Throttling detected: $throttled_records throttled requests"
    fi
}

# 自動スケーリング
auto_scale_stream() {
    current_shards=$(aws kinesis describe-stream --stream-name "$STREAM_NAME" \
        --query 'StreamDescription.Shards | length(@)' --output text)
    
    print_status "Current shard count: $current_shards"
    
    # スロットリングメトリクスに基づくスケーリング判定
    end_time=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    start_time=$(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%SZ)
    
    throttled_records=$(aws cloudwatch get-metric-statistics \
        --namespace AWS/Kinesis \
        --metric-name WriteProvisionedThroughputExceeded \
        --dimensions Name=StreamName,Value="$STREAM_NAME" \
        --start-time "$start_time" \
        --end-time "$end_time" \
        --period 600 \
        --statistics Sum \
        --query 'Datapoints[0].Sum' \
        --output text)
    
    if [ "$throttled_records" != "None" ] && [ "$throttled_records" -gt 100 ]; then
        new_shard_count=$((current_shards + 1))
        print_status "Scaling up: $current_shards -> $new_shard_count shards"
        
        aws kinesis update-shard-count \
            --stream-name "$STREAM_NAME" \
            --target-shard-count "$new_shard_count" \
            --scaling-type UNIFORM_SCALING
    fi
}

# データ品質レポート生成
generate_quality_report() {
    print_status "Generating data quality report..."
    
    # 最新のレコードサンプルを取得して品質分析
    python3 << EOF
import boto3
import json
from datetime import datetime

kinesis = boto3.client('kinesis')

# ストリーム情報取得
response = kinesis.describe_stream(StreamName='$STREAM_NAME')
shards = response['StreamDescription']['Shards']

sample_records = []
for shard in shards[:2]:  # 最初の2シャードのみサンプリング
    try:
        iterator_response = kinesis.get_shard_iterator(
            StreamName='$STREAM_NAME',
            ShardId=shard['ShardId'],
            ShardIteratorType='LATEST'
        )
        
        records_response = kinesis.get_records(
            ShardIterator=iterator_response['ShardIterator'],
            Limit=100
        )
        
        for record in records_response['Records']:
            try:
                data = json.loads(record['Data'])
                sample_records.append(data)
            except:
                pass
    except:
        pass

print(f"=== Data Quality Report ===")
print(f"Sample Size: {len(sample_records)}")

if sample_records:
    # フィールド完全性チェック
    required_fields = ['user_id', 'timestamp', 'event_type']
    completeness = {}
    
    for field in required_fields:
        present = sum(1 for record in sample_records if field in record and record[field])
        completeness[field] = (present / len(sample_records)) * 100
        print(f"{field} completeness: {completeness[field]:.1f}%")
    
    # イベントタイプ分布
    event_types = {}
    for record in sample_records:
        event_type = record.get('event_type', 'unknown')
        event_types[event_type] = event_types.get(event_type, 0) + 1
    
    print("Event Type Distribution:")
    for event_type, count in sorted(event_types.items()):
        percentage = (count / len(sample_records)) * 100
        print(f"  {event_type}: {count} ({percentage:.1f}%)")
else:
    print("No records found for analysis")
EOF
}

# メイン実行
main() {
    case "${3:-health}" in
        "health")
            check_stream_health
            ;;
        "metrics")
            collect_metrics
            ;;
        "scale")
            auto_scale_stream
            ;;
        "quality")
            generate_quality_report
            ;;
        "full")
            check_stream_health && \
            collect_metrics && \
            generate_quality_report
            ;;
        *)
            echo "Usage: $0 <stream-name> <environment> <action>"
            echo "Actions: health, metrics, scale, quality, full"
            exit 1
            ;;
    esac
}

main "$@"
```

## 📊 高度な監視・分析テンプレート

### カスタムダッシュボード定義

```json
{
  "widgets": [
    {
      "type": "metric",
      "x": 0, "y": 0,
      "width": 12, "height": 6,
      "properties": {
        "metrics": [
          ["AWS/Kinesis", "IncomingRecords", "StreamName", "kinesis-streaming-dev-data-stream"],
          [".", "OutgoingRecords", ".", "."],
          [".", "WriteProvisionedThroughputExceeded", ".", "."]
        ],
        "view": "timeSeries",
        "stacked": false,
        "region": "us-east-1",
        "title": "Kinesis Stream Throughput",
        "period": 300
      }
    },
    {
      "type": "metric",
      "x": 12, "y": 0,
      "width": 12, "height": 6,
      "properties": {
        "metrics": [
          ["DataPlatform/Kinesis", "ProcessedRecords"],
          [".", "ErrorRecords"],
          [".", "DataQualityScore"]
        ],
        "view": "timeSeries",
        "region": "us-east-1",
        "title": "Processing Metrics",
        "period": 300
      }
    }
  ]
}
```

この拡張により、以下の高度な機能が追加されました：

1. **エンタープライズ級データパイプライン**: 複数ソース統合、高度なパーティショニング、インテリジェントバッチング
2. **データ品質監視システム**: リアルタイム品質評価、異常検知、メトリクス送信
3. **運用自動化スクリプト**: 健全性チェック、自動スケーリング、品質レポート生成
4. **高度な監視**: カスタムダッシュボード、詳細メトリクス

これらの実装により、実際のエンタープライズ環境でも使用できる高品質なストリーミングデータ基盤の構築スキルを習得できます。