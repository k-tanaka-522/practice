#!/usr/bin/env python3
"""
エンタープライズETLジョブスクリプト
AWS Glue用の高度なデータ処理パイプライン
"""

import sys
import json
import boto3
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional
from pyspark.context import SparkContext
from pyspark.sql import DataFrame, SparkSession
from pyspark.sql import functions as F
from pyspark.sql.types import *
from pyspark.sql.window import Window
import pyspark.sql.utils

# AWS Glue imports
try:
    from awsglue.transforms import *
    from awsglue.utils import getResolvedOptions
    from awsglue.context import GlueContext
    from awsglue.job import Job
    from awsglue.dynamicframe import DynamicFrame
except ImportError:
    # ローカル開発環境用のモック
    print("AWS Glue libraries not available - using mock imports")

# ログ設定
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class EnterpriseETLJob:
    """エンタープライズETLジョブクラス"""
    
    def __init__(self, job_args: Dict[str, str]):
        """
        ETLジョブの初期化
        
        Args:
            job_args: Glueジョブ引数
        """
        self.args = job_args
        
        # Spark/Glue コンテキスト初期化
        self.sc = SparkContext()
        self.glueContext = GlueContext(self.sc)
        self.spark = self.glueContext.spark_session
        self.job = Job(self.glueContext)
        
        # ジョブ初期化
        self.job.init(self.args['JOB_NAME'], self.args)
        
        # AWS クライアント
        self.s3 = boto3.client('s3')
        self.sns = boto3.client('sns')
        self.cloudwatch = boto3.client('cloudwatch')
        
        # 設定
        self.raw_bucket = self.args['raw_bucket']
        self.processed_bucket = self.args['processed_bucket']
        self.curated_bucket = self.args['curated_bucket']
        self.database_name = self.args['database_name']
        self.notification_topic = self.args.get('notification_topic_arn')
        
        # データ品質閾値
        self.quality_thresholds = {
            'completeness': 0.95,
            'uniqueness': 0.99,
            'validity': 0.98,
            'consistency': 0.95
        }
        
        logger.info(f"ETL Job initialized: {self.args['JOB_NAME']}")
    
    def run(self):
        """メインETL実行フロー"""
        try:
            execution_start = datetime.now()
            logger.info("Starting ETL pipeline execution")
            
            # Phase 1: データ抽出とバリデーション
            raw_data = self.extract_data()
            logger.info(f"Data extraction completed: {raw_data.count()} records")
            
            # Phase 2: データ品質チェック
            quality_results = self.validate_data_quality(raw_data)
            if not quality_results['passed']:
                raise Exception(f"Data quality validation failed: {quality_results}")
            
            # Phase 3: データクレンジング
            clean_data = self.cleanse_data(raw_data)
            logger.info(f"Data cleansing completed: {clean_data.count()} records")
            
            # Phase 4: データ変換・エンリッチメント
            transformed_data = self.transform_data(clean_data)
            logger.info(f"Data transformation completed: {transformed_data.count()} records")
            
            # Phase 5: ビジネスルール適用
            business_data = self.apply_business_rules(transformed_data)
            logger.info(f"Business rules applied: {business_data.count()} records")
            
            # Phase 6: データ集約
            aggregated_data = self.aggregate_data(business_data)
            logger.info("Data aggregation completed")
            
            # Phase 7: データ書き込み
            self.load_processed_data(business_data)
            self.load_curated_data(aggregated_data)
            logger.info("Data loading completed")
            
            # Phase 8: メタデータ更新
            self.update_metadata()
            
            # Phase 9: 実行レポート生成
            execution_time = (datetime.now() - execution_start).total_seconds()
            report = self.generate_execution_report(
                records_processed=raw_data.count(),
                quality_results=quality_results,
                execution_time=execution_time
            )
            
            # 成功通知
            self.send_notification("SUCCESS", report)
            logger.info(f"ETL pipeline completed successfully in {execution_time:.2f} seconds")
            
        except Exception as e:
            error_msg = f"ETL pipeline failed: {str(e)}"
            logger.error(error_msg)
            self.send_notification("FAILED", {"error": error_msg})
            raise
        
        finally:
            # ジョブのコミット
            self.job.commit()
    
    def extract_data(self) -> DataFrame:
        """データ抽出"""
        logger.info("Starting data extraction phase")
        
        # パーティション日付の決定
        partition_date = self.args.get('partition_date', 
                                     (datetime.now() - timedelta(days=1)).strftime('%Y-%m-%d'))
        
        # 複数ソースからのデータ読み込み
        input_paths = [
            f"s3://{self.raw_bucket}/user_activity/year={partition_date[:4]}/month={partition_date[5:7]}/day={partition_date[8:10]}/",
            f"s3://{self.raw_bucket}/transactions/year={partition_date[:4]}/month={partition_date[5:7]}/day={partition_date[8:10]}/",
            f"s3://{self.raw_bucket}/system_metrics/year={partition_date[:4]}/month={partition_date[5:7]}/day={partition_date[8:10]}/"
        ]
        
        all_data = []
        
        for path in input_paths:
            try:
                # ファイル存在確認
                if self._path_exists(path):
                    df = self.spark.read.option("multiline", "true").json(path)
                    
                    # データソース情報を追加
                    source_name = path.split('/')[-4]  # ディレクトリ名を取得
                    df = df.withColumn("source_dataset", F.lit(source_name))
                    df = df.withColumn("ingestion_timestamp", F.current_timestamp())
                    
                    all_data.append(df)
                    logger.info(f"Loaded data from {path}: {df.count()} records")
                else:
                    logger.warning(f"Path does not exist: {path}")
            
            except Exception as e:
                logger.error(f"Failed to load data from {path}: {e}")
                continue
        
        if not all_data:
            raise Exception("No data found for processing")
        
        # データ統合
        combined_df = all_data[0]
        for df in all_data[1:]:
            combined_df = combined_df.unionByName(df, allowMissingColumns=True)
        
        return combined_df
    
    def validate_data_quality(self, df: DataFrame) -> Dict[str, Any]:
        """データ品質検証"""
        logger.info("Starting data quality validation")
        
        total_records = df.count()
        quality_checks = {}
        
        # 完全性チェック（必須フィールドのNULL率）
        required_fields = ['timestamp', 'event_type']
        completeness_scores = {}
        
        for field in required_fields:
            if field in df.columns:
                null_count = df.filter(F.col(field).isNull()).count()
                completeness = 1 - (null_count / total_records) if total_records > 0 else 0
                completeness_scores[field] = completeness
            else:
                completeness_scores[field] = 0
        
        overall_completeness = sum(completeness_scores.values()) / len(completeness_scores)
        quality_checks['completeness'] = {
            'score': overall_completeness,
            'threshold': self.quality_thresholds['completeness'],
            'passed': overall_completeness >= self.quality_thresholds['completeness']
        }
        
        # 一意性チェック（重複率）
        if 'event_id' in df.columns:
            unique_count = df.select('event_id').distinct().count()
            uniqueness = unique_count / total_records if total_records > 0 else 0
            quality_checks['uniqueness'] = {
                'score': uniqueness,
                'threshold': self.quality_thresholds['uniqueness'],
                'passed': uniqueness >= self.quality_thresholds['uniqueness']
            }
        
        # 妥当性チェック（データ形式）
        validity_checks = []
        
        # タイムスタンプ妥当性
        if 'timestamp' in df.columns:
            valid_timestamps = df.filter(
                F.col('timestamp').rlike(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}')
            ).count()
            timestamp_validity = valid_timestamps / total_records if total_records > 0 else 0
            validity_checks.append(timestamp_validity)
        
        # 数値フィールド妥当性
        numeric_fields = ['amount', 'quantity', 'price']
        for field in numeric_fields:
            if field in df.columns:
                valid_numeric = df.filter(
                    F.col(field).isNotNull() & 
                    (F.col(field) >= 0)
                ).count()
                numeric_validity = valid_numeric / total_records if total_records > 0 else 1
                validity_checks.append(numeric_validity)
        
        overall_validity = sum(validity_checks) / len(validity_checks) if validity_checks else 1
        quality_checks['validity'] = {
            'score': overall_validity,
            'threshold': self.quality_thresholds['validity'],
            'passed': overall_validity >= self.quality_thresholds['validity']
        }
        
        # 全体品質スコア計算
        overall_passed = all(check['passed'] for check in quality_checks.values())
        
        result = {
            'total_records': total_records,
            'checks': quality_checks,
            'passed': overall_passed,
            'overall_score': sum(check['score'] for check in quality_checks.values()) / len(quality_checks)
        }
        
        # 品質メトリクスをCloudWatchに送信
        self._send_quality_metrics(result)
        
        logger.info(f"Data quality validation completed: Overall score = {result['overall_score']:.3f}")
        return result
    
    def cleanse_data(self, df: DataFrame) -> DataFrame:
        """データクレンジング"""
        logger.info("Starting data cleansing phase")
        
        # 1. NULL値処理
        df_clean = df.na.drop(subset=['timestamp', 'event_type'])
        
        # 2. 重複除去
        if 'event_id' in df.columns:
            df_clean = df_clean.dropDuplicates(['event_id'])
        
        # 3. データ型正規化
        if 'timestamp' in df.columns:
            df_clean = df_clean.withColumn(
                'timestamp_normalized',
                F.to_timestamp('timestamp', 'yyyy-MM-dd\'T\'HH:mm:ss')
            )
        
        # 4. 異常値除去
        numeric_fields = ['amount', 'quantity', 'price']
        for field in numeric_fields:
            if field in df.columns:
                # 99.9パーセンタイルを上限として異常値を除去
                quantiles = df.select(F.expr(f'percentile_approx({field}, 0.999)')).collect()[0][0]
                if quantiles:
                    df_clean = df_clean.filter(F.col(field) <= quantiles)
        
        # 5. 文字列正規化
        string_fields = ['event_type', 'category', 'product_name']
        for field in string_fields:
            if field in df.columns:
                df_clean = df_clean.withColumn(
                    field,
                    F.trim(F.lower(F.col(field)))
                )
        
        logger.info(f"Data cleansing completed: {df_clean.count()} records retained")
        return df_clean
    
    def transform_data(self, df: DataFrame) -> DataFrame:
        """データ変換・エンリッチメント"""
        logger.info("Starting data transformation phase")
        
        # 1. 時間次元の拡張
        if 'timestamp_normalized' in df.columns:
            df = df.withColumn('year', F.year('timestamp_normalized')) \
                   .withColumn('month', F.month('timestamp_normalized')) \
                   .withColumn('day', F.dayofmonth('timestamp_normalized')) \
                   .withColumn('hour', F.hour('timestamp_normalized')) \
                   .withColumn('day_of_week', F.dayofweek('timestamp_normalized')) \
                   .withColumn('quarter', F.quarter('timestamp_normalized'))
        
        # 2. ビジネス計算フィールド
        if 'amount' in df.columns and 'quantity' in df.columns:
            df = df.withColumn('unit_price', F.col('amount') / F.col('quantity'))
        
        # 3. カテゴリ階層分解
        if 'category' in df.columns:
            df = df.withColumn('main_category', F.split(F.col('category'), ' > ').getItem(0)) \
                   .withColumn('sub_category', F.split(F.col('category'), ' > ').getItem(1))
        
        # 4. 地理的エンリッチメント（郵便番号→地域）
        if 'postal_code' in df.columns:
            df = df.withColumn('region', self._map_postal_to_region('postal_code'))
        
        # 5. セッション分析
        if 'user_id' in df.columns and 'timestamp_normalized' in df.columns:
            # セッション区切り（30分以上の間隔で新セッション）
            window_spec = Window.partitionBy('user_id').orderBy('timestamp_normalized')
            
            df = df.withColumn(
                'prev_timestamp',
                F.lag('timestamp_normalized', 1).over(window_spec)
            ).withColumn(
                'time_diff_minutes',
                (F.col('timestamp_normalized').cast('long') - 
                 F.col('prev_timestamp').cast('long')) / 60
            ).withColumn(
                'is_new_session',
                F.when(F.col('time_diff_minutes') > 30, 1).otherwise(0)
            ).withColumn(
                'session_id',
                F.sum('is_new_session').over(window_spec.rowsBetween(Window.unboundedPreceding, 0))
            )
        
        # 6. 顧客セグメンテーション
        if 'user_id' in df.columns:
            df = self._add_customer_segmentation(df)
        
        logger.info("Data transformation completed")
        return df
    
    def apply_business_rules(self, df: DataFrame) -> DataFrame:
        """ビジネスルール適用"""
        logger.info("Applying business rules")
        
        # 1. 購入金額による顧客ランク設定
        if 'amount' in df.columns and 'user_id' in df.columns:
            # ユーザー別累計購入金額計算
            user_totals = df.filter(F.col('event_type') == 'purchase') \
                           .groupBy('user_id') \
                           .agg(F.sum('amount').alias('total_purchase_amount'),
                                F.count('*').alias('purchase_count'))
            
            # 顧客ランク決定
            user_totals = user_totals.withColumn(
                'customer_rank',
                F.when(F.col('total_purchase_amount') >= 100000, 'platinum')
                 .when(F.col('total_purchase_amount') >= 50000, 'gold')
                 .when(F.col('total_purchase_amount') >= 10000, 'silver')
                 .otherwise('bronze')
            )
            
            # メインデータにランク情報をjoin
            df = df.join(user_totals.select('user_id', 'customer_rank'), 'user_id', 'left')
        
        # 2. 商品推奨スコア計算
        if 'product_id' in df.columns and 'user_id' in df.columns:
            # 商品人気度計算
            product_popularity = df.filter(F.col('event_type').isin(['view', 'purchase'])) \
                                  .groupBy('product_id') \
                                  .agg((F.count('*') * 0.7 + 
                                       F.sum(F.when(F.col('event_type') == 'purchase', 1).otherwise(0)) * 0.3)
                                       .alias('popularity_score'))
            
            df = df.join(product_popularity, 'product_id', 'left')
        
        # 3. 異常検知フラグ
        if 'amount' in df.columns:
            # 統計的異常値検出
            stats = df.filter(F.col('amount').isNotNull()) \
                     .select(F.mean('amount').alias('mean_amount'),
                             F.stddev('amount').alias('stddev_amount')) \
                     .collect()[0]
            
            if stats['stddev_amount']:
                threshold = stats['mean_amount'] + (3 * stats['stddev_amount'])
                df = df.withColumn(
                    'is_anomaly',
                    F.when(F.col('amount') > threshold, True).otherwise(False)
                )
        
        logger.info("Business rules application completed")
        return df
    
    def aggregate_data(self, df: DataFrame) -> Dict[str, DataFrame]:
        """データ集約"""
        logger.info("Starting data aggregation")
        
        aggregations = {}
        
        # 1. 時間別集約
        if 'timestamp_normalized' in df.columns:
            hourly_agg = df.groupBy('year', 'month', 'day', 'hour') \
                          .agg(F.count('*').alias('total_events'),
                               F.countDistinct('user_id').alias('unique_users'),
                               F.sum(F.when(F.col('event_type') == 'purchase', 1).otherwise(0)).alias('purchases'),
                               F.sum(F.when(F.col('event_type') == 'purchase', F.col('amount')).otherwise(0)).alias('revenue'))
            
            aggregations['hourly_metrics'] = hourly_agg
        
        # 2. 顧客別集約
        if 'user_id' in df.columns:
            customer_agg = df.groupBy('user_id') \
                            .agg(F.count('*').alias('total_events'),
                                 F.countDistinct('session_id').alias('total_sessions'),
                                 F.sum(F.when(F.col('event_type') == 'purchase', F.col('amount')).otherwise(0)).alias('total_spent'),
                                 F.first('customer_rank').alias('customer_rank'),
                                 F.max('timestamp_normalized').alias('last_activity'))
            
            aggregations['customer_summary'] = customer_agg
        
        # 3. 商品別集約
        if 'product_id' in df.columns:
            product_agg = df.filter(F.col('event_type').isin(['view', 'purchase'])) \
                           .groupBy('product_id', 'main_category') \
                           .agg(F.count('*').alias('total_interactions'),
                                F.sum(F.when(F.col('event_type') == 'purchase', 1).otherwise(0)).alias('purchases'),
                                F.sum(F.when(F.col('event_type') == 'purchase', F.col('amount')).otherwise(0)).alias('revenue'),
                                F.avg('popularity_score').alias('avg_popularity'))
            
            aggregations['product_summary'] = product_agg
        
        logger.info(f"Data aggregation completed: {len(aggregations)} aggregation tables created")
        return aggregations
    
    def load_processed_data(self, df: DataFrame):
        """処理済みデータの書き込み"""
        logger.info("Loading processed data")
        
        # パーティション列の準備
        if 'year' in df.columns and 'month' in df.columns and 'day' in df.columns:
            partition_cols = ['year', 'month', 'day']
        else:
            # フォールバック：現在日付でパーティション
            current_date = datetime.now()
            df = df.withColumn('year', F.lit(current_date.year)) \
                   .withColumn('month', F.lit(current_date.month)) \
                   .withColumn('day', F.lit(current_date.day))
            partition_cols = ['year', 'month', 'day']
        
        # Parquet形式で書き込み
        output_path = f"s3://{self.processed_bucket}/processed_events/"
        
        df.write \
          .mode('overwrite') \
          .option('compression', 'snappy') \
          .partitionBy(*partition_cols) \
          .parquet(output_path)
        
        logger.info(f"Processed data written to {output_path}")
    
    def load_curated_data(self, aggregations: Dict[str, DataFrame]):
        """キュレーションデータの書き込み"""
        logger.info("Loading curated data")
        
        base_path = f"s3://{self.curated_bucket}/"
        
        for table_name, df in aggregations.items():
            output_path = f"{base_path}{table_name}/"
            
            df.write \
              .mode('overwrite') \
              .option('compression', 'snappy') \
              .parquet(output_path)
            
            logger.info(f"Curated table '{table_name}' written to {output_path}")
    
    def update_metadata(self):
        """メタデータ更新"""
        logger.info("Updating metadata in Glue Data Catalog")
        
        try:
            # Glue Crawlerを実行してメタデータを更新
            glue_client = boto3.client('glue')
            
            crawlers = [
                f"{self.database_name}-processed-crawler",
                f"{self.database_name}-curated-crawler"
            ]
            
            for crawler_name in crawlers:
                try:
                    glue_client.start_crawler(Name=crawler_name)
                    logger.info(f"Started crawler: {crawler_name}")
                except Exception as e:
                    logger.warning(f"Failed to start crawler {crawler_name}: {e}")
        
        except Exception as e:
            logger.error(f"Metadata update failed: {e}")
    
    def generate_execution_report(self, records_processed: int, 
                                quality_results: Dict, execution_time: float) -> Dict:
        """実行レポート生成"""
        return {
            'job_name': self.args['JOB_NAME'],
            'execution_timestamp': datetime.now().isoformat(),
            'records_processed': records_processed,
            'execution_time_seconds': execution_time,
            'data_quality_score': quality_results['overall_score'],
            'quality_checks_passed': quality_results['passed'],
            'buckets': {
                'raw': self.raw_bucket,
                'processed': self.processed_bucket,
                'curated': self.curated_bucket
            }
        }
    
    def send_notification(self, status: str, details: Dict):
        """通知送信"""
        if not self.notification_topic:
            return
        
        try:
            message = {
                'status': status,
                'job_name': self.args['JOB_NAME'],
                'timestamp': datetime.now().isoformat(),
                'details': details
            }
            
            self.sns.publish(
                TopicArn=self.notification_topic,
                Message=json.dumps(message, indent=2),
                Subject=f"ETL Job {status}: {self.args['JOB_NAME']}"
            )
            
            logger.info(f"Notification sent: {status}")
        
        except Exception as e:
            logger.error(f"Failed to send notification: {e}")
    
    # ヘルパーメソッド
    def _path_exists(self, s3_path: str) -> bool:
        """S3パス存在確認"""
        try:
            bucket, key = s3_path.replace('s3://', '').split('/', 1)
            response = self.s3.list_objects_v2(Bucket=bucket, Prefix=key, MaxKeys=1)
            return 'Contents' in response
        except Exception:
            return False
    
    def _map_postal_to_region(self, postal_col: str) -> F.col:
        """郵便番号→地域マッピング"""
        return F.when(F.col(postal_col).substr(1, 1).isin(['0', '1']), '北海道・東北') \
                .when(F.col(postal_col).substr(1, 1).isin(['2', '3']), '関東') \
                .when(F.col(postal_col).substr(1, 1).isin(['4', '9']), '中部') \
                .when(F.col(postal_col).substr(1, 1).isin(['5', '6']), '関西') \
                .when(F.col(postal_col).substr(1, 1).isin(['7', '8']), '中国・四国・九州') \
                .otherwise('その他')
    
    def _add_customer_segmentation(self, df: DataFrame) -> DataFrame:
        """顧客セグメンテーション追加"""
        # RFM分析に基づくセグメンテーション
        current_date = F.current_date()
        
        # 最近性（Recency）
        user_recency = df.filter(F.col('event_type') == 'purchase') \
                        .groupBy('user_id') \
                        .agg(F.max('timestamp_normalized').alias('last_purchase_date'))
        
        user_recency = user_recency.withColumn(
            'recency_days',
            F.datediff(current_date, F.col('last_purchase_date'))
        ).withColumn(
            'recency_score',
            F.when(F.col('recency_days') <= 30, 5)
             .when(F.col('recency_days') <= 90, 4)
             .when(F.col('recency_days') <= 180, 3)
             .when(F.col('recency_days') <= 365, 2)
             .otherwise(1)
        )
        
        return df.join(user_recency.select('user_id', 'recency_score'), 'user_id', 'left')
    
    def _send_quality_metrics(self, quality_results: Dict):
        """品質メトリクスをCloudWatchに送信"""
        try:
            metric_data = []
            
            for check_name, check_result in quality_results['checks'].items():
                metric_data.append({
                    'MetricName': f'DataQuality_{check_name.title()}',
                    'Value': check_result['score'],
                    'Unit': 'Percent',
                    'Dimensions': [
                        {'Name': 'JobName', 'Value': self.args['JOB_NAME']},
                        {'Name': 'Database', 'Value': self.database_name}
                    ]
                })
            
            # 全体品質スコア
            metric_data.append({
                'MetricName': 'DataQuality_Overall',
                'Value': quality_results['overall_score'],
                'Unit': 'Percent',
                'Dimensions': [
                    {'Name': 'JobName', 'Value': self.args['JOB_NAME']},
                    {'Name': 'Database', 'Value': self.database_name}
                ]
            })
            
            self.cloudwatch.put_metric_data(
                Namespace='ETL/DataQuality',
                MetricData=metric_data
            )
            
        except Exception as e:
            logger.error(f"Failed to send quality metrics: {e}")

def main():
    """メインエントリポイント"""
    # Glueジョブ引数の取得
    required_args = [
        'JOB_NAME', 'raw_bucket', 'processed_bucket', 'curated_bucket', 'database_name'
    ]
    optional_args = ['partition_date', 'notification_topic_arn']
    
    try:
        args = getResolvedOptions(sys.argv, required_args + optional_args)
    except Exception:
        # ローカル開発環境用のフォールバック
        args = {
            'JOB_NAME': 'enterprise-etl-job',
            'raw_bucket': 'my-raw-bucket',
            'processed_bucket': 'my-processed-bucket',
            'curated_bucket': 'my-curated-bucket',
            'database_name': 'analytics_db'
        }
    
    # ETLジョブ実行
    etl_job = EnterpriseETLJob(args)
    etl_job.run()

if __name__ == "__main__":
    main()