# 4.2.1 QuickSightダッシュボード

## 学習目標

このセクションでは、Amazon QuickSightを活用したビジネスインテリジェンス（BI）ダッシュボードの構築を学習し、データレイクやDynamoDB、RDSなどの複数データソースを統合した高度な可視化・分析レポートシステムの実装方法を習得します。

### 習得できるスキル
- QuickSight による統合ダッシュボード構築
- 複数データソース（S3・DynamoDB・RDS・Athena）の統合
- SPICE エンジンによる高速データ分析
- カスタム計算フィールドと高度なビジュアライゼーション
- ユーザー・グループ別アクセス制御とレポート配信
- 機械学習インサイトとアノマリー検知

## 前提知識

### 必須の知識
- データウェアハウス・データレイクの基本概念
- SQL クエリの基本操作
- DynamoDB の基本操作（2.3.2セクション完了）
- ETLパイプライン（4.1.2セクション完了）

### あると望ましい知識
- ビジネスインテリジェンス（BI）の基本概念
- 統計学・データ分析の基礎知識
- ダッシュボード設計のベストプラクティス
- 機械学習の基本概念

## アーキテクチャ概要

### 統合ビジネスインテリジェンス アーキテクチャ

```
                    ┌─────────────────────┐
                    │   Business Users    │
                    │ (Executives/Analysts│
                    │  /Data Scientists)  │
                    └─────────┬───────────┘
                              │
                    ┌─────────┼───────────┐
                    │         │           │
                    ▼         ▼           ▼
          ┌─────────────────┐ ┌──────────┐ ┌─────────────────┐
          │   QuickSight    │ │  Mobile  │ │   Embedded      │
          │   Dashboard     │ │   App    │ │   Analytics     │
          └─────────┬───────┘ └────┬─────┘ └─────────┬───────┘
                    │              │                 │
                    └──────────────┼─────────────────┘
                                   │
                                   ▼
          ┌─────────────────────────────────────────────────────────┐
          │                Amazon QuickSight                        │
          │                                                         │
          │  ┌─────────────────────────────────────────────────┐   │
          │  │              SPICE Engine                        │   │
          │  │           (Super-fast Columnar)                 │   │
          │  │                                                  │   │
          │  │  ┌─────────────┐  ┌─────────────┐  ┌──────────┐ │   │
          │  │  │   In-Memory │  │ Compressed  │  │ Parallel │ │   │
          │  │  │    Cache    │  │   Storage   │  │  Query   │ │   │
          │  │  │             │  │             │  │          │ │   │
          │  │  │ ┌─────────┐ │  │ ┌─────────┐ │  │┌────────┐│ │   │
          │  │  │ │Hot Data │ │  │ │Columnar │ │  ││Parallel││ │   │
          │  │  │ │Access   │ │  │ │Format   │ │  ││Scan    ││ │   │
          │  │  │ └─────────┘ │  │ └─────────┘ │  │└────────┘│ │   │
          │  │  └─────────────┘  └─────────────┘  └──────────┘ │   │
          │  └─────────────────────────────────────────────────┘   │
          └─────────────────────────────────────────────────────────┘
                                   │
                                   ▼
          ┌─────────────────────────────────────────────────────────┐
          │              Data Source Connectors                     │
          │                                                         │
          │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │
          │  │   Amazon    │  │  DynamoDB   │  │    RDS      │   │
          │  │   Athena    │  │  (NoSQL)    │  │ (Relational)│   │
          │  │             │  │             │  │             │   │
          │  │┌──────────┐ │  │┌──────────┐ │  │┌──────────┐ │   │
          │  ││S3 Data   │ │  ││Tables    │ │  ││MySQL     │ │   │
          │  ││Lake      │ │  ││Indexes   │ │  ││PostgreSQL│ │   │
          │  ││Queries   │ │  ││Streams   │ │  ││Oracle    │ │   │
          │  │└──────────┘ │  │└──────────┘ │  │└──────────┘ │   │
          │  └─────────────┘  └─────────────┘  └─────────────┘   │
          └─────────┬───────────────┬───────────────┬─────────────┘
                    │               │               │
                    ▼               ▼               ▼
          ┌─────────────────┐ ┌──────────┐ ┌─────────────────┐
          │   Data Lake     │ │DynamoDB  │ │   Data Warehouse│
          │   (S3/Glue)     │ │ Tables   │ │     (RDS)       │
          │                 │ │          │ │                 │
          │ ┌─────────────┐ │ │┌────────┐ │ │ ┌─────────────┐ │
          │ │   Raw       │ │ ││Main    │ │ │ │  Dimension  │ │
          │ │   Curated   │ │ ││Table   │ │ │ │    Tables   │ │
          │ │   Analytics │ │ ││GSI     │ │ │ │    Fact     │ │
          │ │   Zones     │ │ │└────────┘ │ │ │   Tables    │ │
          │ └─────────────┘ │ └──────────┘ │ │ └─────────────┘ │
          └─────────────────┘              └─────────────────┘
                    │                               │
                    ▼                               ▼
          ┌─────────────────────────────────────────────────────────┐
          │               External Data Sources                     │
          │                                                         │
          │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │
          │  │   REST      │  │   CSV/JSON  │  │  3rd Party  │   │
          │  │   APIs      │  │   Files     │  │  Services   │   │
          │  │             │  │             │  │             │   │
          │  │┌──────────┐ │  │┌──────────┐ │  │┌──────────┐ │   │
          │  ││Salesforce│ │  ││S3        │ │  ││SaaS      │ │   │
          │  ││Google    │ │  ││Local     │ │  ││Snowflake │ │   │
          │  ││APIs      │ │  ││Files     │ │  ││Redshift  │ │   │
          │  │└──────────┘ │  │└──────────┘ │  │└──────────┘ │   │
          │  └─────────────┘  └─────────────┘  └─────────────┘   │
          └─────────────────────────────────────────────────────────┘
```

### 主要コンポーネント
- **Amazon QuickSight**: マネージドBIサービス
- **SPICE Engine**: インメモリ高速分析エンジン
- **Data Source Connectors**: 複数データソース統合
- **ML Insights**: 機械学習ベースの洞察
- **Embedded Analytics**: アプリケーション組み込み分析
- **User Management**: 詳細なアクセス制御

## ハンズオン手順

### ステップ1: QuickSight セットアップと権限設定

