# 4.1.2 ETLパイプライン

## 学習目標

このセクションでは、AWS Glue、Lambda、Stepfunctionsを活用したサーバーレスETL（Extract, Transform, Load）パイプラインを構築し、データレイクアーキテクチャにおける大規模データ処理・変換・分析基盤の実装方法を習得します。

### 習得できるスキル
- AWS Glue による大規模データ変換処理
- Apache Spark on AWS Glue でのスケーラブル処理
- Step Functions によるワークフロー自動化
- S3 データレイクアーキテクチャの設計
- Lambda による軽量データ処理
- Glue Data Catalog によるメタデータ管理

## 前提知識

### 必須の知識
- ETLの基本概念とデータパイプライン
- SQL クエリの基本操作
- Lambda 関数の開発（1.2.3セクション完了）
- S3 の基本操作（2.1.1セクション完了）

### あると望ましい知識
- Apache Spark の基本概念
- データウェアハウス設計
- 分散処理アーキテクチャ
- Parquet・ORC などのカラム型ストレージ

## アーキテクチャ概要

### サーバーレス ETL パイプラインアーキテクチャ

```
                    ┌─────────────────────┐
                    │   Data Sources      │
                    │ (Files/APIs/DBs/    │
                    │  Streaming/SaaS)    │
                    └─────────┬───────────┘
                              │
                    ┌─────────┼───────────┐
                    │         │           │
                    ▼         ▼           ▼
          ┌─────────────────┐ ┌──────────┐ ┌─────────────────┐
          │   S3 Raw        │ │Kinesis   │ │   Direct API    │
          │   Data Zone     │ │Firehose  │ │   Ingestion     │
          │   (Landing)     │ │          │ │   (Lambda)      │
          └─────────┬───────┘ └────┬─────┘ └─────────┬───────┘
                    │              │                 │
                    └──────────────┼─────────────────┘
                                   │
                                   ▼
          ┌─────────────────────────────────────────────────────────┐
          │               Step Functions Workflow                   │
          │              (ETL Orchestration)                       │
          │                                                         │
          │  ┌─────────────────────────────────────────────────┐   │
          │  │              Workflow States                    │   │
          │  │                                                  │   │
          │  │  ┌─────────────┐  ┌─────────────┐  ┌──────────┐ │   │
          │  │  │   Data      │  │ Schema      │  │ Quality  │ │   │
          │  │  │Validation   │  │ Discovery   │  │ Checks   │ │   │
          │  │  │             │  │             │  │          │ │   │
          │  │  │ ┌─────────┐ │  │ ┌─────────┐ │  │┌────────┐│ │   │
          │  │  │ │Lambda   │ │  │ │Glue     │ │  ││Lambda  ││ │   │
          │  │  │ │Format   │ │  │ │Crawler  │ │  ││DQ      ││ │   │
          │  │  │ │Check    │ │  │ │         │ │  ││Rules   ││ │   │
          │  │  │ └─────────┘ │  │ └─────────┘ │  │└────────┘│ │   │
          │  │  └─────────────┘  └─────────────┘  └──────────┘ │   │
          │  └─────────────────────────────────────────────────┘   │
          └─────────────────────────────────────────────────────────┘
                                   │
                                   ▼
          ┌─────────────────────────────────────────────────────────┐
          │                 AWS Glue Jobs                           │
          │               (Apache Spark)                            │
          │                                                         │
          │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │
          │  │Extract &    │  │ Transform   │  │   Load &    │   │
          │  │ Normalize   │  │  & Enrich   │  │  Partition  │   │
          │  │             │  │             │  │             │   │
          │  │┌──────────┐ │  │┌──────────┐ │  │┌──────────┐ │   │
          │  ││CSV->     │ │  ││Data      │ │  ││Parquet   │ │   │
          │  ││Parquet   │ │  ││Cleansing │ │  ││Partition │ │   │
          │  ││JSON->    │ │  ││Join      │ │  ││Optimize  │ │   │
          │  ││Delta     │ │  ││Aggregate │ │  ││Compress  │ │   │
          │  │└──────────┘ │  │└──────────┘ │  │└──────────┘ │   │
          │  └─────────────┘  └─────────────┘  └─────────────┘   │
          └─────────────────────────────────────────────────────────┘
                                   │
                    ┌──────────────┼──────────────┐
                    │              │              │
                    ▼              ▼              ▼
          ┌─────────────────┐ ┌──────────┐ ┌─────────────────┐
          │   S3 Curated    │ │Glue Data │ │   S3 Analytics  │
          │   Data Zone     │ │ Catalog  │ │    Zone         │
          │   (Clean)       │ │(Metadata)│ │   (Aggregated)  │
          │                 │ │          │ │                 │
          │ ┌─────────────┐ │ │┌────────┐│ │ ┌─────────────┐ │
          │ │Parquet      │ │ ││Table   ││ │ │Dimensional  │ │
          │ │Delta Lake   │ │ ││Schema  ││ │ │Data Models  │ │
          │ │Partitioned  │ │ ││Stats   ││ │ │Aggregations │ │
          │ │Compressed   │ │ │└────────┘│ │ │Summaries    │ │
          │ └─────────────┘ │ └──────────┘ │ └─────────────┘ │
          └─────────────────┘              └─────────────────┘
                    │                               │
                    ▼                               ▼
          ┌─────────────────────────────────────────────────────────┐
          │                Analytics & BI Tools                     │
          │                                                         │
          │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │
          │  │  Amazon     │  │   Amazon    │  │  QuickSight │   │
          │  │  Athena     │  │  Redshift   │  │ Dashboards  │   │
          │  │  (Query)    │  │(Data Warehouse│  │             │   │
          │  └─────────────┘  └─────────────┘  └─────────────┘   │
          └─────────────────────────────────────────────────────────┘
```

### 主要コンポーネント
- **AWS Glue**: サーバーレスETLサービス
- **Step Functions**: ワークフロー自動化・オーケストレーション
- **S3 Data Lake**: 階層化データストレージ
- **Glue Data Catalog**: 統合メタデータ管理
- **Lambda**: 軽量データ処理・トリガー
- **CloudWatch**: 監視・ログ・アラート

## ハンズオン手順

### ステップ1: S3 データレイクアーキテクチャ構築

1. **CloudFormation による S3 データレイクセットアップ**
```yaml
# cloudformation/s3-data-lake.yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'S3 Data Lake for ETL Pipeline'

Parameters:
  ProjectName:
    Type: String
    Default: 'etl-pipeline'
  
  EnvironmentName:
    Type: String
    Default: 'dev'
    AllowedValues: [dev, staging, prod]

Conditions:
  IsProduction: !Equals [!Ref EnvironmentName, 'prod']

Resources:
  # Raw Data Zone (ランディングゾーン)
  RawDataBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Sub '${ProjectName}-${EnvironmentName}-raw-data-${AWS::AccountId}'
      
      # バージョニング
      VersioningConfiguration:
        Status: Enabled
      
      # ライフサイクル管理
      LifecycleConfiguration:
        Rules:
          - Id: RawDataLifecycle
            Status: Enabled
            Transitions:
              - TransitionInDays: 30
                StorageClass: STANDARD_IA
              - TransitionInDays: 90
                StorageClass: GLACIER
              - TransitionInDays: 365
                StorageClass: DEEP_ARCHIVE
      
      # 暗号化
      BucketEncryption:
        ServerSideEncryptionConfiguration:
          - ServerSideEncryptionByDefault:
              SSEAlgorithm: aws:kms
              KMSMasterKeyID: !Ref DataLakeKMSKey
            BucketKeyEnabled: true
      
      # パブリックアクセスブロック
      PublicAccessBlockConfiguration:
        BlockPublicAcls: true
        BlockPublicPolicy: true
        IgnorePublicAcls: true
        RestrictPublicBuckets: true
      
      # イベント通知設定
      NotificationConfiguration:
        LambdaConfigurations:
          - Event: 's3:ObjectCreated:*'
            Function: !GetAtt DataIngestionTrigger.Arn
            Filter:
              S3Key:
                Rules:
                  - Name: prefix
                    Value: 'incoming/'

  # Curated Data Zone (クリーンデータ)
  CuratedDataBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Sub '${ProjectName}-${EnvironmentName}-curated-data-${AWS::AccountId}'
      
      # バージョニング
      VersioningConfiguration:
        Status: Enabled
      
      # 暗号化
      BucketEncryption:
        ServerSideEncryptionConfiguration:
          - ServerSideEncryptionByDefault:
              SSEAlgorithm: aws:kms
              KMSMasterKeyID: !Ref DataLakeKMSKey
            BucketKeyEnabled: true
      
      # インテリジェントティアリング
      IntelligentTieringConfigurations:
        - Id: CuratedDataIntelligentTiering
          Status: Enabled
          Prefix: 'processed/'
          OptionalFields:
            - BucketKeyStatus
  
  # Analytics Zone (集計データ)
  AnalyticsDataBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Sub '${ProjectName}-${EnvironmentName}-analytics-data-${AWS::AccountId}'
      
      # 暗号化
      BucketEncryption:
        ServerSideEncryptionConfiguration:
          - ServerSideEncryptionByDefault:
              SSEAlgorithm: aws:kms
              KMSMasterKeyID: !Ref DataLakeKMSKey
            BucketKeyEnabled: true
  
  # Scripts and Artifacts Bucket
  ScriptsBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Sub '${ProjectName}-${EnvironmentName}-etl-scripts-${AWS::AccountId}'
      
      # バージョニング
      VersioningConfiguration:
        Status: Enabled
      
      # 暗号化
      BucketEncryption:
        ServerSideEncryptionConfiguration:
          - ServerSideEncryptionByDefault:
              SSEAlgorithm: aws:kms
              KMSMasterKeyID: !Ref DataLakeKMSKey

  # KMS Key for Data Lake
  DataLakeKMSKey:
    Type: AWS::KMS::Key
    Properties:
      Description: 'KMS key for S3 Data Lake encryption'
      KeyPolicy:
        Version: '2012-10-17'
        Statement:
          - Sid: Enable IAM User Permissions
            Effect: Allow
            Principal:
              AWS: !Sub 'arn:aws:iam::${AWS::AccountId}:root'
            Action: 'kms:*'
            Resource: '*'
          - Sid: Allow Glue Service
            Effect: Allow
            Principal:
              Service: glue.amazonaws.com
            Action:
              - kms:Decrypt
              - kms:GenerateDataKey
              - kms:CreateGrant
            Resource: '*'
          - Sid: Allow S3 Service
            Effect: Allow
            Principal:
              Service: s3.amazonaws.com
            Action:
              - kms:Decrypt
              - kms:GenerateDataKey
            Resource: '*'

  DataLakeKMSKeyAlias:
    Type: AWS::KMS::Alias
    Properties:
      AliasName: !Sub 'alias/${ProjectName}-${EnvironmentName}-data-lake'
      TargetKeyId: !Ref DataLakeKMSKey

  # Data Ingestion Trigger Lambda
  DataIngestionTrigger:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: !Sub '${ProjectName}-${EnvironmentName}-ingestion-trigger'
      Runtime: python3.9
      Handler: index.lambda_handler
      Role: !GetAtt DataIngestionTriggerRole.Arn
      Code:
        ZipFile: |
          import json
          import boto3
          import os
          from datetime import datetime
          
          stepfunctions = boto3.client('stepfunctions')
          
          def lambda_handler(event, context):
              print(f"Received S3 event: {json.dumps(event)}")
              
              # S3イベント処理
              for record in event['Records']:
                  bucket = record['s3']['bucket']['name']
                  key = record['s3']['object']['key']
                  
                  # ファイル情報
                  file_info = {
                      'bucket': bucket,
                      'key': key,
                      'size': record['s3']['object']['size'],
                      'etag': record['s3']['object']['eTag'],
                      'timestamp': datetime.utcnow().isoformat()
                  }
                  
                  # Step Functions実行
                  response = stepfunctions.start_execution(
                      stateMachineArn=os.environ['STATE_MACHINE_ARN'],
                      name=f"etl-{datetime.utcnow().strftime('%Y%m%d%H%M%S')}-{key.replace('/', '-').replace('.', '-')}",
                      input=json.dumps({
                          'inputData': file_info,
                          'pipeline': 'raw-to-curated'
                      })
                  )
                  
                  print(f"Started execution: {response['executionArn']}")
              
              return {
                  'statusCode': 200,
                  'body': json.dumps('ETL pipeline triggered successfully')
              }
      
      Environment:
        Variables:
          STATE_MACHINE_ARN: !Ref ETLStateMachine
      
      Timeout: 60
      MemorySize: 128

  # Lambda permission for S3
  DataIngestionTriggerPermission:
    Type: AWS::Lambda::Permission
    Properties:
      FunctionName: !Ref DataIngestionTrigger
      Action: lambda:InvokeFunction
      Principal: s3.amazonaws.com
      SourceAccount: !Ref AWS::AccountId
      SourceArn: !Sub '${RawDataBucket}/*'

  # IAM Role for Data Ingestion Trigger
  DataIngestionTriggerRole:
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
        - PolicyName: StepFunctionsExecution
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - states:StartExecution
                Resource: !Ref ETLStateMachine

Outputs:
  RawDataBucketName:
    Description: 'Raw data S3 bucket name'
    Value: !Ref RawDataBucket
    Export:
      Name: !Sub '${AWS::StackName}-RawDataBucket'
  
  CuratedDataBucketName:
    Description: 'Curated data S3 bucket name'
    Value: !Ref CuratedDataBucket
    Export:
      Name: !Sub '${AWS::StackName}-CuratedDataBucket'
  
  AnalyticsDataBucketName:
    Description: 'Analytics data S3 bucket name'
    Value: !Ref AnalyticsDataBucket
    Export:
      Name: !Sub '${AWS::StackName}-AnalyticsDataBucket'
  
  ScriptsBucketName:
    Description: 'ETL scripts S3 bucket name'
    Value: !Ref ScriptsBucket
    Export:
      Name: !Sub '${AWS::StackName}-ScriptsBucket'
```

