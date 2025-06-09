# データ分析基盤編

## 概要

このセクションでは、AWSを使用したモダンなデータ分析基盤を構築します。リアルタイムデータ処理、ETLパイプライン、データ可視化まで、エンドツーエンドのデータプラットフォームを学習します。

## 学習目標

- 📊 **データ収集**: Kinesis、EventBridge、IoTによるリアルタイムデータ取得
- 🔄 **データ処理**: ETL/ELTパイプライン、Lambda、Glue
- 🗄️ **データ保存**: S3 Data Lake、Redshift、Athena
- 📈 **データ可視化**: QuickSight、CloudWatch、カスタムダッシュボード
- 🤖 **機械学習統合**: SageMaker、予測分析、異常検知

## アーキテクチャ概要

```
┌─────────────────────────────────────────────────────────────────┐
│                        Data Sources                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────┐ │
│  │ Web/Mobile  │  │     IoT     │  │ External    │  │  APIs   │ │
│  │    Apps     │  │   Devices   │  │    APIs     │  │         │ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Data Ingestion                               │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────┐ │
│  │   Kinesis   │  │ EventBridge │  │   Lambda    │  │   SQS   │ │
│  │  Streams    │  │   Events    │  │  Functions  │  │ Queues  │ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Data Processing                               │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────┐ │
│  │    Glue     │  │   Lambda    │  │     EMR     │  │  Step   │ │
│  │  ETL Jobs   │  │ Processing  │  │   Clusters  │  │Function │ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Data Storage                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────┐ │
│  │   S3 Data   │  │  Redshift   │  │  DynamoDB   │  │ RDS     │ │
│  │    Lake     │  │    DWH      │  │   NoSQL     │  │   DB    │ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                 Analytics & Visualization                       │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────┐ │
│  │  QuickSight │  │   Athena    │  │ CloudWatch  │  │ Custom  │ │
│  │ Dashboards  │  │   Queries   │  │  Metrics    │  │   UIs   │ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## 学習パス

### 4.1 データ収集と保存
- **4.1.1** Kinesisストリーミング
- **4.1.2** ETLパイプライン（Glue）

### 4.2 可視化と分析
- **4.2.1** QuickSightダッシュボード
- **4.2.2** CloudWatchメトリクス

### 4.3 高度な分析（拡張）
- **4.3.1** Athenaクエリエンジン
- **4.3.2** SageMaker機械学習統合

## クイックスタート

### 前提条件

```bash
# AWS CLI確認
aws --version

# Python環境確認（データ処理用）
python3 --version
pip3 --version

# Node.js確認（Lambda関数用）
node --version
npm --version
```

### 全体デプロイ

```bash
# データ分析基盤の一括デプロイ
./scripts/deploy-all-infrastructure.sh deploy-data

# 段階的デプロイ
./scripts/deploy-data-platform.sh deploy-ingestion
./scripts/deploy-data-platform.sh deploy-processing
./scripts/deploy-data-platform.sh deploy-analytics
```

## 学習コンテンツ詳細

### 📊 4.1.1 Kinesisストリーミング

**学習内容:**
- リアルタイムデータストリーミング
- Kinesis Data Streams設計
- Kinesis Analytics でのリアルタイム分析
- 並列処理とスケーリング戦略

**実装内容:**
- Kinesis Data Streams構築
- Lambda コンシューマー実装
- Kinesis Analytics アプリケーション
- CloudWatch監視設定

**主要技術:**
- Amazon Kinesis Data Streams
- Amazon Kinesis Analytics
- AWS Lambda
- Amazon CloudWatch

### 🔄 4.1.2 ETLパイプライン

**学習内容:**
- データ変換処理の設計
- AWS Glue によるサーバーレス ETL
- データカタログ管理
- スケジューリングと依存関係管理

**実装内容:**
- Glue ETL ジョブ実装
- Glue Data Catalog 設定
- Step Functions ワークフロー
- 品質チェックとエラーハンドリング

**主要技術:**
- AWS Glue
- AWS Step Functions
- Amazon S3
- AWS Lambda

### 📈 4.2.1 QuickSightダッシュボード

**学習内容:**
- ビジネスインテリジェンス設計
- インタラクティブダッシュボード作成
- データセット設計と最適化
- 組み込み分析とセキュリティ

**実装内容:**
- QuickSight データセット作成
- ダッシュボード設計と実装
- 自動レポート生成
- 埋め込み分析機能

**主要技術:**
- Amazon QuickSight
- Amazon Athena
- Amazon Redshift
- S3 Data Lake

### 📊 4.2.2 CloudWatchメトリクス

**学習内容:**
- カスタムメトリクス設計
- アラートとダッシュボード
- ログ分析とインサイト
- コスト監視と最適化

**実装内容:**
- カスタムメトリクス実装
- CloudWatch ダッシュボード作成
- アラームとSNS通知
- ログ集約と分析

**主要技術:**
- Amazon CloudWatch
- CloudWatch Logs
- Amazon SNS
- AWS X-Ray

## 🏗️ 実装手順

### Step 1: データ収集層の構築

```bash
# Kinesisストリーム作成
aws kinesis create-stream \
  --stream-name data-ingestion-stream \
  --shard-count 2