1. **CloudFormation による QuickSight インフラ構築**
```yaml
# cloudformation/quicksight-infrastructure.yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'QuickSight BI Dashboard Infrastructure'

Parameters:
  ProjectName:
    Type: String
    Default: 'quicksight-bi'
  
  EnvironmentName:
    Type: String
    Default: 'dev'
    AllowedValues: [dev, staging, prod]
  
  QuickSightIdentityRegion:
    Type: String
    Default: 'us-east-1'
    Description: 'QuickSight identity region (usually us-east-1)'

Conditions:
  IsProduction: !Equals [!Ref EnvironmentName, 'prod']

Resources:
  # QuickSight Service Role
  QuickSightServiceRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: !Sub '${ProjectName}-${EnvironmentName}-quicksight-service-role'
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: quicksight.amazonaws.com
            Action: sts:AssumeRole
      Policies:
        - PolicyName: S3DataLakeAccess
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - s3:GetObject
                  - s3:GetObjectVersion
                  - s3:ListBucket
                  - s3:ListBucketVersions
                Resource:
                  - !Sub '${DataLakeBucket}'
                  - !Sub '${DataLakeBucket}/*'
                  - !Sub '${AnalyticsDataBucket}'
                  - !Sub '${AnalyticsDataBucket}/*'
        
        - PolicyName: AthenaAccess
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - athena:BatchGetQueryExecution
                  - athena:GetQueryExecution
                  - athena:GetQueryResults
                  - athena:GetWorkGroup
                  - athena:ListQueryExecutions
                  - athena:StartQueryExecution
                  - athena:StopQueryExecution
                Resource: '*'
              - Effect: Allow
                Action:
                  - glue:GetDatabase
                  - glue:GetTable
                  - glue:GetTables
                  - glue:GetPartition
                  - glue:GetPartitions
                Resource: '*'
        
        - PolicyName: DynamoDBAccess
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - dynamodb:DescribeTable
                  - dynamodb:ListTables
                  - dynamodb:Query
                  - dynamodb:Scan
                Resource: 
                  - !Sub 'arn:aws:dynamodb:${AWS::Region}:${AWS::AccountId}:table/${ProjectName}-*'
        
        - PolicyName: RDSAccess
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - rds:DescribeDBInstances
                  - rds:DescribeDBClusters
                Resource: '*'

  # Athena Workgroup for QuickSight
  QuickSightAthenaWorkGroup:
    Type: AWS::Athena::WorkGroup
    Properties:
      Name: !Sub '${ProjectName}-${EnvironmentName}-quicksight-workgroup'
      Description: 'Athena workgroup for QuickSight queries'
      State: ENABLED
      WorkGroupConfiguration:
        ResultConfiguration:
          OutputLocation: !Sub 's3://${QueryResultsBucket}/athena-results/'
          EncryptionConfiguration:
            EncryptionOption: SSE_S3
        EnforceWorkGroupConfiguration: true
        PublishCloudWatchMetrics: true
        BytesScannedCutoffPerQuery: !If [IsProduction, 10737418240, 1073741824] # 10GB or 1GB
      Tags:
        - Key: Environment
          Value: !Ref EnvironmentName
        - Key: Project
          Value: !Ref ProjectName

  # S3 Bucket for Query Results
  QueryResultsBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Sub '${ProjectName}-${EnvironmentName}-query-results-${AWS::AccountId}'
      VersioningConfiguration:
        Status: Enabled
      BucketEncryption:
        ServerSideEncryptionConfiguration:
          - ServerSideEncryptionByDefault:
              SSEAlgorithm: AES256
      LifecycleConfiguration:
        Rules:
          - Id: QueryResultsLifecycle
            Status: Enabled
            ExpirationInDays: 90
            NoncurrentVersionExpirationInDays: 30
      PublicAccessBlockConfiguration:
        BlockPublicAcls: true
        BlockPublicPolicy: true
        IgnorePublicAcls: true
        RestrictPublicBuckets: true

  # QuickSight Dataset IAM Role
  QuickSightDataSetRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: !Sub '${ProjectName}-${EnvironmentName}-quicksight-dataset-role'
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              AWS: !Sub 'arn:aws:iam::${AWS::AccountId}:root'
            Action: sts:AssumeRole
            Condition:
              StringEquals:
                'sts:ExternalId': !Sub '${ProjectName}-quicksight-external-id'
      Policies:
        - PolicyName: CrossAccountQuickSightAccess
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - quicksight:CreateDataSet
                  - quicksight:CreateDataSource
                  - quicksight:DescribeDataSet
                  - quicksight:DescribeDataSource
                  - quicksight:PassRole
                Resource: '*'

  # Lambda Function for QuickSight Setup
  QuickSightSetupFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: !Sub '${ProjectName}-${EnvironmentName}-quicksight-setup'
      Runtime: python3.9
      Handler: index.lambda_handler
      Role: !GetAtt QuickSightSetupLambdaRole.Arn
      Code:
        ZipFile: |
          import json
          import boto3
          import cfnresponse
          from botocore.exceptions import ClientError
          
          def lambda_handler(event, context):
              quicksight = boto3.client('quicksight')
              
              try:
                  if event['RequestType'] == 'Create':
                      # QuickSight アカウント設定確認
                      try:
                          response = quicksight.describe_account_settings(
                              AwsAccountId=context.aws_account_id
                          )
                          print(f"QuickSight account already configured: {response}")
                      except ClientError as e:
                          if e.response['Error']['Code'] == 'ResourceNotFoundException':
                              print("QuickSight account not found. Manual setup required.")
                              cfnresponse.send(event, context, cfnresponse.SUCCESS, {
                                  'Message': 'QuickSight manual setup required'
                              })
                              return
                          else:
                              raise e
                      
                      # デフォルト設定を返す
                      cfnresponse.send(event, context, cfnresponse.SUCCESS, {
                          'Message': 'QuickSight setup completed'
                      })
                  
                  elif event['RequestType'] == 'Delete':
                      # クリーンアップ処理
                      cfnresponse.send(event, context, cfnresponse.SUCCESS, {})
                  
                  else:
                      cfnresponse.send(event, context, cfnresponse.SUCCESS, {})
              
              except Exception as e:
                  print(f"Error: {str(e)}")
                  cfnresponse.send(event, context, cfnresponse.FAILED, {
                      'Error': str(e)
                  })
      
      Environment:
        Variables:
          PROJECT_NAME: !Ref ProjectName
          ENVIRONMENT: !Ref EnvironmentName
      
      Timeout: 60

  # Lambda Role for QuickSight Setup
  QuickSightSetupLambdaRole:
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
        - PolicyName: QuickSightSetupAccess
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - quicksight:CreateAccountSubscription
                  - quicksight:DescribeAccountSettings
                  - quicksight:DescribeAccountSubscription
                  - quicksight:ListUsers
                  - quicksight:RegisterUser
                Resource: '*'

  # Custom Resource for QuickSight Setup
  QuickSightSetup:
    Type: AWS::CloudFormation::CustomResource
    Properties:
      ServiceToken: !GetAtt QuickSightSetupFunction.Arn
      ProjectName: !Ref ProjectName
      EnvironmentName: !Ref EnvironmentName

Outputs:
  QuickSightServiceRoleArn:
    Description: 'QuickSight service role ARN'
    Value: !GetAtt QuickSightServiceRole.Arn
    Export:
      Name: !Sub '${AWS::StackName}-QuickSightServiceRole'
  
  AthenaWorkGroupName:
    Description: 'Athena workgroup name for QuickSight'
    Value: !Ref QuickSightAthenaWorkGroup
    Export:
      Name: !Sub '${AWS::StackName}-AthenaWorkGroup'
  
  QueryResultsBucketName:
    Description: 'S3 bucket for query results'
    Value: !Ref QueryResultsBucket
    Export:
      Name: !Sub '${AWS::StackName}-QueryResultsBucket'
```