### ステップ2: AWS Glue ETL ジョブの実装

1. **Glue インフラストラクチャ設定**
```yaml
# cloudformation/glue-etl-infrastructure.yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'AWS Glue ETL Infrastructure'

Parameters:
  ProjectName:
    Type: String
    Default: 'etl-pipeline'
  
  EnvironmentName:
    Type: String
    Default: 'dev'
    AllowedValues: [dev, staging, prod]

Conditions:
  IsProduction: !Equals [!Ref EnvironmentName, 'prod']

Resources:
  # Glue Database
  GlueDatabase:
    Type: AWS::Glue::Database
    Properties:
      CatalogId: !Ref AWS::AccountId
      DatabaseInput:
        Name: !Sub '${ProjectName}_${EnvironmentName}_database'
        Description: 'Database for ETL pipeline data catalog'

  # Glue Crawler for Raw Data
  RawDataCrawler:
    Type: AWS::Glue::Crawler
    Properties:
      Name: !Sub '${ProjectName}-${EnvironmentName}-raw-data-crawler'
      Role: !GetAtt GlueServiceRole.Arn
      DatabaseName: !Ref GlueDatabase
      Description: 'Crawler for raw data discovery'
      
      # クロール対象設定
      Targets:
        S3Targets:
          - Path: !Sub 's3://${RawDataBucket}/processed/'
            Exclusions:
              - '**/_temporary/**'
              - '**/_spark_metadata/**'
      
      # スキーマ変更設定
      SchemaChangePolicy:
        UpdateBehavior: UPDATE_IN_DATABASE
        DeleteBehavior: LOG
      
      # スケジュール（本番環境のみ）
      Schedule:
        !If
          - IsProduction
          - ScheduleExpression: 'cron(0 2 * * ? *)'  # 毎日2時
          - !Ref AWS::NoValue

  # Glue Job for Data Transformation
  DataTransformationJob:
    Type: AWS::Glue::Job
    Properties:
      Name: !Sub '${ProjectName}-${EnvironmentName}-data-transformation'
      Role: !GetAtt GlueServiceRole.Arn
      Description: 'Data transformation job for raw to curated pipeline'
      
      # Spark設定
      Command:
        Name: glueetl
        ScriptLocation: !Sub 's3://${ScriptsBucket}/scripts/data_transformation.py'
        PythonVersion: 3
      
      # 実行設定
      DefaultArguments:
        '--job-language': 'python'
        '--job-bookmark-option': 'job-bookmark-enable'
        '--enable-metrics': 'true'
        '--enable-continuous-cloudwatch-log': 'true'
        '--enable-glue-datacatalog': 'true'
        '--enable-spark-ui': 'true'
        '--spark-event-logs-path': !Sub 's3://${ScriptsBucket}/spark-logs/'
        '--TempDir': !Sub 's3://${ScriptsBucket}/temp/'
        '--source-bucket': !Ref RawDataBucket
        '--target-bucket': !Ref CuratedDataBucket
        '--database-name': !Ref GlueDatabase
      
      # リソース設定
      MaxRetries: 2
      MaxCapacity: !If [IsProduction, 10, 2]
      Timeout: 60
      
      # セキュリティ設定
      SecurityConfiguration: !Ref GlueSecurityConfiguration

  # Glue Security Configuration
  GlueSecurityConfiguration:
    Type: AWS::Glue::SecurityConfiguration
    Properties:
      Name: !Sub '${ProjectName}-${EnvironmentName}-glue-security'
      EncryptionConfiguration:
        S3Encryptions:
          - S3EncryptionMode: SSE-KMS
            KmsKeyArn: !GetAtt DataLakeKMSKey.Arn
        CloudWatchEncryption:
          CloudWatchEncryptionMode: SSE-KMS
          KmsKeyArn: !GetAtt DataLakeKMSKey.Arn
        JobBookmarksEncryption:
          JobBookmarksEncryptionMode: CSE-KMS
          KmsKeyArn: !GetAtt DataLakeKMSKey.Arn

  # Glue Service Role
  GlueServiceRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: glue.amazonaws.com
            Action: sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole
      Policies:
        - PolicyName: S3DataLakeAccess
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - s3:GetObject
                  - s3:PutObject
                  - s3:DeleteObject
                  - s3:ListBucket
                Resource:
                  - !Sub '${RawDataBucket}/*'
                  - !Sub '${CuratedDataBucket}/*'
                  - !Sub '${AnalyticsDataBucket}/*'
                  - !Sub '${ScriptsBucket}/*'
                  - !Ref RawDataBucket
                  - !Ref CuratedDataBucket
                  - !Ref AnalyticsDataBucket
                  - !Ref ScriptsBucket
        - PolicyName: KMSAccess
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - kms:Decrypt
                  - kms:GenerateDataKey
                  - kms:CreateGrant
                Resource: !GetAtt DataLakeKMSKey.Arn

  # CloudWatch Log Group for Glue
  GlueLogGroup:
    Type: AWS::Logs::LogGroup
    Properties:
      LogGroupName: !Sub '/aws/glue/${ProjectName}-${EnvironmentName}'
      RetentionInDays: !If [IsProduction, 30, 7]

Outputs:
  GlueDatabaseName:
    Description: 'Glue database name'
    Value: !Ref GlueDatabase
    Export:
      Name: !Sub '${AWS::StackName}-GlueDatabase'
  
  DataTransformationJobName:
    Description: 'Glue data transformation job name'
    Value: !Ref DataTransformationJob
    Export:
      Name: !Sub '${AWS::StackName}-DataTransformationJob'
```