# データ生成Lambda関数デプロイ
cd 04-データ分析基盤編/4.1-データ収集と保存/4.1.1-Kinesisストリーミング
aws cloudformation create-stack \
  --stack-name data-ingestion \
  --template-body file://cloudformation/kinesis-streaming.yaml \
  --capabilities CAPABILITY_IAM
```

### Step 2: データ処理層の構築

```bash
# Glue ETLジョブの設定
aws glue create-job \
  --name data-transformation-job \
  --role GlueServiceRole \
  --command ScriptLocation=s3://my-bucket/etl-script.py

# Step Functions ワークフロー作成
aws stepfunctions create-state-machine \
  --name data-processing-workflow \
  --definition file://step-functions-definition.json
```

### Step 3: データ保存層の構築

```bash
# S3 Data Lake バケット作成
aws s3 mb s3://my-data-lake-bucket
aws s3api put-bucket-encryption \
  --bucket my-data-lake-bucket \
  --server-side-encryption-configuration file://encryption-config.json

# Athena データベース作成
aws athena start-query-execution \
  --query-string "CREATE DATABASE analytics_db"
```

### Step 4: 分析・可視化層の構築

```bash
# QuickSight データセット作成
aws quicksight create-data-set \
  --aws-account-id 123456789012 \
  --data-set-id my-dataset \
  --name "Analytics Dataset"

# CloudWatch カスタムダッシュボード作成
aws cloudwatch put-dashboard \
  --dashboard-name "DataPlatformDashboard" \
  --dashboard-body file://dashboard-config.json
```

## 💾 データモデリング

### データレイク設計

```
s3://my-data-lake/
├── raw/                    # 生データ
│   ├── year=2024/
│   │   ├── month=01/
│   │   │   ├── day=15/
│   │   │   │   └── events/
│   └── source=app/
├── processed/              # 処理済みデータ
│   ├── aggregated/
│   ├── cleaned/
│   └── enriched/
└── curated/               # キュレーション済み
    ├── analytics/
    ├── ml/
    └── reporting/
```

### パーティション戦略

```sql
-- Athena テーブル作成例
CREATE TABLE events (
  event_id string,
  user_id string,
  event_type string,
  timestamp timestamp,
  properties map<string,string>
)
PARTITIONED BY (
  year int,
  month int,
  day int,
  source string
)
STORED AS PARQUET
LOCATION 's3://my-data-lake/processed/events/'
```

## 🧪 データ品質管理

### データバリデーション

```python
# Glue ETL スクリプト例
import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job

args = getResolvedOptions(sys.argv, ['JOB_NAME'])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

# データ品質チェック
def validate_data(df):
    # NULL値チェック
    null_count = df.filter(df.user_id.isNull()).count()
    if null_count > 0:
        raise ValueError(f"NULL values found: {null_count}")
    
    # データ型チェック
    numeric_columns = ['amount', 'quantity']
    for col in numeric_columns:
        if df.filter(~df[col].cast('double').isNotNull()).count() > 0:
            raise ValueError(f"Invalid numeric values in {col}")
    
    return True