### ステップ2: データソース統合と データセット作成

1. **マルチソース データコネクタ実装**
```python
# src/quicksight/data_connector.py
import boto3
import json
import logging
from typing import Dict, List, Any, Optional
from dataclasses import dataclass
from botocore.exceptions import ClientError

@dataclass
class DataSourceConfig:
    name: str
    type: str
    connection_properties: Dict[str, Any]
    permissions: List[Dict[str, Any]]
    ssl_properties: Optional[Dict[str, Any]] = None

class QuickSightDataConnector:
    """
    QuickSight 複数データソース統合管理クラス
    """
    
    def __init__(self, account_id: str, region: str = 'ap-northeast-1'):
        self.quicksight = boto3.client('quicksight', region_name=region)
        self.account_id = account_id
        self.region = region
        self.logger = logging.getLogger(__name__)
    
    def create_athena_data_source(self, 
                                  data_source_id: str,
                                  name: str,
                                  workgroup: str) -> Dict[str, Any]:
        """
        Athena データソース作成
        """
        try:
            data_source_config = {
                'AwsAccountId': self.account_id,
                'DataSourceId': data_source_id,
                'Name': name,
                'Type': 'ATHENA',
                'DataSourceParameters': {
                    'AthenaParameters': {
                        'WorkGroup': workgroup
                    }
                },
                'Permissions': [
                    {
                        'Principal': f'arn:aws:quicksight:{self.region}:{self.account_id}:user/default/{self.account_id}/quicksight-admin',
                        'Actions': [
                            'quicksight:DescribeDataSource',
                            'quicksight:DescribeDataSourcePermissions',
                            'quicksight:PassDataSource',
                            'quicksight:UpdateDataSource',
                            'quicksight:DeleteDataSource',
                            'quicksight:UpdateDataSourcePermissions'
                        ]
                    }
                ],
                'SslProperties': {
                    'DisableSsl': False
                }
            }
            
            response = self.quicksight.create_data_source(**data_source_config)
            self.logger.info(f"Athena data source created: {data_source_id}")
            return response
            
        except ClientError as e:
            self.logger.error(f"Error creating Athena data source: {e}")
            raise e
    
    def create_dynamodb_data_source(self,
                                   data_source_id: str,
                                   name: str,
                                   region: str = None) -> Dict[str, Any]:
        """
        DynamoDB データソース作成
        """
        try:
            target_region = region or self.region
            
            data_source_config = {
                'AwsAccountId': self.account_id,
                'DataSourceId': data_source_id,
                'Name': name,
                'Type': 'DYNAMODB',
                'DataSourceParameters': {
                    'DynamoDBParameters': {
                        'Region': target_region
                    }
                },
                'Permissions': [
                    {
                        'Principal': f'arn:aws:quicksight:{self.region}:{self.account_id}:user/default/{self.account_id}/quicksight-admin',
                        'Actions': [
                            'quicksight:DescribeDataSource',
                            'quicksight:DescribeDataSourcePermissions',
                            'quicksight:PassDataSource',
                            'quicksight:UpdateDataSource',
                            'quicksight:DeleteDataSource',
                            'quicksight:UpdateDataSourcePermissions'
                        ]
                    }
                ]
            }
            
            response = self.quicksight.create_data_source(**data_source_config)
            self.logger.info(f"DynamoDB data source created: {data_source_id}")
            return response
            
        except ClientError as e:
            self.logger.error(f"Error creating DynamoDB data source: {e}")
            raise e
    
    def create_rds_data_source(self,
                              data_source_id: str,
                              name: str,
                              database_engine: str,
                              host: str,
                              port: int,
                              database: str,
                              username: str) -> Dict[str, Any]:
        """
        RDS データソース作成
        """
        try:
            # RDS接続パラメータ設定
            rds_params = {
                'Host': host,
                'Port': port,
                'Database': database,
                'Username': username
            }
            
            # エンジン別パラメータ設定
            if database_engine.lower() == 'mysql':
                data_source_type = 'MYSQL'
                connection_params = {'MySqlParameters': rds_params}
            elif database_engine.lower() == 'postgresql':
                data_source_type = 'POSTGRESQL'
                connection_params = {'PostgreSqlParameters': rds_params}
            elif database_engine.lower() == 'oracle':
                data_source_type = 'ORACLE'
                connection_params = {'OracleParameters': rds_params}
            else:
                raise ValueError(f"Unsupported database engine: {database_engine}")
            
            data_source_config = {
                'AwsAccountId': self.account_id,
                'DataSourceId': data_source_id,
                'Name': name,
                'Type': data_source_type,
                'DataSourceParameters': connection_params,
                'Credentials': {
                    'CredentialPair': {
                        'Username': username,
                        'Password': f'{data_source_id}-password'  # Secrets Managerから取得
                    }
                },
                'Permissions': [
                    {
                        'Principal': f'arn:aws:quicksight:{self.region}:{self.account_id}:user/default/{self.account_id}/quicksight-admin',
                        'Actions': [
                            'quicksight:DescribeDataSource',
                            'quicksight:DescribeDataSourcePermissions',
                            'quicksight:PassDataSource',
                            'quicksight:UpdateDataSource',
                            'quicksight:DeleteDataSource',
                            'quicksight:UpdateDataSourcePermissions'
                        ]
                    }
                ],
                'VpcConnectionProperties': {
                    'VpcConnectionArn': f'arn:aws:quicksight:{self.region}:{self.account_id}:vpcConnection/{data_source_id}-vpc'
                },
                'SslProperties': {
                    'DisableSsl': False
                }
            }
            
            response = self.quicksight.create_data_source(**data_source_config)
            self.logger.info(f"RDS data source created: {data_source_id}")
            return response
            
        except ClientError as e:
            self.logger.error(f"Error creating RDS data source: {e}")
            raise e
    
    def create_dataset(self,
                      dataset_id: str,
                      name: str,
                      data_source_id: str,
                      physical_table_map: Dict[str, Any],
                      logical_table_map: Optional[Dict[str, Any]] = None,
                      import_mode: str = 'SPICE') -> Dict[str, Any]:
        """
        データセット作成
        """
        try:
            dataset_config = {
                'AwsAccountId': self.account_id,
                'DataSetId': dataset_id,
                'Name': name,
                'PhysicalTableMap': physical_table_map,
                'ImportMode': import_mode,
                'Permissions': [
                    {
                        'Principal': f'arn:aws:quicksight:{self.region}:{self.account_id}:user/default/{self.account_id}/quicksight-admin',
                        'Actions': [
                            'quicksight:DescribeDataSet',
                            'quicksight:DescribeDataSetPermissions',
                            'quicksight:PassDataSet',
                            'quicksight:DescribeIngestion',
                            'quicksight:ListIngestions',
                            'quicksight:UpdateDataSet',
                            'quicksight:DeleteDataSet',
                            'quicksight:CreateIngestion',
                            'quicksight:CancelIngestion',
                            'quicksight:UpdateDataSetPermissions'
                        ]
                    }
                ]
            }
            
            # 論理テーブルマップ追加
            if logical_table_map:
                dataset_config['LogicalTableMap'] = logical_table_map
            
            response = self.quicksight.create_data_set(**dataset_config)
            self.logger.info(f"Dataset created: {dataset_id}")
            
            # SPICE への取り込み開始
            if import_mode == 'SPICE':
                ingestion_id = f"{dataset_id}-initial-ingestion"
                self.start_ingestion(dataset_id, ingestion_id)
            
            return response
            
        except ClientError as e:
            self.logger.error(f"Error creating dataset: {e}")
            raise e
    
    def start_ingestion(self, dataset_id: str, ingestion_id: str) -> Dict[str, Any]:
        """
        SPICE 取り込み開始
        """
        try:
            response = self.quicksight.create_ingestion(
                AwsAccountId=self.account_id,
                DataSetId=dataset_id,
                IngestionId=ingestion_id
            )
            
            self.logger.info(f"SPICE ingestion started: {ingestion_id}")
            return response
            
        except ClientError as e:
            self.logger.error(f"Error starting SPICE ingestion: {e}")
            raise e
    
    def create_sales_analytics_dataset(self) -> Dict[str, Any]:
        """
        売上分析用統合データセット作成例
        """
        dataset_id = 'sales-analytics-dataset'
        
        # 物理テーブルマップ定義
        physical_table_map = {
            'orders_table': {
                'CustomSql': {
                    'DataSourceArn': f'arn:aws:quicksight:{self.region}:{self.account_id}:datasource/athena-data-source',
                    'Name': 'Orders Data',
                    'SqlQuery': '''
                        SELECT 
                            o.order_id,
                            o.user_id,
                            o.order_date,
                            o.total_amount,
                            o.status,
                            oi.product_id,
                            oi.quantity,
                            oi.unit_price,
                            oi.quantity * oi.unit_price as line_total,
                            p.product_name,
                            p.category,
                            u.first_name,
                            u.last_name,
                            u.email,
                            EXTRACT(YEAR FROM CAST(o.order_date AS DATE)) as order_year,
                            EXTRACT(MONTH FROM CAST(o.order_date AS DATE)) as order_month,
                            EXTRACT(DAY FROM CAST(o.order_date AS DATE)) as order_day,
                            EXTRACT(DOW FROM CAST(o.order_date AS DATE)) as day_of_week
                        FROM orders o
                        JOIN order_items oi ON o.order_id = oi.order_id
                        JOIN products p ON oi.product_id = p.product_id
                        JOIN users u ON o.user_id = u.user_id
                        WHERE o.status IN ('COMPLETED', 'SHIPPED', 'DELIVERED')
                    ''',
                    'Columns': [
                        {'Name': 'order_id', 'Type': 'STRING'},
                        {'Name': 'user_id', 'Type': 'STRING'},
                        {'Name': 'order_date', 'Type': 'DATETIME'},
                        {'Name': 'total_amount', 'Type': 'DECIMAL'},
                        {'Name': 'status', 'Type': 'STRING'},
                        {'Name': 'product_id', 'Type': 'STRING'},
                        {'Name': 'quantity', 'Type': 'INTEGER'},
                        {'Name': 'unit_price', 'Type': 'DECIMAL'},
                        {'Name': 'line_total', 'Type': 'DECIMAL'},
                        {'Name': 'product_name', 'Type': 'STRING'},
                        {'Name': 'category', 'Type': 'STRING'},
                        {'Name': 'first_name', 'Type': 'STRING'},
                        {'Name': 'last_name', 'Type': 'STRING'},
                        {'Name': 'email', 'Type': 'STRING'},
                        {'Name': 'order_year', 'Type': 'INTEGER'},
                        {'Name': 'order_month', 'Type': 'INTEGER'},
                        {'Name': 'order_day', 'Type': 'INTEGER'},
                        {'Name': 'day_of_week', 'Type': 'INTEGER'}
                    ]
                }
            }
        }
        
        # 論理テーブルマップ（計算フィールド追加）
        logical_table_map = {
            'sales_analytics': {
                'Source': 'orders_table',
                'DataTransforms': [
                    {
                        'CreateColumnsOperation': {
                            'Columns': [
                                {
                                    'ColumnName': 'customer_full_name',
                                    'ColumnId': 'customer_full_name',
                                    'Expression': "concat({first_name}, ' ', {last_name})"
                                },
                                {
                                    'ColumnName': 'order_month_name',
                                    'ColumnId': 'order_month_name',
                                    'Expression': """
                                        ifelse({order_month} = 1, 'January',
                                        ifelse({order_month} = 2, 'February',
                                        ifelse({order_month} = 3, 'March',
                                        ifelse({order_month} = 4, 'April',
                                        ifelse({order_month} = 5, 'May',
                                        ifelse({order_month} = 6, 'June',
                                        ifelse({order_month} = 7, 'July',
                                        ifelse({order_month} = 8, 'August',
                                        ifelse({order_month} = 9, 'September',
                                        ifelse({order_month} = 10, 'October',
                                        ifelse({order_month} = 11, 'November',
                                        'December')))))))))))
                                    """
                                },
                                {
                                    'ColumnName': 'revenue_category',
                                    'ColumnId': 'revenue_category',
                                    'Expression': """
                                        ifelse({line_total} >= 10000, 'High Value',
                                        ifelse({line_total} >= 5000, 'Medium Value',
                                        'Low Value'))
                                    """
                                },
                                {
                                    'ColumnName': 'days_since_order',
                                    'ColumnId': 'days_since_order',
                                    'Expression': 'dateDiff(now(), {order_date}, "DD")'
                                }
                            ]
                        }
                    },
                    {
                        'FilterOperation': {
                            'ConditionExpression': '{total_amount} > 0'
                        }
                    }
                ]
            }
        }
        
        return self.create_dataset(
            dataset_id=dataset_id,
            name='Sales Analytics Dataset',
            data_source_id='athena-data-source',
            physical_table_map=physical_table_map,
            logical_table_map=logical_table_map,
            import_mode='SPICE'
        )
```