2. **Glue ETL スクリプト実装**
```python
# glue-scripts/data_transformation.py
import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.dynamicframe import DynamicFrame
from pyspark.sql import functions as F
from pyspark.sql.types import *
import boto3
from datetime import datetime, timedelta
import logging

# 引数取得
args = getResolvedOptions(sys.argv, [
    'JOB_NAME',
    'source-bucket',
    'target-bucket', 
    'database-name',
    'source-path',
    'target-path'
])

# Spark/Glue コンテキスト初期化
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

# ログ設定
logger = glueContext.get_logger()
logger.info(f"Starting ETL job: {args['JOB_NAME']}")

# S3クライアント
s3_client = boto3.client('s3')

class DataTransformer:
    def __init__(self, glue_context, spark_session):
        self.glue_context = glue_context
        self.spark = spark_session
        self.logger = glue_context.get_logger()
    
    def extract_data(self, source_path, data_format="json"):
        """
        データ抽出処理
        """
        try:
            self.logger.info(f"Extracting data from: {source_path}")
            
            if data_format.lower() == "json":
                # JSON形式の読み込み
                df = self.spark.read.option("multiline", "true").json(source_path)
            elif data_format.lower() == "csv":
                # CSV形式の読み込み
                df = self.spark.read.option("header", "true").option("inferSchema", "true").csv(source_path)
            elif data_format.lower() == "parquet":
                # Parquet形式の読み込み
                df = self.spark.read.parquet(source_path)
            else:
                raise ValueError(f"Unsupported data format: {data_format}")
            
            # DynamicFrameに変換
            dynamic_frame = DynamicFrame.fromDF(df, self.glue_context, "extracted_data")
            
            self.logger.info(f"Extracted {dynamic_frame.count()} records")
            return dynamic_frame
            
        except Exception as e:
            self.logger.error(f"Error extracting data: {str(e)}")
            raise e
    
    def validate_data_quality(self, dynamic_frame):
        """
        データ品質チェック
        """
        try:
            self.logger.info("Performing data quality checks")
            
            df = dynamic_frame.toDF()
            total_records = df.count()
            
            # NULL値チェック
            null_counts = {}
            for col in df.columns:
                null_count = df.filter(F.col(col).isNull()).count()
                null_percentage = (null_count / total_records) * 100 if total_records > 0 else 0
                null_counts[col] = {
                    'null_count': null_count,
                    'null_percentage': null_percentage
                }
                
                # 50%以上がNULLの場合は警告
                if null_percentage > 50:
                    self.logger.warn(f"Column {col} has {null_percentage:.2f}% NULL values")
            
            # 重複レコードチェック
            duplicate_count = df.count() - df.dropDuplicates().count()
            if duplicate_count > 0:
                self.logger.warn(f"Found {duplicate_count} duplicate records")
            
            # データ型不整合チェック
            schema_issues = []
            for field in df.schema.fields:
                if field.dataType == StringType():
                    # 数値データが文字列として格納されているかチェック
                    numeric_pattern_count = df.filter(
                        F.col(field.name).rlike(r'^\d+\.?\d*$')
                    ).count()
                    if numeric_pattern_count > total_records * 0.8:  # 80%以上が数値パターン
                        schema_issues.append(f"Column {field.name} appears to contain numeric data but is stored as string")
            
            quality_report = {
                'total_records': total_records,
                'null_counts': null_counts,
                'duplicate_count': duplicate_count,
                'schema_issues': schema_issues,
                'quality_score': self._calculate_quality_score(null_counts, duplicate_count, total_records)
            }
            
            self.logger.info(f"Data quality report: {quality_report}")
            return quality_report
            
        except Exception as e:
            self.logger.error(f"Error in data quality validation: {str(e)}")
            raise e
    
    def transform_data(self, dynamic_frame):
        """
        データ変換処理
        """
        try:
            self.logger.info("Starting data transformation")
            
            # DataFrameに変換
            df = dynamic_frame.toDF()
            
            # 1. データクレンジング
            df_cleaned = self._clean_data(df)
            
            # 2. データ標準化
            df_standardized = self._standardize_data(df_cleaned)
            
            # 3. データエンリッチメント
            df_enriched = self._enrich_data(df_standardized)
            
            # 4. ビジネスルール適用
            df_business_rules = self._apply_business_rules(df_enriched)
            
            # 5. パーティション用カラム追加
            df_partitioned = self._add_partition_columns(df_business_rules)
            
            # DynamicFrameに変換
            transformed_dynamic_frame = DynamicFrame.fromDF(
                df_partitioned, 
                self.glue_context, 
                "transformed_data"
            )
            
            self.logger.info(f"Transformation completed. Output records: {transformed_dynamic_frame.count()}")
            return transformed_dynamic_frame
            
        except Exception as e:
            self.logger.error(f"Error in data transformation: {str(e)}")
            raise e
    
    def _clean_data(self, df):
        """
        データクレンジング
        """
        self.logger.info("Cleaning data")
        
        # NULL値の処理
        df_cleaned = df.na.fill({
            'string_column': 'Unknown',
            'numeric_column': 0,
            'boolean_column': False
        })
        
        # 重複レコード削除
        df_cleaned = df_cleaned.dropDuplicates()
        
        # 不正な値の修正
        df_cleaned = df_cleaned.filter(F.col("id").isNotNull())
        
        return df_cleaned
    
    def _standardize_data(self, df):
        """
        データ標準化
        """
        self.logger.info("Standardizing data")
        
        # 文字列の正規化
        if 'name' in df.columns:
            df = df.withColumn('name', F.trim(F.upper(F.col('name'))))
        
        # 日付フォーマット統一
        if 'date_column' in df.columns:
            df = df.withColumn(
                'date_column', 
                F.to_timestamp(F.col('date_column'), 'yyyy-MM-dd HH:mm:ss')
            )
        
        # 数値データの型変換
        numeric_columns = ['amount', 'quantity', 'price']
        for col in numeric_columns:
            if col in df.columns:
                df = df.withColumn(col, F.col(col).cast('double'))
        
        return df
    
    def _enrich_data(self, df):
        """
        データエンリッチメント
        """
        self.logger.info("Enriching data")
        
        # 計算カラム追加
        if 'quantity' in df.columns and 'price' in df.columns:
            df = df.withColumn('total_amount', F.col('quantity') * F.col('price'))
        
        # カテゴリ分類
        if 'amount' in df.columns:
            df = df.withColumn(
                'amount_category',
                F.when(F.col('amount') < 1000, 'Small')
                 .when(F.col('amount') < 10000, 'Medium')
                 .otherwise('Large')
            )
        
        # 外部データとのJOIN（参照データ）
        # ここでは例として固定値で処理
        if 'region_code' in df.columns:
            region_mapping = {
                '01': 'North',
                '02': 'South', 
                '03': 'East',
                '04': 'West'
            }
            mapping_expr = F.create_map([F.lit(x) for x in sum(region_mapping.items(), ())])
            df = df.withColumn('region_name', mapping_expr[F.col('region_code')])
        
        return df
    
    def _apply_business_rules(self, df):
        """
        ビジネスルール適用
        """
        self.logger.info("Applying business rules")
        
        # 有効性チェック
        if 'status' in df.columns:
            df = df.filter(F.col('status').isin(['ACTIVE', 'PENDING']))
        
        # 期間制限
        if 'created_date' in df.columns:
            cutoff_date = datetime.now() - timedelta(days=365)
            df = df.filter(F.col('created_date') >= cutoff_date)
        
        # データマスキング（PII保護）
        if 'email' in df.columns:
            df = df.withColumn(
                'email_masked',
                F.regexp_replace(F.col('email'), r'(.{2}).*@', '$1***@')
            )
        
        return df
    
    def _add_partition_columns(self, df):
        """
        パーティション用カラム追加
        """
        self.logger.info("Adding partition columns")
        
        # 処理日付パーティション
        current_date = datetime.now()
        df = df.withColumn('process_year', F.lit(current_date.year)) \
               .withColumn('process_month', F.lit(current_date.month)) \
               .withColumn('process_day', F.lit(current_date.day))
        
        # 時間ベースパーティション（データに日付カラムがある場合）
        if 'created_date' in df.columns:
            df = df.withColumn('data_year', F.year(F.col('created_date'))) \
                   .withColumn('data_month', F.month(F.col('created_date')))
        
        return df
    
    def _calculate_quality_score(self, null_counts, duplicate_count, total_records):
        """
        データ品質スコア計算
        """
        if total_records == 0:
            return 0
        
        # NULL値ペナルティ
        null_penalty = 0
        for col, stats in null_counts.items():
            null_penalty += stats['null_percentage'] / 100
        
        # 重複ペナルティ
        duplicate_penalty = (duplicate_count / total_records) * 100
        
        # 品質スコア計算（0-100）
        quality_score = max(0, 100 - (null_penalty * 10) - duplicate_penalty)
        
        return round(quality_score, 2)
    
    def load_data(self, dynamic_frame, target_path, output_format="parquet"):
        """
        データロード処理
        """
        try:
            self.logger.info(f"Loading data to: {target_path}")
            
            if output_format.lower() == "parquet":
                # Parquet形式で出力（推奨）
                glueContext.write_dynamic_frame.from_options(
                    frame=dynamic_frame,
                    connection_type="s3",
                    connection_options={
                        "path": target_path,
                        "partitionKeys": ["process_year", "process_month", "process_day"]
                    },
                    format="glueparquet",
                    format_options={
                        "compression": "snappy",
                        "blockSize": 134217728,  # 128MB
                        "pageSize": 1048576      # 1MB
                    },
                    transformation_ctx="load_data"
                )
            elif output_format.lower() == "delta":
                # Delta Lake形式で出力
                df = dynamic_frame.toDF()
                df.write \
                  .format("delta") \
                  .mode("overwrite") \
                  .option("overwriteSchema", "true") \
                  .partitionBy("process_year", "process_month", "process_day") \
                  .save(target_path)
            
            self.logger.info("Data loading completed successfully")
            
        except Exception as e:
            self.logger.error(f"Error loading data: {str(e)}")
            raise e

def main():
    """
    メイン処理
    """
    transformer = DataTransformer(glueContext, spark)
    
    try:
        # データソースパス構築
        source_path = f"s3://{args['source-bucket']}/{args.get('source-path', 'incoming/')}"
        target_path = f"s3://{args['target-bucket']}/{args.get('target-path', 'processed/')}"
        
        logger.info(f"Processing data from {source_path} to {target_path}")
        
        # 1. データ抽出
        raw_data = transformer.extract_data(source_path, "json")
        
        # 2. データ品質チェック
        quality_report = transformer.validate_data_quality(raw_data)
        
        # 品質スコアが閾値を下回る場合は処理停止
        if quality_report['quality_score'] < 70:
            raise Exception(f"Data quality score {quality_report['quality_score']} is below threshold (70)")
        
        # 3. データ変換
        transformed_data = transformer.transform_data(raw_data)
        
        # 4. データロード
        transformer.load_data(transformed_data, target_path, "parquet")
        
        # 5. 成功メトリクス送信
        cloudwatch = boto3.client('cloudwatch')
        cloudwatch.put_metric_data(
            Namespace='ETL/Pipeline',
            MetricData=[
                {
                    'MetricName': 'RecordsProcessed',
                    'Value': transformed_data.count(),
                    'Unit': 'Count'
                },
                {
                    'MetricName': 'DataQualityScore',
                    'Value': quality_report['quality_score'],
                    'Unit': 'Percent'
                }
            ]
        )
        
        logger.info("ETL job completed successfully")
        
    except Exception as e:
        logger.error(f"ETL job failed: {str(e)}")
        
        # 失敗メトリクス送信
        cloudwatch = boto3.client('cloudwatch')
        cloudwatch.put_metric_data(
            Namespace='ETL/Pipeline',
            MetricData=[
                {
                    'MetricName': 'JobFailures',
                    'Value': 1,
                    'Unit': 'Count'
                }
            ]
        )
        
        raise e

if __name__ == "__main__":
    main()

job.commit()
```

### ステップ3: Step Functions ETL ワークフロー

