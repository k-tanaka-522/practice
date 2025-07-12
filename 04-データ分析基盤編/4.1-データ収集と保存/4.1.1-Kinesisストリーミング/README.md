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