### ステップ3: ダッシュボード構築と高度なビジュアライゼーション

1. **包括的ダッシュボード作成**
```python
# src/quicksight/dashboard_builder.py
import boto3
import json
from typing import Dict, List, Any
from dataclasses import dataclass

@dataclass 
class VisualConfig:
    visual_id: str
    title: str
    visual_type: str
    field_wells: Dict[str, Any]
    sort_configuration: Dict[str, Any] = None
    format_configuration: Dict[str, Any] = None

class QuickSightDashboardBuilder:
    """
    QuickSight ダッシュボード構築クラス
    """
    
    def __init__(self, account_id: str, region: str = 'ap-northeast-1'):
        self.quicksight = boto3.client('quicksight', region_name=region)
        self.account_id = account_id
        self.region = region
    
    def create_analysis(self, analysis_id: str, name: str, dataset_id: str) -> Dict[str, Any]:
        """
        分析（Analysis）作成
        """
        try:
            # ビジュアル定義
            visuals = [
                self._create_kpi_visual(),
                self._create_revenue_trend_visual(),
                self._create_category_breakdown_visual(),
                self._create_top_products_visual(),
                self._create_customer_segments_visual(),
                self._create_geographic_heatmap_visual(),
                self._create_cohort_analysis_visual(),
                self._create_forecast_visual()
            ]
            
            analysis_config = {
                'AwsAccountId': self.account_id,
                'AnalysisId': analysis_id,
                'Name': name,
                'Definition': {
                    'DataSetIdentifierDeclarations': [
                        {
                            'DataSetArn': f'arn:aws:quicksight:{self.region}:{self.account_id}:dataset/{dataset_id}',
                            'Identifier': 'sales_data'
                        }
                    ],
                    'Sheets': [
                        {
                            'SheetId': 'executive-dashboard',
                            'Name': 'Executive Dashboard',
                            'Visuals': visuals[:4],  # 主要メトリクス
                            'Layouts': [
                                {
                                    'Configuration': {
                                        'GridLayout': {
                                            'Elements': [
                                                {
                                                    'ElementId': visuals[0]['VisualId'],
                                                    'ElementType': 'VISUAL',
                                                    'ColumnIndex': 0,
                                                    'ColumnSpan': 3,
                                                    'RowIndex': 0,
                                                    'RowSpan': 2
                                                },
                                                {
                                                    'ElementId': visuals[1]['VisualId'],
                                                    'ElementType': 'VISUAL',
                                                    'ColumnIndex': 3,
                                                    'ColumnSpan': 9,
                                                    'RowIndex': 0,
                                                    'RowSpan': 6
                                                }
                                            ]
                                        }
                                    }
                                }
                            ]
                        },
                        {
                            'SheetId': 'detailed-analytics',
                            'Name': 'Detailed Analytics',
                            'Visuals': visuals[4:],  # 詳細分析
                            'Layouts': [
                                {
                                    'Configuration': {
                                        'GridLayout': {
                                            'Elements': [
                                                {
                                                    'ElementId': visuals[4]['VisualId'],
                                                    'ElementType': 'VISUAL',
                                                    'ColumnIndex': 0,
                                                    'ColumnSpan': 6,
                                                    'RowIndex': 0,
                                                    'RowSpan': 6
                                                },
                                                {
                                                    'ElementId': visuals[5]['VisualId'],
                                                    'ElementType': 'VISUAL',
                                                    'ColumnIndex': 6,
                                                    'ColumnSpan': 6,
                                                    'RowIndex': 0,
                                                    'RowSpan': 6
                                                }
                                            ]
                                        }
                                    }
                                }
                            ]
                        }
                    ],
                    'CalculatedFields': [
                        {
                            'DataSetIdentifier': 'sales_data',
                            'Name': 'Revenue Growth Rate',
                            'Expression': '''
                                (sum({line_total}) - sumOver(sum({line_total}), 
                                [dateDiff({order_date}, now(), "MM") = 1], PRE)) / 
                                sumOver(sum({line_total}), 
                                [dateDiff({order_date}, now(), "MM") = 1], PRE) * 100
                            '''
                        },
                        {
                            'DataSetIdentifier': 'sales_data',
                            'Name': 'Customer Lifetime Value',
                            'Expression': '''
                                sum({line_total}) / countDistinct({user_id})
                            '''
                        },
                        {
                            'DataSetIdentifier': 'sales_data',
                            'Name': 'Average Order Value',
                            'Expression': '''
                                sum({line_total}) / countDistinct({order_id})
                            '''
                        }
                    ],
                    'FilterGroups': [
                        {
                            'FilterGroupId': 'date-filter-group',
                            'Filters': [
                                {
                                    'DateTimeFilter': {
                                        'FilterId': 'date-range-filter',
                                        'Column': {
                                            'DataSetIdentifier': 'sales_data',
                                            'ColumnName': 'order_date'
                                        },
                                        'TimeGranularity': 'DAY',
                                        'DefaultFilterControlConfiguration': {
                                            'Title': 'Date Range',
                                            'ControlOptions': {
                                                'DateTimePickerOptions': {
                                                    'Type': 'DATE_RANGE'
                                                }
                                            }
                                        }
                                    }
                                }
                            ],
                            'ScopeConfiguration': {
                                'SelectedSheets': {
                                    'SheetVisualScopingConfigurations': [
                                        {
                                            'SheetId': 'executive-dashboard',
                                            'Scope': 'ALL_VISUALS'
                                        },
                                        {
                                            'SheetId': 'detailed-analytics',
                                            'Scope': 'ALL_VISUALS'
                                        }
                                    ]
                                }
                            }
                        }
                    ],
                    'ParameterDeclarations': [
                        {
                            'StringParameterDeclaration': {
                                'ParameterValueType': 'SINGLE_VALUED',
                                'Name': 'CategoryFilter',
                                'DefaultValues': {
                                    'StaticValues': ['all']
                                },
                                'ValueWhenUnset': {
                                    'ValueWhenUnsetOption': 'RECOMMENDED_VALUE'
                                }
                            }
                        }
                    ]
                },
                'Permissions': [
                    {
                        'Principal': f'arn:aws:quicksight:{self.region}:{self.account_id}:user/default/{self.account_id}/quicksight-admin',
                        'Actions': [
                            'quicksight:RestoreAnalysis',
                            'quicksight:UpdateAnalysisPermissions',
                            'quicksight:DeleteAnalysis',
                            'quicksight:DescribeAnalysisPermissions',
                            'quicksight:QueryAnalysis',
                            'quicksight:DescribeAnalysis',
                            'quicksight:UpdateAnalysis'
                        ]
                    }
                ]
            }
            
            response = self.quicksight.create_analysis(**analysis_config)
            return response
            
        except Exception as e:
            print(f"Error creating analysis: {e}")
            raise e
    
    def _create_kpi_visual(self) -> Dict[str, Any]:
        """
        KPI ビジュアル作成
        """
        return {
            'VisualId': 'kpi-metrics',
            'KPIVisual': {
                'VisualId': 'kpi-metrics',
                'Title': {
                    'Visibility': 'VISIBLE',
                    'FormatText': {
                        'PlainText': 'Key Performance Indicators'
                    }
                },
                'Subtitle': {
                    'Visibility': 'VISIBLE',
                    'FormatText': {
                        'PlainText': 'Current Period vs Previous Period'
                    }
                },
                'ChartConfiguration': {
                    'FieldWells': {
                        'Values': [
                            {
                                'NumericalMeasureField': {
                                    'FieldId': 'total_revenue',
                                    'Column': {
                                        'DataSetIdentifier': 'sales_data',
                                        'ColumnName': 'line_total'
                                    },
                                    'AggregationFunction': {
                                        'SimpleNumericalAggregation': 'SUM'
                                    }
                                }
                            }
                        ],
                        'TargetValues': [
                            {
                                'NumericalMeasureField': {
                                    'FieldId': 'target_revenue',
                                    'Column': {
                                        'DataSetIdentifier': 'sales_data',
                                        'ColumnName': 'line_total'
                                    },
                                    'AggregationFunction': {
                                        'SimpleNumericalAggregation': 'SUM'
                                    }
                                }
                            }
                        ]
                    },
                    'KPIOptions': {
                        'Comparison': {
                            'ComparisonMethod': 'DIFFERENCE'
                        },
                        'PrimaryValueDisplayType': 'ACTUAL',
                        'ProgressBar': {
                            'Visibility': 'VISIBLE'
                        }
                    }
                }
            }
        }
    
    def _create_revenue_trend_visual(self) -> Dict[str, Any]:
        """
        売上トレンド ライン チャート
        """
        return {
            'VisualId': 'revenue-trend',
            'LineChartVisual': {
                'VisualId': 'revenue-trend',
                'Title': {
                    'Visibility': 'VISIBLE',
                    'FormatText': {
                        'PlainText': 'Revenue Trend Analysis'
                    }
                },
                'ChartConfiguration': {
                    'FieldWells': {
                        'LineChartAggregatedFieldWells': {
                            'Category': [
                                {
                                    'DateDimensionField': {
                                        'FieldId': 'order_date',
                                        'Column': {
                                            'DataSetIdentifier': 'sales_data',
                                            'ColumnName': 'order_date'
                                        },
                                        'HierarchyId': 'date_hierarchy',
                                        'DateGranularity': 'MONTH'
                                    }
                                }
                            ],
                            'Values': [
                                {
                                    'NumericalMeasureField': {
                                        'FieldId': 'monthly_revenue',
                                        'Column': {
                                            'DataSetIdentifier': 'sales_data',
                                            'ColumnName': 'line_total'
                                        },
                                        'AggregationFunction': {
                                            'SimpleNumericalAggregation': 'SUM'
                                        }
                                    }
                                }
                            ],
                            'Colors': [
                                {
                                    'CategoricalDimensionField': {
                                        'FieldId': 'category',
                                        'Column': {
                                            'DataSetIdentifier': 'sales_data',
                                            'ColumnName': 'category'
                                        }
                                    }
                                }
                            ]
                        }
                    },
                    'Type': 'LINE',
                    'DataLabels': {
                        'Visibility': 'VISIBLE',
                        'Overlap': 'DISABLE_OVERLAP'
                    },
                    'ForecastConfigurations': [
                        {
                            'ForecastProperties': {
                                'PeriodsForward': 3,
                                'PeriodsBackward': 0,
                                'UpperBoundary': 1000000,
                                'LowerBoundary': 0,
                                'PredictionInterval': 95
                            }
                        }
                    ]
                }
            }
        }
    
    def _create_category_breakdown_visual(self) -> Dict[str, Any]:
        """
        カテゴリ別売上 ドーナツ チャート
        """
        return {
            'VisualId': 'category-breakdown',
            'PieChartVisual': {
                'VisualId': 'category-breakdown',
                'Title': {
                    'Visibility': 'VISIBLE',
                    'FormatText': {
                        'PlainText': 'Revenue by Product Category'
                    }
                },
                'ChartConfiguration': {
                    'FieldWells': {
                        'PieChartAggregatedFieldWells': {
                            'Category': [
                                {
                                    'CategoricalDimensionField': {
                                        'FieldId': 'category',
                                        'Column': {
                                            'DataSetIdentifier': 'sales_data',
                                            'ColumnName': 'category'
                                        }
                                    }
                                }
                            ],
                            'Values': [
                                {
                                    'NumericalMeasureField': {
                                        'FieldId': 'category_revenue',
                                        'Column': {
                                            'DataSetIdentifier': 'sales_data',
                                            'ColumnName': 'line_total'
                                        },
                                        'AggregationFunction': {
                                            'SimpleNumericalAggregation': 'SUM'
                                        }
                                    }
                                }
                            ]
                        }
                    },
                    'DonutOptions': {
                        'ArcOptions': {
                            'ArcThickness': 'MEDIUM'
                        },
                        'DonutCenterOptions': {
                            'LabelVisibility': 'VISIBLE'
                        }
                    },
                    'DataLabels': {
                        'Visibility': 'VISIBLE',
                        'CategoryLabelVisibility': 'VISIBLE',
                        'MeasureLabelVisibility': 'VISIBLE'
                    }
                }
            }
        }
    
    def create_dashboard_from_analysis(self, 
                                     dashboard_id: str,
                                     name: str,
                                     analysis_id: str) -> Dict[str, Any]:
        """
        Analysis からダッシュボード作成
        """
        try:
            dashboard_config = {
                'AwsAccountId': self.account_id,
                'DashboardId': dashboard_id,
                'Name': name,
                'SourceEntity': {
                    'SourceTemplate': {
                        'DataSetReferences': [
                            {
                                'DataSetArn': f'arn:aws:quicksight:{self.region}:{self.account_id}:dataset/sales-analytics-dataset',
                                'DataSetPlaceholder': 'sales_data'
                            }
                        ],
                        'Arn': f'arn:aws:quicksight:{self.region}:{self.account_id}:analysis/{analysis_id}'
                    }
                },
                'Permissions': [
                    {
                        'Principal': f'arn:aws:quicksight:{self.region}:{self.account_id}:user/default/{self.account_id}/quicksight-admin',
                        'Actions': [
                            'quicksight:DescribeDashboard',
                            'quicksight:ListDashboardVersions',
                            'quicksight:UpdateDashboardPermissions',
                            'quicksight:QueryDashboard',
                            'quicksight:UpdateDashboard',
                            'quicksight:DeleteDashboard',
                            'quicksight:DescribeDashboardPermissions',
                            'quicksight:UpdateDashboardPublishedVersion'
                        ]
                    }
                ],
                'DashboardPublishOptions': {
                    'AdHocFilteringOption': {
                        'AvailabilityStatus': 'ENABLED'
                    },
                    'ExportToCSVOption': {
                        'AvailabilityStatus': 'ENABLED'
                    },
                    'SheetControlsOption': {
                        'VisibilityState': 'EXPANDED'
                    }
                }
            }
            
            response = self.quicksight.create_dashboard(**dashboard_config)
            return response
            
        except Exception as e:
            print(f"Error creating dashboard: {e}")
            raise e
```