1. **Step Functions ETL オーケストレーション**
```yaml
# cloudformation/step-functions-etl.yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Step Functions ETL Workflow'

Parameters:
  ProjectName:
    Type: String
    Default: 'etl-pipeline'
  
  EnvironmentName:
    Type: String
    Default: 'dev'

Resources:
  # Step Functions State Machine
  ETLStateMachine:
    Type: AWS::StepFunctions::StateMachine
    Properties:
      StateMachineName: !Sub '${ProjectName}-${EnvironmentName}-etl-workflow'
      RoleArn: !GetAtt StepFunctionsExecutionRole.Arn
      
      DefinitionString: !Sub |
        {
          "Comment": "ETL Pipeline Workflow with data validation and transformation",
          "StartAt": "ValidateInput",
          "States": {
            "ValidateInput": {
              "Type": "Task",
              "Resource": "${DataValidationFunction.Arn}",
              "ResultPath": "$.validationResult",
              "Next": "CheckValidation",
              "Catch": [
                {
                  "ErrorEquals": ["States.ALL"],
                  "Next": "NotifyFailure",
                  "ResultPath": "$.error"
                }
              ]
            },
            "CheckValidation": {
              "Type": "Choice",
              "Choices": [
                {
                  "Variable": "$.validationResult.isValid",
                  "BooleanEquals": true,
                  "Next": "RunDataDiscovery"
                }
              ],
              "Default": "NotifyValidationFailure"
            },
            "RunDataDiscovery": {
              "Type": "Task",
              "Resource": "arn:aws:states:::aws-sdk:glue:startCrawler",
              "Parameters": {
                "Name": "${RawDataCrawler}"
              },
              "ResultPath": "$.crawlerResult",
              "Next": "WaitForCrawler",
              "Catch": [
                {
                  "ErrorEquals": ["States.ALL"],
                  "Next": "NotifyFailure",
                  "ResultPath": "$.error"
                }
              ]
            },
            "WaitForCrawler": {
              "Type": "Wait",
              "Seconds": 30,
              "Next": "CheckCrawlerStatus"
            },
            "CheckCrawlerStatus": {
              "Type": "Task",
              "Resource": "arn:aws:states:::aws-sdk:glue:getCrawler",
              "Parameters": {
                "Name": "${RawDataCrawler}"
              },
              "ResultPath": "$.crawlerStatus",
              "Next": "IsCrawlerComplete"
            },
            "IsCrawlerComplete": {
              "Type": "Choice",
              "Choices": [
                {
                  "Variable": "$.crawlerStatus.Crawler.State",
                  "StringEquals": "READY",
                  "Next": "RunDataQualityCheck"
                },
                {
                  "Variable": "$.crawlerStatus.Crawler.State",
                  "StringEquals": "RUNNING",
                  "Next": "WaitForCrawler"
                }
              ],
              "Default": "NotifyFailure"
            },
            "RunDataQualityCheck": {
              "Type": "Task",
              "Resource": "${DataQualityCheckFunction.Arn}",
              "ResultPath": "$.qualityResult",
              "Next": "CheckDataQuality",
              "Catch": [
                {
                  "ErrorEquals": ["States.ALL"],
                  "Next": "NotifyFailure",
                  "ResultPath": "$.error"
                }
              ]
            },
            "CheckDataQuality": {
              "Type": "Choice",
              "Choices": [
                {
                  "Variable": "$.qualityResult.qualityScore",
                  "NumericGreaterThanEquals": 70,
                  "Next": "RunETLJob"
                }
              ],
              "Default": "NotifyQualityFailure"
            },
            "RunETLJob": {
              "Type": "Task",
              "Resource": "arn:aws:states:::glue:startJobRun.sync",
              "Parameters": {
                "JobName": "${DataTransformationJob}",
                "Arguments": {
                  "--source-path.$": "$.inputData.key",
                  "--target-path": "processed/"
                }
              },
              "ResultPath": "$.etlResult",
              "Next": "UpdateDataCatalog",
              "Catch": [
                {
                  "ErrorEquals": ["States.ALL"],
                  "Next": "NotifyFailure",
                  "ResultPath": "$.error"
                }
              ]
            },
            "UpdateDataCatalog": {
              "Type": "Task",
              "Resource": "arn:aws:states:::aws-sdk:glue:startCrawler",
              "Parameters": {
                "Name": "${CuratedDataCrawler}"
              },
              "ResultPath": "$.catalogUpdateResult",
              "Next": "NotifySuccess",
              "Catch": [
                {
                  "ErrorEquals": ["States.ALL"],
                  "Next": "NotifyFailure",
                  "ResultPath": "$.error"
                }
              ]
            },
            "NotifySuccess": {
              "Type": "Task",
              "Resource": "arn:aws:states:::sns:publish",
              "Parameters": {
                "TopicArn": "${ETLNotificationTopic}",
                "Message": {
                  "status": "SUCCESS",
                  "executionArn.$": "$$.Execution.Name",
                  "input.$": "$.inputData"
                },
                "Subject": "ETL Pipeline Completed Successfully"
              },
              "End": true
            },
            "NotifyValidationFailure": {
              "Type": "Task",
              "Resource": "arn:aws:states:::sns:publish",
              "Parameters": {
                "TopicArn": "${ETLNotificationTopic}",
                "Message": {
                  "status": "VALIDATION_FAILED",
                  "executionArn.$": "$$.Execution.Name",
                  "validationResult.$": "$.validationResult"
                },
                "Subject": "ETL Pipeline - Data Validation Failed"
              },
              "End": true
            },
            "NotifyQualityFailure": {
              "Type": "Task",
              "Resource": "arn:aws:states:::sns:publish",
              "Parameters": {
                "TopicArn": "${ETLNotificationTopic}",
                "Message": {
                  "status": "QUALITY_CHECK_FAILED",
                  "executionArn.$": "$$.Execution.Name",
                  "qualityResult.$": "$.qualityResult"
                },
                "Subject": "ETL Pipeline - Data Quality Check Failed"
              },
              "End": true
            },
            "NotifyFailure": {
              "Type": "Task",
              "Resource": "arn:aws:states:::sns:publish",
              "Parameters": {
                "TopicArn": "${ETLNotificationTopic}",
                "Message": {
                  "status": "FAILED",
                  "executionArn.$": "$$.Execution.Name",
                  "error.$": "$.error"
                },
                "Subject": "ETL Pipeline Failed"
              },
              "End": true
            }
          }
        }

  # Step Functions Execution Role
  StepFunctionsExecutionRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: states.amazonaws.com
            Action: sts:AssumeRole
      Policies:
        - PolicyName: StepFunctionsETLPolicy
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - lambda:InvokeFunction
                Resource:
                  - !GetAtt DataValidationFunction.Arn
                  - !GetAtt DataQualityCheckFunction.Arn
              - Effect: Allow
                Action:
                  - glue:StartJobRun
                  - glue:GetJobRun
                  - glue:BatchStopJobRun
                  - glue:StartCrawler
                  - glue:GetCrawler
                Resource:
                  - !Sub 'arn:aws:glue:${AWS::Region}:${AWS::AccountId}:job/${DataTransformationJob}'
                  - !Sub 'arn:aws:glue:${AWS::Region}:${AWS::AccountId}:crawler/${RawDataCrawler}'
                  - !Sub 'arn:aws:glue:${AWS::Region}:${AWS::AccountId}:crawler/${CuratedDataCrawler}'
              - Effect: Allow
                Action:
                  - sns:Publish
                Resource: !Ref ETLNotificationTopic

  # Data Validation Lambda Function
  DataValidationFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: !Sub '${ProjectName}-${EnvironmentName}-data-validation'
      Runtime: python3.9
      Handler: index.lambda_handler
      Role: !GetAtt DataValidationLambdaRole.Arn
      Code:
        ZipFile: |
          import json
          import boto3
          import re
          from datetime import datetime
          
          s3 = boto3.client('s3')
          
          def lambda_handler(event, context):
              try:
                  input_data = event['inputData']
                  bucket = input_data['bucket']
                  key = input_data['key']
                  
                  # ファイル拡張子チェック
                  supported_formats = ['.json', '.csv', '.parquet', '.txt']
                  file_extension = '.' + key.split('.')[-1].lower()
                  
                  if file_extension not in supported_formats:
                      return {
                          'isValid': False,
                          'reason': f'Unsupported file format: {file_extension}',
                          'supportedFormats': supported_formats
                      }
                  
                  # ファイルサイズチェック
                  response = s3.head_object(Bucket=bucket, Key=key)
                  file_size = response['ContentLength']
                  max_size = 5 * 1024 * 1024 * 1024  # 5GB
                  
                  if file_size > max_size:
                      return {
                          'isValid': False,
                          'reason': f'File too large: {file_size} bytes (max: {max_size})',
                          'fileSize': file_size
                      }
                  
                  # ファイル名パターンチェック
                  filename_pattern = r'^[a-zA-Z0-9_-]+\.[a-zA-Z0-9]+$'
                  filename = key.split('/')[-1]
                  
                  if not re.match(filename_pattern, filename):
                      return {
                          'isValid': False,
                          'reason': f'Invalid filename pattern: {filename}',
                          'expectedPattern': filename_pattern
                      }
                  
                  return {
                      'isValid': True,
                      'fileFormat': file_extension,
                      'fileSize': file_size,
                      'filename': filename,
                      'validatedAt': datetime.utcnow().isoformat()
                  }
                  
              except Exception as e:
                  return {
                      'isValid': False,
                      'reason': f'Validation error: {str(e)}',
                      'error': str(e)
                  }
      
      Timeout: 30
      MemorySize: 128

  # Data Quality Check Lambda Function
  DataQualityCheckFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: !Sub '${ProjectName}-${EnvironmentName}-data-quality-check'
      Runtime: python3.9
      Handler: index.lambda_handler
      Role: !GetAtt DataValidationLambdaRole.Arn
      Code:
        ZipFile: |
          import json
          import boto3
          import pandas as pd
          from io import StringIO
          from datetime import datetime
          
          s3 = boto3.client('s3')
          
          def lambda_handler(event, context):
              try:
                  input_data = event['inputData']
                  bucket = input_data['bucket']
                  key = input_data['key']
                  
                  # ファイル読み込み（サンプリング）
                  response = s3.get_object(Bucket=bucket, Key=key)
                  content = response['Body'].read().decode('utf-8')
                  
                  # データフレーム作成（JSON形式の場合）
                  if key.endswith('.json'):
                      data = json.loads(content)
                      if isinstance(data, list):
                          df = pd.DataFrame(data)
                      else:
                          df = pd.DataFrame([data])
                  elif key.endswith('.csv'):
                      df = pd.read_csv(StringIO(content))
                  else:
                      # 他の形式は簡易チェックのみ
                      return {
                          'qualityScore': 80,
                          'checks': ['File format check passed'],
                          'warnings': ['Detailed quality check not available for this format']
                      }
                  
                  # 品質チェック実行
                  quality_checks = perform_quality_checks(df)
                  
                  return quality_checks
                  
              except Exception as e:
                  return {
                      'qualityScore': 0,
                      'checks': [],
                      'errors': [f'Quality check failed: {str(e)}']
                  }
          
          def perform_quality_checks(df):
              checks = []
              warnings = []
              errors = []
              
              total_records = len(df)
              if total_records == 0:
                  return {
                      'qualityScore': 0,
                      'checks': checks,
                      'warnings': warnings,
                      'errors': ['No data found in file']
                  }
              
              # NULL値チェック
              null_percentage = (df.isnull().sum().sum() / (total_records * len(df.columns))) * 100
              if null_percentage > 50:
                  errors.append(f'High NULL percentage: {null_percentage:.2f}%')
              elif null_percentage > 20:
                  warnings.append(f'Moderate NULL percentage: {null_percentage:.2f}%')
              else:
                  checks.append(f'NULL percentage acceptable: {null_percentage:.2f}%')
              
              # 重複チェック
              duplicate_percentage = (df.duplicated().sum() / total_records) * 100
              if duplicate_percentage > 30:
                  errors.append(f'High duplicate percentage: {duplicate_percentage:.2f}%')
              elif duplicate_percentage > 10:
                  warnings.append(f'Moderate duplicate percentage: {duplicate_percentage:.2f}%')
              else:
                  checks.append(f'Duplicate percentage acceptable: {duplicate_percentage:.2f}%')
              
              # 品質スコア計算
              quality_score = max(0, 100 - null_percentage - duplicate_percentage)
              
              return {
                  'qualityScore': round(quality_score, 2),
                  'totalRecords': total_records,
                  'nullPercentage': round(null_percentage, 2),
                  'duplicatePercentage': round(duplicate_percentage, 2),
                  'checks': checks,
                  'warnings': warnings,
                  'errors': errors,
                  'checkedAt': datetime.utcnow().isoformat()
              }
      
      Timeout: 300
      MemorySize: 512

  # Lambda Role
  DataValidationLambdaRole:
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
        - PolicyName: S3Access
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - s3:GetObject
                  - s3:HeadObject
                Resource:
                  - !Sub '${RawDataBucket}/*'

  # SNS Topic for notifications
  ETLNotificationTopic:
    Type: AWS::SNS::Topic
    Properties:
      TopicName: !Sub '${ProjectName}-${EnvironmentName}-etl-notifications'

Outputs:
  ETLStateMachineArn:
    Description: 'ETL State Machine ARN'
    Value: !Ref ETLStateMachine
    Export:
      Name: !Sub '${AWS::StackName}-ETLStateMachine'
```