# ETL処理
datasource = glueContext.create_dynamic_frame.from_catalog(
    database="analytics_db",
    table_name="raw_events"
)

# データクリーニング
df = datasource.toDF()
validate_data(df)  # 品質チェック

# 変換処理
transformed_df = df.filter(df.event_type != 'test') \
                  .withColumn('processed_at', current_timestamp())

# 出力
output_frame = DynamicFrame.fromDF(transformed_df, glueContext, "output")
glueContext.write_dynamic_frame.from_options(
    frame=output_frame,
    connection_type="s3",
    connection_options={
        "path": "s3://my-data-lake/processed/events/",
        "partitionKeys": ["year", "month", "day"]
    },
    format="parquet"
)

job.commit()
```

## 📊 パフォーマンス最適化

### Kinesis 最適化

```yaml
# Kinesis設定例
KinesisStream:
  ShardCount: !Ref ShardCount  # 書き込み速度に応じて調整
  RetentionPeriod: 168         # 7日間保持
  ShardLevelMetrics:
    - IncomingRecords
    - OutgoingRecords
```

### Athena 最適化

```sql
-- パーティション射影を使用した高速クエリ
CREATE TABLE optimized_events (
  event_id string,
  user_id string,
  event_type string,
  properties string
)
PARTITIONED BY (
  year int,
  month int,
  day int
)
STORED AS PARQUET
LOCATION 's3://my-data-lake/optimized/events/'
TBLPROPERTIES (
  'projection.enabled'='true',
  'projection.year.type'='integer',
  'projection.year.range'='2020,2030',
  'projection.month.type'='integer',
  'projection.month.range'='1,12',
  'projection.day.type'='integer',
  'projection.day.range'='1,31',
  'storage.location.template'='s3://my-data-lake/optimized/events/year=${year}/month=${month}/day=${day}/'
);
```

## 🔍 監視とアラート

### データパイプライン監視

```bash
# CloudWatch カスタムメトリクス送信
aws cloudwatch put-metric-data \
  --namespace "DataPipeline" \
  --metric-data MetricName=ProcessedRecords,Value=1000,Unit=Count

# データ品質アラート
aws cloudwatch put-metric-alarm \
  --alarm-name "DataQualityFailure" \
  --alarm-description "Data quality check failed" \
  --metric-name "QualityCheckFailures" \
  --namespace "DataPipeline" \
  --statistic "Sum" \
  --period 300 \
  --threshold 1 \
  --comparison-operator "GreaterThanOrEqualToThreshold"
```

### コスト監視

```python
# Lambda関数でコスト監視
import boto3
import json

def lambda_handler(event, context):
    ce = boto3.client('ce')
    
    # S3ストレージコスト取得
    response = ce.get_cost_and_usage(
        TimePeriod={
            'Start': '2024-01-01',
            'End': '2024-01-31'
        },
        Granularity='MONTHLY',
        Metrics=['BlendedCost'],
        GroupBy=[
            {
                'Type': 'DIMENSION',
                'Key': 'SERVICE'
            }
        ]
    )
    
    # コストアラート
    for group in response['ResultsByTime'][0]['Groups']:
        service = group['Keys'][0]
        cost = float(group['Metrics']['BlendedCost']['Amount'])
        
        if service == 'Amazon Simple Storage Service' and cost > 1000:
            sns = boto3.client('sns')
            sns.publish(
                TopicArn='arn:aws:sns:us-east-1:123456789012:cost-alerts',
                Message=f'S3 cost exceeded $1000: ${cost:.2f}',
                Subject='High S3 Cost Alert'
            )
    
    return {'statusCode': 200}
```

## 🛠️ トラブルシューティング

### よくある問題と解決方法

#### 1. Kinesis スロットリング

```python
# 指数バックオフリトライ
import time
import random