### ステップ4: 機械学習インサイトと アノマリー検知

1. **ML Insights 設定**
```python
# src/quicksight/ml_insights.py
import boto3
from typing import Dict, List, Any

class QuickSightMLInsights:
    """
    QuickSight 機械学習インサイト管理クラス
    """
    
    def __init__(self, account_id: str, region: str = 'ap-northeast-1'):
        self.quicksight = boto3.client('quicksight', region_name=region)
        self.account_id = account_id
        self.region = region
    
    def create_anomaly_detection_visual(self, dataset_id: str) -> Dict[str, Any]:
        """
        アノマリー検知ビジュアル作成
        """
        return {
            'VisualId': 'anomaly-detection',
            'LineChartVisual': {
                'VisualId': 'anomaly-detection',
                'Title': {
                    'Visibility': 'VISIBLE',
                    'FormatText': {
                        'PlainText': 'Revenue Anomaly Detection'
                    }
                },
                'ChartConfiguration': {
                    'FieldWells': {
                        'LineChartAggregatedFieldWells': {
                            'Category': [
                                {
                                    'DateDimensionField': {
                                        'FieldId': 'order_date',
                                        'Column': {
                                            'DataSetIdentifier': dataset_id,
                                            'ColumnName': 'order_date'
                                        },
                                        'DateGranularity': 'DAY'
                                    }
                                }
                            ],
                            'Values': [
                                {
                                    'NumericalMeasureField': {
                                        'FieldId': 'daily_revenue',
                                        'Column': {
                                            'DataSetIdentifier': dataset_id,
                                            'ColumnName': 'line_total'
                                        },
                                        'AggregationFunction': {
                                            'SimpleNumericalAggregation': 'SUM'
                                        }
                                    }
                                }
                            ]
                        }
                    },
                    'ContributionAnalysisDefaults': [
                        {
                            'MeasureFieldId': 'daily_revenue',
                            'ContributorDimensions': [
                                {
                                    'DataSetIdentifier': dataset_id,
                                    'ColumnName': 'category'
                                },
                                {
                                    'DataSetIdentifier': dataset_id,
                                    'ColumnName': 'product_name'
                                }
                            ]
                        }
                    ]
                }
            }
        }
    
    def create_forecast_visual(self, dataset_id: str) -> Dict[str, Any]:
        """
        予測分析ビジュアル作成
        """
        return {
            'VisualId': 'revenue-forecast',
            'LineChartVisual': {
                'VisualId': 'revenue-forecast',
                'Title': {
                    'Visibility': 'VISIBLE',
                    'FormatText': {
                        'PlainText': 'Revenue Forecast (Next 90 Days)'
                    }
                },
                'ChartConfiguration': {
                    'FieldWells': {
                        'LineChartAggregatedFieldWells': {
                            'Category': [
                                {
                                    'DateDimensionField': {
                                        'FieldId': 'order_date',
                                        'Column': {
                                            'DataSetIdentifier': dataset_id,
                                            'ColumnName': 'order_date'
                                        },
                                        'DateGranularity': 'WEEK'
                                    }
                                }
                            ],
                            'Values': [
                                {
                                    'NumericalMeasureField': {
                                        'FieldId': 'weekly_revenue',
                                        'Column': {
                                            'DataSetIdentifier': dataset_id,
                                            'ColumnName': 'line_total'
                                        },
                                        'AggregationFunction': {
                                            'SimpleNumericalAggregation': 'SUM'
                                        }
                                    }
                                }
                            ]
                        }
                    },
                    'ForecastConfigurations': [
                        {
                            'ForecastProperties': {
                                'PeriodsForward': 12,  # 12週間先
                                'PeriodsBackward': 0,
                                'PredictionInterval': 95,
                                'Seasonality': 'AUTOMATIC'
                            }
                        }
                    ]
                }
            }
        }
    
    def setup_automated_insights(self, dataset_id: str) -> List[Dict[str, Any]]:
        """
        自動インサイト設定
        """
        # QuickSight Q（自然言語クエリ）設定
        topics = [
            {
                'TopicId': 'sales-topic',
                'TopicName': 'Sales Data',
                'Description': 'Sales and revenue analysis topic',
                'DataSets': [
                    {
                        'DataSetArn': f'arn:aws:quicksight:{self.region}:{self.account_id}:dataset/{dataset_id}',
                        'Name': 'Sales Dataset',
                        'DataSetDescription': 'Comprehensive sales data with orders, products, and customers',
                        'Filters': [],
                        'ColumnGroupings': [
                            {
                                'GroupingName': 'Date Dimensions',
                                'Columns': ['order_date', 'order_year', 'order_month', 'order_day']
                            },
                            {
                                'GroupingName': 'Customer Dimensions',
                                'Columns': ['user_id', 'first_name', 'last_name', 'email']
                            },
                            {
                                'GroupingName': 'Product Dimensions', 
                                'Columns': ['product_id', 'product_name', 'category']
                            },
                            {
                                'GroupingName': 'Financial Metrics',
                                'Columns': ['line_total', 'unit_price', 'quantity', 'total_amount']
                            }
                        ],
                        'NamedEntities': [
                            {
                                'EntityName': 'Revenue',
                                'EntityDescription': 'Total sales revenue',
                                'EntitySynonyms': ['Sales', 'Income', 'Earnings'],
                                'Definition': {
                                    'FieldName': 'line_total',
                                    'PropertyName': 'SUM'
                                }
                            },
                            {
                                'EntityName': 'Orders',
                                'EntityDescription': 'Number of orders',
                                'EntitySynonyms': ['Purchases', 'Transactions'],
                                'Definition': {
                                    'FieldName': 'order_id',
                                    'PropertyName': 'DISTINCT_COUNT'
                                }
                            }
                        ]
                    }
                ]
            }
        ]
        
        return topics
    
    def create_executive_summary_insights(self) -> List[str]:
        """
        エグゼクティブサマリー用インサイト例
        """
        insights = [
            "What is the total revenue this month?",
            "How does this month's revenue compare to last month?",
            "Which product category generated the most revenue?",
            "Who are the top 10 customers by revenue?",
            "What is the average order value?",
            "Show me the revenue trend for the last 12 months",
            "Which products have declining sales?",
            "What is the customer acquisition cost?",
            "Show me seasonal patterns in sales",
            "Identify any anomalies in daily revenue"
        ]
        
        return insights
```