## 検証方法

### 1. ETL パイプライン実行テスト
```bash
# サンプルデータアップロード
aws s3 cp sample-data.json s3://etl-pipeline-dev-raw-data-123456789/incoming/

# Step Functions実行状況確認
aws stepfunctions list-executions --state-machine-arn arn:aws:states:region:account:stateMachine:etl-pipeline-dev-etl-workflow

# Glueジョブ実行履歴確認
aws glue get-job-runs --job-name etl-pipeline-dev-data-transformation
```

### 2. データ品質検証
```python
# データ品質検証スクリプト
import boto3
import pandas as pd

def validate_etl_output(bucket, prefix):
    s3 = boto3.client('s3')
    
    # 出力ファイル一覧取得
    response = s3.list_objects_v2(Bucket=bucket, Prefix=prefix)
    
    for obj in response.get('Contents', []):
        if obj['Key'].endswith('.parquet'):
            print(f"Validating: {obj['Key']}")
            
            # ファイルサイズチェック
            if obj['Size'] == 0:
                print(f"ERROR: Empty file detected: {obj['Key']}")
            
            # パーティション構造チェック
            path_parts = obj['Key'].split('/')
            if 'process_year=' not in obj['Key']:
                print(f"WARNING: Missing partition structure: {obj['Key']}")

validate_etl_output('etl-pipeline-dev-curated-data-123456789', 'processed/')
```

### 3. パフォーマンス監視
```bash
# CloudWatch メトリクス確認
aws cloudwatch get-metric-statistics \
  --namespace AWS/Glue \
  --metric-name glue.driver.aggregate.numCompletedTasks \
  --dimensions Name=JobName,Value=etl-pipeline-dev-data-transformation \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-01T23:59:59Z \
  --period 3600 \
  --statistics Sum
```

## トラブルシューティング

### よくある問題と解決策

#### 1. Glue ジョブのメモリ不足
**症状**: OutOfMemoryError または処理の遅延
**解決策**:
```python
# Spark設定最適化
spark.conf.set("spark.sql.adaptive.enabled", "true")
spark.conf.set("spark.sql.adaptive.coalescePartitions.enabled", "true")
spark.conf.set("spark.sql.adaptive.skewJoin.enabled", "true")
spark.conf.set("spark.serializer", "org.apache.spark.serializer.KryoSerializer")
```

#### 2. データスキューの問題
**症状**: 一部のタスクが異常に遅い
**解決策**:
```python
# データ再パーティション
df_repartitioned = df.repartition(200, "partition_column")

# ソルトによる負荷分散
df_salted = df.withColumn("salt", F.rand() * 100).cast("int"))
```

#### 3. S3スロットリング
**症状**: S3 503 Slow Down エラー
**解決策**:
- S3プレフィックス設計の見直し
- リクエストレートの分散
- 指数バックオフリトライの実装

## 学習リソース