def put_record_with_retry(kinesis_client, stream_name, data, partition_key, max_retries=3):
    for attempt in range(max_retries):
        try:
            response = kinesis_client.put_record(
                StreamName=stream_name,
                Data=data,
                PartitionKey=partition_key
            )
            return response
        except kinesis_client.exceptions.ProvisionedThroughputExceededException:
            if attempt < max_retries - 1:
                sleep_time = (2 ** attempt) + random.uniform(0, 1)
                time.sleep(sleep_time)
            else:
                raise
```

#### 2. Glue ETL メモリエラー

```python
# データフレームの最適化
def optimize_dataframe(df):
    # カラムのデータ型最適化
    for col in df.columns:
        if df[col].dtype == 'object':
            try:
                df[col] = pd.to_numeric(df[col], downcast='integer')
            except:
                pass
    
    # 不要カラムの削除
    df = df.drop(['temp_column'], axis=1, errors='ignore')
    
    return df
```

#### 3. Athena クエリタイムアウト

```sql
-- クエリ最適化のベストプラクティス
-- 1. パーティション射映の使用
-- 2. カラムナーフォーマット（Parquet）の使用
-- 3. 適切なデータ型の選択

-- 効率的なクエリ例
SELECT 
    event_type,
    COUNT(*) as event_count
FROM events
WHERE year = 2024 
    AND month = 1 
    AND day BETWEEN 1 AND 7
GROUP BY event_type
LIMIT 1000;
```

## 💰 コスト最適化

### S3 ストレージ最適化

```yaml
# ライフサイクルポリシー
LifecycleConfiguration:
  Rules:
    - Id: DataArchiving
      Status: Enabled
      Transitions:
        - Days: 30
          StorageClass: STANDARD_IA
        - Days: 90
          StorageClass: GLACIER
        - Days: 365
          StorageClass: DEEP_ARCHIVE
      ExpirationInDays: 2555  # 7年後削除
```

### Kinesis コスト最適化

```bash
# オンデマンドモード（推奨）
aws kinesis put-record \
  --stream-name my-stream \
  --data "sample data" \
  --partition-key "key1"

# シャード数動的調整
aws application-autoscaling register-scalable-target \
  --service-namespace kinesis \
  --resource-id stream/my-stream \
  --scalable-dimension kinesis:stream:shard-count
```

## 📚 参考資料

### AWS ドキュメント
- [Big Data Analytics Options on AWS](https://aws.amazon.com/big-data/analytics-options/)
- [Data Lake Implementation Guide](https://aws.amazon.com/solutions/implementations/data-lake-solution/)
- [Analytics Lens - Well-Architected Framework](https://docs.aws.amazon.com/wellarchitected/latest/analytics-lens/)

### データエンジニアリング
- [The Data Engineering Handbook](https://github.com/DataExpert-io/data-engineer-handbook)
- [Apache Parquet Best Practices](https://parquet.apache.org/docs/)
- [Data Modeling for Analytics](https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/)

## 📈 次のステップ

完了後は以下に進んでください：

1. **[AI-ML統合編](../05-AI-ML統合編/README.md)** - 機械学習パイプライン
2. **[CI-CD高度化編](../06-CI-CD高度化編/README.md)** - 自動化パイプライン
3. **[Claude Code & Bedrock編](../07-Claude-Code-Bedrock-AI駆動開発編/README.md)** - AI駆動開発

---

## 🎯 学習チェックリスト

### データ収集
- [ ] Kinesis Data Streams設定
- [ ] リアルタイムデータ処理
- [ ] イベント駆動アーキテクチャ
- [ ] データ取り込みパイプライン

### データ処理
- [ ] Glue ETL ジョブ設計
- [ ] データ変換とクリーニング
- [ ] 品質チェック実装
- [ ] ワークフロー管理

### データ保存
- [ ] Data Lake 設計
- [ ] パーティション戦略
- [ ] データカタログ管理
- [ ] セキュリティ設定

### 分析・可視化
- [ ] QuickSight ダッシュボード作成
- [ ] Athena クエリ最適化
- [ ] カスタムメトリクス実装
- [ ] アラート設定

**準備ができたら次のセクションへ進みましょう！**