## 検証方法

### 1. ダッシュボード機能テスト
```bash
# QuickSight APIを使用したテスト
aws quicksight describe-dashboard \
  --aws-account-id 123456789012 \
  --dashboard-id sales-executive-dashboard

# データセット更新確認
aws quicksight describe-data-set \
  --aws-account-id 123456789012 \
  --data-set-id sales-analytics-dataset

# SPICE取り込み状況確認
aws quicksight list-ingestions \
  --aws-account-id 123456789012 \
  --data-set-id sales-analytics-dataset
```

### 2. パフォーマンステスト
```python
# SPICE パフォーマンステスト
import time
import boto3

def test_spice_performance():
    quicksight = boto3.client('quicksight')
    
    # クエリ実行時間測定
    start_time = time.time()
    
    # 大量データクエリ実行
    response = quicksight.get_session_embed_url(
        AwsAccountId='123456789012',
        EntryPoint='https://ap-northeast-1.quicksight.aws.amazon.com/sn/dashboards/sales-executive-dashboard'
    )
    
    end_time = time.time()
    print(f"Query execution time: {end_time - start_time:.2f} seconds")

test_spice_performance()
```

### 3. アクセス制御テスト
```python
# ユーザー・グループ権限テスト
def test_dashboard_permissions():
    quicksight = boto3.client('quicksight')
    
    # ダッシュボード権限確認
    permissions = quicksight.describe_dashboard_permissions(
        AwsAccountId='123456789012',
        DashboardId='sales-executive-dashboard'
    )
    
    print("Dashboard permissions:", permissions['Permissions'])
    
    # グループ別アクセステスト
    for group in ['Executives', 'Analysts', 'Viewers']:
        try:
            user_access = quicksight.describe_group(
                AwsAccountId='123456789012',
                GroupName=group,
                Namespace='default'
            )
            print(f"Group {group} access confirmed")
        except Exception as e:
            print(f"Group {group} access denied: {e}")

test_dashboard_permissions()
```