### AWS公式ドキュメント
- [AWS Glue Developer Guide](https://docs.aws.amazon.com/glue/latest/dg/)
- [Step Functions Developer Guide](https://docs.aws.amazon.com/step-functions/latest/dg/)
- [S3 Data Lake Best Practices](https://docs.aws.amazon.com/whitepapers/latest/building-data-lakes/building-data-lake-aws.html)

### 追加学習教材
- [Apache Spark Programming Guide](https://spark.apache.org/docs/latest/programming-guide.html)
- [Data Lake Architecture](https://aws.amazon.com/big-data/datalakes-and-analytics/)

## セキュリティとコストの考慮事項

### セキュリティベストプラクティス
1. **データ暗号化**: 保存時・転送時の暗号化
2. **IAM最小権限**: ジョブ固有の権限設定
3. **VPC**: プライベートサブネットでの実行
4. **データマスキング**: PII データの適切な処理

### コスト最適化
1. **Glue DPU最適化**: ワークロードに応じた適切な設定
2. **S3ストレージクラス**: IA・Glacier の活用
3. **データ圧縮**: Parquet・Snappy圧縮
4. **ジョブスケジューリング**: オフピーク時間の活用

### AWS Well-Architectedフレームワークとの関連
- **運用性の柱**: CloudWatch監視・Step Functions可視化
- **セキュリティの柱**: IAM・VPC・暗号化・監査ログ
- **信頼性の柱**: 複数AZ・エラーハンドリング・再試行
- **パフォーマンス効率の柱**: 適切なリソース設定・データ分散
- **コスト最適化の柱**: オンデマンド実行・適切なストレージ選択

## 次のステップ

### 推奨される学習パス
1. **4.2.1 QuickSightダッシュボード**: ETLデータの可視化
2. **5.2.2 RAGシステム構築**: 処理済みデータ活用
3. **6.1.1 マルチステージビルド**: ETL CI/CD パイプライン
4. **6.2.1 APM実装**: ETL監視強化

### 発展的な機能
1. **AWS Lake Formation**: 高度なデータガバナンス
2. **EMR Serverless**: より柔軟なSpark処理
3. **Redshift Spectrum**: データレイククエリ
4. **EventBridge**: イベント駆動ETL

### 実践プロジェクトのアイデア
1. **マルチソースETL**: 複数データソース統合
2. **リアルタイムETL**: ストリーミング処理統合
3. **機械学習パイプライン**: 特徴量エンジニアリング
4. **データリネージ追跡**: データ系譜管理システム

## 🏗️ エンタープライズ級ETL実装パターン

### データファクトリーパターン
企業レベルでの複雑なデータ変換要件に対応する設計パターンです。

```python
# src/advanced/data_factory.py
import boto3
import pandas as pd
from typing import Dict, List, Any, Optional, Callable
from dataclasses import dataclass, field
from abc import ABC, abstractmethod
import logging
from datetime import datetime
import json

@dataclass
class ETLJobConfig:
    """ETLジョブ設定"""
    job_name: str
    source_config: Dict[str, Any]
    target_config: Dict[str, Any]
    transformation_rules: List[Dict[str, Any]]
    quality_checks: List[Dict[str, Any]] = field(default_factory=list)
    schedule: Optional[str] = None
    dependencies: List[str] = field(default_factory=list)
    retry_config: Dict[str, Any] = field(default_factory=lambda: {"max_retries": 3, "backoff_factor": 2})

class DataTransformer(ABC):
    """抽象データ変換クラス"""
    
    @abstractmethod
    def transform(self, df: pd.DataFrame) -> pd.DataFrame:
        pass
    
    @abstractmethod
    def validate(self, df: pd.DataFrame) -> bool:
        pass

class CustomerDataTransformer(DataTransformer):
    """顧客データ変換"""
    
    def transform(self, df: pd.DataFrame) -> pd.DataFrame:
        """顧客データの標準化と拡張"""
        
        # 電話番号正規化
        df['phone_normalized'] = df['phone'].str.replace(r'[^\d]', '', regex=True)
        
        # メールドメイン抽出
        df['email_domain'] = df['email'].str.extract(r'@(.+)$')
        
        # 年齢グループ計算
        current_year = datetime.now().year
        df['birth_year'] = pd.to_datetime(df['birth_date']).dt.year
        df['age'] = current_year - df['birth_year']
        df['age_group'] = pd.cut(df['age'], 
                                bins=[0, 18, 30, 50, 65, 100],
                                labels=['under_18', '18_30', '30_50', '50_65', 'over_65'])
        
        # 顧客セグメント計算
        df['customer_segment'] = self._calculate_customer_segment(df)
        
        # データクリーニング
        df = df.dropna(subset=['customer_id', 'email'])
        df = df.drop_duplicates(subset=['customer_id'])
        
        return df
    
    def _calculate_customer_segment(self, df: pd.DataFrame) -> pd.Series:
        """顧客セグメントの計算"""
        conditions = [
            (df['total_purchases'] >= 10) & (df['avg_order_value'] >= 100),
            (df['total_purchases'] >= 5) & (df['avg_order_value'] >= 50),
            (df['total_purchases'] >= 1)
        ]
        choices = ['premium', 'standard', 'basic']
        return pd.Series(pd.np.select(conditions, choices, default='new'))
    
    def validate(self, df: pd.DataFrame) -> bool:
        """データ品質検証"""
        checks = [
            df['customer_id'].notna().all(),
            df['email'].str.contains('@').all(),
            df['phone_normalized'].str.len().between(10, 15).all(),
            df['age'].between(0, 120).all()
        ]
        return all(checks)

class SalesDataTransformer(DataTransformer):
    """売上データ変換"""
    
    def transform(self, df: pd.DataFrame) -> pd.DataFrame:
        """売上データの集約と分析"""
        
        # 日付フィールド正規化
        df['order_date'] = pd.to_datetime(df['order_date'])
        df['year'] = df['order_date'].dt.year
        df['month'] = df['order_date'].dt.month
        df['quarter'] = df['order_date'].dt.quarter
        df['day_of_week'] = df['order_date'].dt.day_name()
        
        # 売上メトリクス計算
        df['total_amount'] = df['quantity'] * df['unit_price']
        df['discount_amount'] = df['total_amount'] * df['discount_rate']
        df['net_amount'] = df['total_amount'] - df['discount_amount']
        
        # 商品カテゴリ階層分析
        df['main_category'] = df['product_category'].str.split(' > ').str[0]
        df['sub_category'] = df['product_category'].str.split(' > ').str[1]
        
        # 季節性分析
        df['season'] = df['month'].map({
            12: 'winter', 1: 'winter', 2: 'winter',
            3: 'spring', 4: 'spring', 5: 'spring',
            6: 'summer', 7: 'summer', 8: 'summer',
            9: 'autumn', 10: 'autumn', 11: 'autumn'
        })
        
        # 地域分析
        df['region'] = self._map_region(df['postal_code'])
        
        return df
    
    def _map_region(self, postal_codes: pd.Series) -> pd.Series:
        """郵便番号から地域マッピング"""
        # 日本の郵便番号パターンに基づく地域分類
        region_map = {
            '0': '北海道・東北', '1': '関東', '2': '関東',
            '3': '中部', '4': '関西', '5': '中国・四国',
            '6': '九州・沖縄', '7': '関東', '8': '中部', '9': '九州・沖縄'
        }
        return postal_codes.astype(str).str[0].map(region_map).fillna('不明')
    
    def validate(self, df: pd.DataFrame) -> bool:
        """売上データ検証"""
        checks = [
            df['quantity'].gt(0).all(),
            df['unit_price'].ge(0).all(),
            df['discount_rate'].between(0, 1).all(),
            df['order_date'].notna().all()
        ]
        return all(checks)

class EnterpriseETLPipeline:
    """エンタープライズETLパイプライン"""
    
    def __init__(self, config: ETLJobConfig):
        self.config = config
        self.glue = boto3.client('glue')
        self.s3 = boto3.client('s3')
        self.stepfunctions = boto3.client('stepfunctions')
        self.logger = logging.getLogger(__name__)
        
        # トランスフォーマー登録
        self.transformers = {
            'customer': CustomerDataTransformer(),
            'sales': SalesDataTransformer(),
        }
    
    def execute_pipeline(self) -> Dict[str, Any]:
        """パイプライン実行のメインエントリポイント"""
        execution_id = f"{self.config.job_name}_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        
        try:
            # 実行前検証
            self._validate_configuration()
            
            # データ抽出
            raw_data = self._extract_data()
            
            # データ変換
            transformed_data = self._transform_data(raw_data)
            
            # 品質チェック
            quality_results = self._perform_quality_checks(transformed_data)
            
            # データロード
            load_results = self._load_data(transformed_data)
            
            # メタデータ更新
            self._update_metadata(transformed_data)
            
            # 実行結果
            execution_results = {
                'execution_id': execution_id,
                'status': 'SUCCESS',
                'records_processed': len(transformed_data),
                'quality_score': quality_results['overall_score'],
                'load_results': load_results,
                'execution_time': datetime.now().isoformat()
            }
            
            self.logger.info(f"Pipeline execution completed: {execution_results}")
            return execution_results
            
        except Exception as e:
            error_results = {
                'execution_id': execution_id,
                'status': 'FAILED',
                'error': str(e),
                'execution_time': datetime.now().isoformat()
            }
            self.logger.error(f"Pipeline execution failed: {error_results}")
            raise
    
    def _extract_data(self) -> pd.DataFrame:
        """データ抽出"""
        source_type = self.config.source_config['type']
        
        if source_type == 's3':
            return self._extract_from_s3()
        elif source_type == 'rds':
            return self._extract_from_rds()
        elif source_type == 'api':
            return self._extract_from_api()
        else:
            raise ValueError(f"Unsupported source type: {source_type}")
    
    def _extract_from_s3(self) -> pd.DataFrame:
        """S3からのデータ抽出"""
        bucket = self.config.source_config['bucket']
        prefix = self.config.source_config['prefix']
        
        # S3オブジェクト一覧取得
        objects = self.s3.list_objects_v2(Bucket=bucket, Prefix=prefix)
        
        dataframes = []
        for obj in objects.get('Contents', []):
            if obj['Key'].endswith('.csv'):
                df = pd.read_csv(f"s3://{bucket}/{obj['Key']}")
                dataframes.append(df)
            elif obj['Key'].endswith('.parquet'):
                df = pd.read_parquet(f"s3://{bucket}/{obj['Key']}")
                dataframes.append(df)
        
        return pd.concat(dataframes, ignore_index=True) if dataframes else pd.DataFrame()
    
    def _transform_data(self, raw_data: pd.DataFrame) -> pd.DataFrame:
        """データ変換の実行"""
        data = raw_data.copy()
        
        # 設定されたトランスフォーマーを順次適用
        for rule in self.config.transformation_rules:
            transformer_name = rule['transformer']
            transformer = self.transformers.get(transformer_name)
            
            if transformer:
                if transformer.validate(data):
                    data = transformer.transform(data)
                else:
                    raise ValueError(f"Data validation failed for transformer: {transformer_name}")
        
        return data
    
    def _perform_quality_checks(self, data: pd.DataFrame) -> Dict[str, Any]:
        """データ品質チェック"""
        quality_results = {
            'checks': [],
            'overall_score': 0.0
        }
        
        total_score = 0
        for check in self.config.quality_checks:
            check_name = check['name']
            check_type = check['type']
            threshold = check.get('threshold', 0.95)
            
            if check_type == 'completeness':
                score = self._check_completeness(data, check['columns'])
            elif check_type == 'uniqueness':
                score = self._check_uniqueness(data, check['columns'])
            elif check_type == 'range':
                score = self._check_range(data, check['column'], check['min'], check['max'])
            else:
                score = 1.0
            
            passed = score >= threshold
            quality_results['checks'].append({
                'name': check_name,
                'type': check_type,
                'score': score,
                'threshold': threshold,
                'passed': passed
            })
            
            total_score += score
        
        quality_results['overall_score'] = total_score / len(self.config.quality_checks) if self.config.quality_checks else 1.0
        return quality_results

# 高度なGlueジョブスクリプト
def advanced_glue_job_script():
    """高度なGlueジョブスクリプトテンプレート"""
    return """
import sys
import boto3
import pandas as pd
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql import functions as F
from pyspark.sql.types import *
from datetime import datetime, timedelta
import logging

# ログ設定
logger = logging.getLogger()
logger.setLevel(logging.INFO)

class AdvancedGlueJob:
    \"\"\"高度なGlueジョブクラス\"\"\"
    
    def __init__(self):
        self.args = getResolvedOptions(sys.argv, [
            'JOB_NAME', 'raw_bucket', 'processed_bucket', 'curated_bucket',
            'database_name', 'table_name', 'partition_date'
        ])
        
        self.sc = SparkContext()
        self.glueContext = GlueContext(self.sc)
        self.spark = self.glueContext.spark_session
        self.job = Job(self.glueContext)
        self.job.init(self.args['JOB_NAME'], self.args)
    
    def run(self):
        \"\"\"メイン実行関数\"\"\"
        try:
            logger.info(f"Starting job: {self.args['JOB_NAME']}")
            
            # データ読み込み
            raw_df = self.read_raw_data()
            
            # データ品質チェック
            if not self.validate_data_quality(raw_df):
                raise Exception("Data quality validation failed")
            
            # データ変換
            transformed_df = self.transform_data(raw_df)
            
            # 重複除去
            deduped_df = self.deduplicate_data(transformed_df)
            
            # パーティション処理
            partitioned_df = self.add_partitions(deduped_df)
            
            # データ書き込み
            self.write_processed_data(partitioned_df)
            
            # 集約データ作成
            aggregated_df = self.create_aggregations(partitioned_df)
            self.write_curated_data(aggregated_df)
            
            # メタデータ更新
            self.update_catalog()
            
            logger.info("Job completed successfully")
            
        except Exception as e:
            logger.error(f"Job failed: {str(e)}")
            raise
        finally:
            self.job.commit()
    
    def read_raw_data(self):
        \"\"\"生データ読み込み\"\"\"
        input_path = f"s3://{self.args['raw_bucket']}/data/{self.args['partition_date']}"
        
        # スキーマ定義
        schema = StructType([
            StructField("transaction_id", StringType(), True),
            StructField("customer_id", StringType(), True),
            StructField("product_id", StringType(), True),
            StructField("quantity", IntegerType(), True),
            StructField("unit_price", DoubleType(), True),
            StructField("transaction_date", TimestampType(), True),
            StructField("store_id", StringType(), True)
        ])
        
        df = self.spark.read.schema(schema).option("header", "true").csv(input_path)
        logger.info(f"Read {df.count()} records from {input_path}")
        
        return df
    
    def validate_data_quality(self, df):
        \"\"\"データ品質検証\"\"\"
        total_records = df.count()
        
        # NULL値チェック
        null_checks = {
            'transaction_id': df.filter(F.col('transaction_id').isNull()).count(),
            'customer_id': df.filter(F.col('customer_id').isNull()).count(),
            'quantity': df.filter(F.col('quantity').isNull()).count(),
            'unit_price': df.filter(F.col('unit_price').isNull()).count()
        }
        
        # 品質メトリクス計算
        quality_metrics = {}
        for field, null_count in null_checks.items():
            completeness = 1 - (null_count / total_records)
            quality_metrics[f"{field}_completeness"] = completeness
            
            if completeness < 0.95:  # 95%未満は品質不良
                logger.error(f"Data quality check failed for {field}: {completeness:.2%}")
                return False
        
        # 範囲チェック
        invalid_quantity = df.filter(F.col('quantity') <= 0).count()
        invalid_price = df.filter(F.col('unit_price') < 0).count()
        
        if invalid_quantity > 0 or invalid_price > 0:
            logger.error(f"Invalid data found: quantity={invalid_quantity}, price={invalid_price}")
            return False
        
        logger.info(f"Data quality validation passed: {quality_metrics}")
        return True
    
    def transform_data(self, df):
        \"\"\"データ変換\"\"\"
        # 計算フィールド追加
        transformed_df = df.withColumn("total_amount", F.col("quantity") * F.col("unit_price")) \\
                          .withColumn("transaction_year", F.year("transaction_date")) \\
                          .withColumn("transaction_month", F.month("transaction_date")) \\
                          .withColumn("transaction_day", F.dayofmonth("transaction_date")) \\
                          .withColumn("day_of_week", F.dayofweek("transaction_date")) \\
                          .withColumn("hour", F.hour("transaction_date"))
        
        # 顧客セグメント計算
        customer_metrics = transformed_df.groupBy("customer_id") \\
                                       .agg(F.sum("total_amount").alias("total_spent"),
                                           F.count("transaction_id").alias("transaction_count"))
        
        segmentation_conditions = [
            F.when((F.col("total_spent") >= 1000) & (F.col("transaction_count") >= 10), "premium")
             .when((F.col("total_spent") >= 500) & (F.col("transaction_count") >= 5), "gold")
             .when(F.col("total_spent") >= 100, "silver")
             .otherwise("bronze")
        ]
        
        customer_segments = customer_metrics.withColumn("customer_segment", segmentation_conditions[0])
        
        # メインデータに顧客セグメント結合
        final_df = transformed_df.join(customer_segments.select("customer_id", "customer_segment"), 
                                     "customer_id", "left")
        
        return final_df
    
    def write_processed_data(self, df):
        \"\"\"処理済みデータ書き込み\"\"\"
        output_path = f"s3://{self.args['processed_bucket']}/transactions/"
        
        df.write.mode("overwrite") \\
          .partitionBy("transaction_year", "transaction_month", "transaction_day") \\
          .parquet(output_path)
        
        logger.info(f"Wrote processed data to {output_path}")

if __name__ == "__main__":
    job = AdvancedGlueJob()
    job.run()
"""

# 使用例
def example_usage():
    """使用例"""
    config = ETLJobConfig(
        job_name="customer_sales_etl",
        source_config={
            "type": "s3",
            "bucket": "raw-data-bucket",
            "prefix": "customer_data/"
        },
        target_config={
            "type": "s3",
            "bucket": "curated-data-bucket",
            "prefix": "customer_analytics/"
        },
        transformation_rules=[
            {"transformer": "customer"},
            {"transformer": "sales"}
        ],
        quality_checks=[
            {"name": "customer_completeness", "type": "completeness", "columns": ["customer_id", "email"], "threshold": 0.95},
            {"name": "customer_uniqueness", "type": "uniqueness", "columns": ["customer_id"], "threshold": 0.99}
        ]
    )
    
    pipeline = EnterpriseETLPipeline(config)
    results = pipeline.execute_pipeline()
    print(f"Pipeline execution results: {results}")
```

### 📊 データ系譜管理システム
データの流れと変換履歴を追跡するシステムです。

```python
# src/advanced/data_lineage.py
import boto3
import networkx as nx
import matplotlib.pyplot as plt
from typing import Dict, List, Set, Tuple
from dataclasses import dataclass
from datetime import datetime
import json

@dataclass
class DataAsset:
    """データアセット定義"""
    asset_id: str
    asset_type: str  # table, file, api, etc.
    location: str
    schema: Dict[str, str]
    owner: str
    created_at: datetime
    last_modified: datetime

@dataclass
class DataTransformation:
    """データ変換定義"""
    transformation_id: str
    source_assets: List[str]
    target_assets: List[str]
    transformation_type: str  # etl_job, glue_job, lambda, etc.
    code_location: str
    executed_at: datetime
    execution_context: Dict[str, str]

class DataLineageTracker:
    """データ系譜追跡システム"""
    
    def __init__(self):
        self.graph = nx.DiGraph()
        self.assets = {}
        self.transformations = {}
        self.glue = boto3.client('glue')
        self.s3 = boto3.client('s3')
    
    def register_asset(self, asset: DataAsset):
        """データアセット登録"""
        self.assets[asset.asset_id] = asset
        self.graph.add_node(asset.asset_id, **asset.__dict__)
    
    def register_transformation(self, transformation: DataTransformation):
        """変換処理登録"""
        self.transformations[transformation.transformation_id] = transformation
        
        # グラフにエッジ追加
        for source in transformation.source_assets:
            for target in transformation.target_assets:
                self.graph.add_edge(
                    source, target,
                    transformation_id=transformation.transformation_id,
                    **transformation.__dict__
                )
    
    def trace_lineage_upstream(self, asset_id: str, max_depth: int = 10) -> Set[str]:
        """上流系譜追跡"""
        upstream_assets = set()
        
        def _traverse_upstream(current_asset, depth):
            if depth > max_depth:
                return
            
            predecessors = list(self.graph.predecessors(current_asset))
            for pred in predecessors:
                upstream_assets.add(pred)
                _traverse_upstream(pred, depth + 1)
        
        _traverse_upstream(asset_id, 0)
        return upstream_assets
    
    def trace_lineage_downstream(self, asset_id: str, max_depth: int = 10) -> Set[str]:
        """下流系譜追跡"""
        downstream_assets = set()
        
        def _traverse_downstream(current_asset, depth):
            if depth > max_depth:
                return
            
            successors = list(self.graph.successors(current_asset))
            for succ in successors:
                downstream_assets.add(succ)
                _traverse_downstream(succ, depth + 1)
        
        _traverse_downstream(asset_id, 0)
        return downstream_assets
    
    def find_impact_analysis(self, asset_id: str) -> Dict[str, List[str]]:
        """影響分析"""
        downstream = self.trace_lineage_downstream(asset_id)
        
        # 影響を受けるアセットを種類別に分類
        impact_by_type = {}
        for asset in downstream:
            asset_info = self.assets.get(asset)
            if asset_info:
                asset_type = asset_info.asset_type
                if asset_type not in impact_by_type:
                    impact_by_type[asset_type] = []
                impact_by_type[asset_type].append(asset)
        
        return impact_by_type
    
    def visualize_lineage(self, asset_id: str, output_path: str):
        """系譜可視化"""
        # 関連するアセットを抽出
        upstream = self.trace_lineage_upstream(asset_id)
        downstream = self.trace_lineage_downstream(asset_id)
        related_assets = upstream.union(downstream).union({asset_id})
        
        # サブグラフ作成
        subgraph = self.graph.subgraph(related_assets)
        
        # レイアウト計算
        pos = nx.spring_layout(subgraph, k=3, iterations=50)
        
        # 描画
        plt.figure(figsize=(15, 10))
        
        # ノード描画（種類別に色分け）
        node_colors = {
            'table': 'lightblue',
            'file': 'lightgreen',
            'api': 'lightyellow',
            'view': 'lightcoral'
        }
        
        for asset in related_assets:
            asset_info = self.assets.get(asset, {})
            color = node_colors.get(asset_info.asset_type if hasattr(asset_info, 'asset_type') else 'unknown', 'lightgray')
            nx.draw_networkx_nodes(subgraph, pos, nodelist=[asset], node_color=color, node_size=1000)
        
        # エッジ描画
        nx.draw_networkx_edges(subgraph, pos, edge_color='gray', arrows=True, arrowsize=20)
        
        # ラベル描画
        nx.draw_networkx_labels(subgraph, pos, font_size=8)
        
        # 中心ノード強調
        nx.draw_networkx_nodes(subgraph, pos, nodelist=[asset_id], node_color='red', node_size=1500)
        
        plt.title(f"Data Lineage for {asset_id}")
        plt.axis('off')
        plt.tight_layout()
        plt.savefig(output_path, dpi=300, bbox_inches='tight')
        plt.close()
    
    def generate_lineage_report(self, asset_id: str) -> Dict[str, Any]:
        """系譜レポート生成"""
        upstream = self.trace_lineage_upstream(asset_id)
        downstream = self.trace_lineage_downstream(asset_id)
        impact_analysis = self.find_impact_analysis(asset_id)
        
        # 変換パス分析
        transformation_paths = []
        for source in upstream:
            if self.graph.has_edge(source, asset_id):
                edge_data = self.graph.get_edge_data(source, asset_id)
                transformation_paths.append({
                    'source': source,
                    'target': asset_id,
                    'transformation': edge_data.get('transformation_id'),
                    'executed_at': edge_data.get('executed_at')
                })
        
        report = {
            'asset_id': asset_id,
            'asset_info': self.assets.get(asset_id).__dict__ if asset_id in self.assets else {},
            'upstream_count': len(upstream),
            'downstream_count': len(downstream),
            'upstream_assets': list(upstream),
            'downstream_assets': list(downstream),
            'impact_analysis': impact_analysis,
            'transformation_paths': transformation_paths,
            'generated_at': datetime.now().isoformat()
        }
        
        return report

# 使用例
def setup_sample_lineage():
    """サンプル系譜設定"""
    tracker = DataLineageTracker()
    
    # データアセット登録
    assets = [
        DataAsset("raw_customers", "table", "s3://raw/customers/", {"id": "string", "name": "string"}, "data-team", datetime.now(), datetime.now()),
        DataAsset("raw_orders", "table", "s3://raw/orders/", {"order_id": "string", "customer_id": "string"}, "data-team", datetime.now(), datetime.now()),
        DataAsset("clean_customers", "table", "s3://processed/customers/", {"id": "string", "name": "string", "segment": "string"}, "data-team", datetime.now(), datetime.now()),
        DataAsset("customer_analytics", "view", "redshift://analytics/customer_summary", {"customer_id": "string", "total_orders": "int"}, "analytics-team", datetime.now(), datetime.now())
    ]
    
    for asset in assets:
        tracker.register_asset(asset)
    
    # 変換処理登録
    transformations = [
        DataTransformation("customer_etl", ["raw_customers"], ["clean_customers"], "glue_job", "s3://scripts/customer_etl.py", datetime.now(), {"job_run_id": "jr_123"}),
        DataTransformation("analytics_view", ["clean_customers", "raw_orders"], ["customer_analytics"], "sql_view", "redshift://views/customer_analytics.sql", datetime.now(), {"view_version": "v1"})
    ]
    
    for transformation in transformations:
        tracker.register_transformation(transformation)
    
    return tracker
```

### 🔄 リアルタイムETLパターン
ストリーミングデータとバッチデータを統合したハイブリッドETLです。

```python
# src/advanced/realtime_etl.py
import boto3
import json
import pandas as pd
from typing import Dict, List, Any
from datetime import datetime, timedelta
import asyncio
import logging

class RealtimeETLProcessor:
    """リアルタイムETLプロセッサー"""
    
    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.kinesis = boto3.client('kinesis')
        self.s3 = boto3.client('s3')
        self.glue = boto3.client('glue')
        self.dynamodb = boto3.resource('dynamodb')
        self.logger = logging.getLogger(__name__)
        
        # 状態管理テーブル
        self.state_table = self.dynamodb.Table(config['state_table_name'])
    
    async def process_stream_batch(self, records: List[Dict]) -> Dict[str, Any]:
        """ストリームバッチ処理"""
        start_time = datetime.now()
        
        # レコード前処理
        processed_records = []
        for record in records:
            try:
                processed_record = await self._preprocess_record(record)
                if processed_record:
                    processed_records.append(processed_record)
            except Exception as e:
                self.logger.error(f"Record preprocessing failed: {e}")
        
        # バッチサイズチェック
        if len(processed_records) < self.config.get('min_batch_size', 1):
            return {'status': 'skipped', 'reason': 'insufficient_records'}
        
        # リアルタイム変換
        transformed_records = await self._transform_records(processed_records)
        
        # 状態更新
        await self._update_processing_state(transformed_records)
        
        # マイクロバッチロード
        load_result = await self._load_microbatch(transformed_records)
        
        processing_time = (datetime.now() - start_time).total_seconds()
        
        return {
            'status': 'success',
            'records_processed': len(processed_records),
            'records_transformed': len(transformed_records),
            'processing_time_seconds': processing_time,
            'load_result': load_result
        }
    
    async def _preprocess_record(self, record: Dict) -> Dict:
        """レコード前処理"""
        # データ検証
        if not self._validate_record_schema(record):
            return None
        
        # エンリッチメント
        enriched_record = await self._enrich_record(record)
        
        # 重複チェック
        if await self._is_duplicate(enriched_record):
            return None
        
        return enriched_record
    
    def _validate_record_schema(self, record: Dict) -> bool:
        """レコードスキーマ検証"""
        required_fields = self.config.get('required_fields', [])
        return all(field in record for field in required_fields)
    
    async def _enrich_record(self, record: Dict) -> Dict:
        """レコードエンリッチメント"""
        enriched = record.copy()
        
        # タイムスタンプ正規化
        if 'timestamp' in record:
            enriched['processed_timestamp'] = datetime.now().isoformat()
        
        # 地理的エンリッチメント
        if 'ip_address' in record:
            geo_info = await self._lookup_geo_info(record['ip_address'])
            enriched.update(geo_info)
        
        # 顧客データエンリッチメント
        if 'customer_id' in record:
            customer_info = await self._lookup_customer_info(record['customer_id'])
            enriched.update(customer_info)
        
        return enriched
    
    async def _lookup_geo_info(self, ip_address: str) -> Dict:
        """IP地理情報検索"""
        # 実装例: 外部APIまたはローカルDBからGeoIPデータ取得
        # ここではモックデータを返す
        return {
            'country': 'JP',
            'region': 'Tokyo',
            'city': 'Tokyo'
        }
    
    async def _lookup_customer_info(self, customer_id: str) -> Dict:
        """顧客情報検索"""
        try:
            # DynamoDBから顧客情報取得
            response = await asyncio.get_event_loop().run_in_executor(
                None,
                lambda: self.state_table.get_item(Key={'customer_id': customer_id})
            )
            
            if 'Item' in response:
                return {
                    'customer_segment': response['Item'].get('segment', 'unknown'),
                    'customer_tier': response['Item'].get('tier', 'standard')
                }
        except Exception as e:
            self.logger.warning(f"Customer lookup failed: {e}")
        
        return {'customer_segment': 'unknown', 'customer_tier': 'standard'}
    
    async def _is_duplicate(self, record: Dict) -> bool:
        """重複チェック"""
        # 実装例: レコードの一意キーを使用して重複チェック
        unique_key = f"{record.get('event_id', '')}_{record.get('timestamp', '')}"
        
        try:
            response = await asyncio.get_event_loop().run_in_executor(
                None,
                lambda: self.state_table.get_item(Key={'record_key': unique_key})
            )
            return 'Item' in response
        except:
            return False

# Lambda関数実装例
def realtime_etl_lambda_handler(event, context):
    """リアルタイムETL Lambda関数"""
    
    config = {
        'state_table_name': 'etl-processing-state',
        'required_fields': ['event_id', 'timestamp', 'user_id'],
        'min_batch_size': 10,
        'output_bucket': 'realtime-processed-data'
    }
    
    processor = RealtimeETLProcessor(config)
    
    # Kinesisレコード処理
    records = []
    for record in event['Records']:
        try:
            data = json.loads(base64.b64decode(record['kinesis']['data']))
            records.append(data)
        except Exception as e:
            print(f"Error decoding record: {e}")
    
    # 非同期処理実行
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    
    try:
        result = loop.run_until_complete(processor.process_stream_batch(records))
        return {
            'statusCode': 200,
            'body': json.dumps(result)
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
    finally:
        loop.close()
```

### 🧪 ETL自動テストフレームワーク

```python
# src/testing/etl_test_framework.py
import pytest
import pandas as pd
import boto3
from moto import mock_s3, mock_glue
from typing import Dict, List, Any
import tempfile
import os

class ETLTestFramework:
    """ETL自動テストフレームワーク"""
    
    def __init__(self):
        self.test_data_path = tempfile.mkdtemp()
    
    def create_test_data(self, schema: Dict[str, str], num_records: int = 100) -> pd.DataFrame:
        """テストデータ生成"""
        import random
        from faker import Faker
        
        fake = Faker('ja_JP')
        data = {}
        
        for column, data_type in schema.items():
            if data_type == 'string':
                data[column] = [fake.name() for _ in range(num_records)]
            elif data_type == 'int':
                data[column] = [random.randint(1, 1000) for _ in range(num_records)]
            elif data_type == 'float':
                data[column] = [random.uniform(0, 1000) for _ in range(num_records)]
            elif data_type == 'datetime':
                data[column] = [fake.date_time_this_year() for _ in range(num_records)]
            elif data_type == 'email':
                data[column] = [fake.email() for _ in range(num_records)]
        
        return pd.DataFrame(data)
    
    def assert_data_quality(self, df: pd.DataFrame, quality_rules: List[Dict]) -> bool:
        """データ品質アサーション"""
        for rule in quality_rules:
            rule_type = rule['type']
            
            if rule_type == 'not_null':
                columns = rule['columns']
                for col in columns:
                    null_count = df[col].isnull().sum()
                    assert null_count == 0, f"Column {col} has {null_count} null values"
            
            elif rule_type == 'unique':
                columns = rule['columns']
                for col in columns:
                    duplicate_count = df.duplicated(subset=[col]).sum()
                    assert duplicate_count == 0, f"Column {col} has {duplicate_count} duplicate values"
            
            elif rule_type == 'range':
                col = rule['column']
                min_val = rule['min']
                max_val = rule['max']
                out_of_range = df[(df[col] < min_val) | (df[col] > max_val)].shape[0]
                assert out_of_range == 0, f"Column {col} has {out_of_range} values out of range [{min_val}, {max_val}]"
        
        return True
    
    def compare_schemas(self, expected_schema: Dict, actual_df: pd.DataFrame) -> bool:
        """スキーマ比較"""
        actual_columns = set(actual_df.columns)
        expected_columns = set(expected_schema.keys())
        
        missing_columns = expected_columns - actual_columns
        extra_columns = actual_columns - expected_columns
        
        assert len(missing_columns) == 0, f"Missing columns: {missing_columns}"
        assert len(extra_columns) == 0, f"Extra columns: {extra_columns}"
        
        return True

# テスト実装例
class TestCustomerETL:
    """顧客ETLテスト"""
    
    def setup_method(self):
        self.test_framework = ETLTestFramework()
    
    def test_customer_data_transformation(self):
        """顧客データ変換テスト"""
        # テストデータ作成
        schema = {
            'customer_id': 'string',
            'name': 'string',
            'email': 'email',
            'birth_date': 'datetime',
            'phone': 'string'
        }
        
        test_data = self.test_framework.create_test_data(schema, 50)
        
        # ETL変換実行
        transformer = CustomerDataTransformer()
        result_data = transformer.transform(test_data)
        
        # 品質チェック
        quality_rules = [
            {'type': 'not_null', 'columns': ['customer_id', 'email']},
            {'type': 'unique', 'columns': ['customer_id']},
            {'type': 'range', 'column': 'age', 'min': 0, 'max': 120}
        ]
        
        self.test_framework.assert_data_quality(result_data, quality_rules)
        
        # スキーマチェック
        expected_schema = {
            'customer_id': 'string',
            'name': 'string',
            'email': 'string',
            'age': 'int',
            'customer_segment': 'string'
        }
        
        self.test_framework.compare_schemas(expected_schema, result_data)
    
    @mock_s3
    def test_s3_data_loading(self):
        """S3データロードテスト"""
        # モックS3設定
        s3 = boto3.client('s3')
        bucket_name = 'test-bucket'
        s3.create_bucket(Bucket=bucket_name)
        
        # テストデータ準備
        test_data = pd.DataFrame({
            'id': [1, 2, 3],
            'value': ['a', 'b', 'c']
        })
        
        # S3への書き込みテスト
        csv_buffer = test_data.to_csv(index=False)
        s3.put_object(Bucket=bucket_name, Key='test/data.csv', Body=csv_buffer)
        
        # データ読み込みテスト
        response = s3.get_object(Bucket=bucket_name, Key='test/data.csv')
        loaded_data = pd.read_csv(response['Body'])
        
        # データ整合性確認
        pd.testing.assert_frame_equal(test_data, loaded_data)
```

これらの拡張により、ETLパイプラインに以下の高度な機能が追加されました：

1. **エンタープライズ級データファクトリー**: 設定駆動のETLパイプライン、高度なデータ変換、品質チェック
2. **データ系譜管理**: データの流れと変換履歴の追跡、影響分析、可視化
3. **リアルタイムETL**: ストリーミング・バッチ統合処理、非同期処理、状態管理
4. **自動テストフレームワーク**: データ品質テスト、スキーマ検証、モックサービス

これにより、実際のエンタープライズ環境で求められる高度なETL機能を学習できます。