## トラブルシューティング

### よくある問題と解決策

#### 1. SPICE容量制限
**症状**: データ取り込み時の容量エラー
**解決策**:
- データセットの最適化
- 不要なカラムの除外
- データフィルタリング

#### 2. 複雑なクエリのパフォーマンス
**症状**: ダッシュボード読み込み遅延
**解決策**:
```python
# クエリ最適化例
optimized_query = """
SELECT 
    DATE_TRUNC('month', order_date) as month,
    category,
    SUM(line_total) as revenue,
    COUNT(DISTINCT order_id) as order_count
FROM sales_data
WHERE order_date >= DATE('2024-01-01')
GROUP BY 1, 2
ORDER BY 1 DESC, 3 DESC
"""
```

#### 3. 権限設定問題
**症状**: データソースアクセス拒否
**解決策**:
- IAMロール権限の確認
- VPC接続設定の検証
- セキュリティグループ設定確認

## 学習リソース

### AWS公式ドキュメント
- [Amazon QuickSight User Guide](https://docs.aws.amazon.com/quicksight/latest/user/)
- [QuickSight API Reference](https://docs.aws.amazon.com/quicksight/latest/APIReference/)
- [QuickSight Embedded Analytics](https://docs.aws.amazon.com/quicksight/latest/user/embedded-analytics.html)

### 追加学習教材
- [QuickSight Workshop](https://quicksight-workshop.com/)
- [BI Best Practices Guide](https://aws.amazon.com/quicksight/resources/)

## セキュリティとコストの考慮事項

### セキュリティベストプラクティス
1. **アクセス制御**: 最小権限の原則
2. **データ暗号化**: 保存時・転送時暗号化
3. **VPC統合**: プライベートネットワーク接続
4. **監査ログ**: CloudTrail連携

### コスト最適化
1. **SPICE最適化**: 必要なデータのみ取り込み
2. **ユーザー管理**: 適切なライセンス選択
3. **自動更新**: 効率的な更新スケジュール
4. **リソース監視**: 使用量の継続的監視

### AWS Well-Architectedフレームワークとの関連
- **運用性の柱**: 自動化・監視・ダッシュボード管理
- **セキュリティの柱**: IAM・VPC・暗号化・監査
- **信頼性の柱**: Multi-AZ・バックアップ・フェイルオーバー
- **パフォーマンス効率の柱**: SPICE最適化・クエリ最適化
- **コスト最適化の柱**: ライセンス最適化・リソース効率化

## 次のステップ

### 推奨される学習パス
1. **4.2.2 CloudWatchメトリクス**: 運用監視強化
2. **5.1.1 Bedrockセットアップ**: AI機能統合
3. **6.1.1 マルチステージビルド**: CI/CD統合
4. **6.2.1 APM実装**: 高度な監視

### 発展的な機能
1. **Embedded Analytics**: アプリケーション統合
2. **Custom Visuals**: 独自ビジュアライゼーション
3. **Real-time Dashboards**: ストリーミング統合
4. **Advanced ML**: カスタム機械学習モデル

### 実践プロジェクトのアイデア
1. **リアルタイム売上ダッシュボード**: ストリーミングデータ統合
2. **顧客行動分析**: 高度なセグメンテーション
3. **サプライチェーン可視化**: 複数システム統合
4. **財務レポート自動化**: 規制対応レポート