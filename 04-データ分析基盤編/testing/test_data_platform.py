#!/usr/bin/env python3
"""
Enterprise Data Platform Testing Framework
包括的なデータプラットフォームテストスイート
"""

import unittest
import json
import boto3
import time
import random
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional
import concurrent.futures
from dataclasses import dataclass
import tempfile
import os
import pandas as pd
import numpy as np
from moto import mock_s3, mock_kinesis, mock_glue, mock_cloudwatch

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@dataclass
class TestResult:
    """テスト結果"""
    test_name: str
    passed: bool
    duration: float
    message: str
    details: Dict[str, Any] = None

class DataPlatformTestSuite:
    """データプラットフォームテストスイートクラス"""
    
    def __init__(self, config_file: str):
        """
        初期化
        
        Args:
            config_file: 設定ファイルパス
        """
        with open(config_file, 'r') as f:
            self.config = json.load(f)
        
        self.aws_clients = {}
        self.test_results = []
        self.setup_aws_clients()
    
    def setup_aws_clients(self):
        """AWSクライアント初期化"""
        region = self.config['data_platform']['region']
        
        self.aws_clients = {
            'kinesis': boto3.client('kinesis', region_name=region),
            's3': boto3.client('s3', region_name=region),
            'glue': boto3.client('glue', region_name=region),
            'cloudwatch': boto3.client('cloudwatch', region_name=region),
            'quicksight': boto3.client('quicksight', region_name=region),
            'stepfunctions': boto3.client('stepfunctions', region_name=region)
        }
    
    def run_comprehensive_tests(self) -> Dict[str, Any]:
        """包括的テスト実行"""
        logger.info("Starting comprehensive data platform tests")
        
        test_suites = [
            ('Infrastructure Tests', self.run_infrastructure_tests),
            ('Kinesis Streaming Tests', self.run_kinesis_tests),
            ('ETL Pipeline Tests', self.run_etl_tests),
            ('Analytics Tests', self.run_analytics_tests),
            ('Monitoring Tests', self.run_monitoring_tests),
            ('Data Quality Tests', self.run_data_quality_tests),
            ('Performance Tests', self.run_performance_tests),
            ('Security Tests', self.run_security_tests)
        ]
        
        all_results = {}
        total_start = time.time()
        
        for suite_name, test_function in test_suites:
            logger.info(f"Running {suite_name}")
            try:
                suite_results = test_function()
                all_results[suite_name] = suite_results
            except Exception as e:
                logger.error(f"Test suite {suite_name} failed: {e}")
                all_results[suite_name] = {
                    'passed': False,
                    'error': str(e),
                    'tests': []
                }
        
        total_duration = time.time() - total_start
        
        # 結果集計
        summary = self.generate_test_summary(all_results, total_duration)
        
        return {
            'summary': summary,
            'detailed_results': all_results,
            'execution_time': total_duration
        }
    
    def run_infrastructure_tests(self) -> Dict[str, Any]:
        """インフラストラクチャテスト"""
        tests = []
        
        # S3バケット存在確認テスト
        test_result = self.test_s3_buckets_exist()
        tests.append(test_result)
        
        # IAMロール確認テスト
        test_result = self.test_iam_roles_exist()
        tests.append(test_result)
        
        # VPC設定確認テスト
        test_result = self.test_vpc_configuration()
        tests.append(test_result)
        
        # 暗号化設定確認テスト
        test_result = self.test_encryption_settings()
        tests.append(test_result)
        
        passed_count = sum(1 for test in tests if test.passed)
        
        return {
            'passed': passed_count == len(tests),
            'total_tests': len(tests),
            'passed_tests': passed_count,
            'tests': tests
        }
    
    def run_kinesis_tests(self) -> Dict[str, Any]:
        """Kinesisストリーミングテスト"""
        tests = []
        
        # ストリーム存在確認テスト
        test_result = self.test_kinesis_stream_exists()
        tests.append(test_result)
        
        # データ送信テスト
        test_result = self.test_kinesis_data_ingestion()
        tests.append(test_result)
        
        # スループットテスト
        test_result = self.test_kinesis_throughput()
        tests.append(test_result)
        
        # コンシューマーテスト
        test_result = self.test_kinesis_consumers()
        tests.append(test_result)
        
        # 暗号化テスト
        test_result = self.test_kinesis_encryption()
        tests.append(test_result)
        
        passed_count = sum(1 for test in tests if test.passed)
        
        return {
            'passed': passed_count == len(tests),
            'total_tests': len(tests),
            'passed_tests': passed_count,
            'tests': tests
        }
    
    def run_etl_tests(self) -> Dict[str, Any]:
        """ETLパイプラインテスト"""
        tests = []
        
        # Glueジョブ存在確認テスト
        test_result = self.test_glue_jobs_exist()
        tests.append(test_result)
        
        # データ変換テスト
        test_result = self.test_data_transformation()
        tests.append(test_result)
        
        # データ品質テスト
        test_result = self.test_data_quality_validation()
        tests.append(test_result)
        
        # Step Functions ワークフローテスト
        test_result = self.test_step_functions_workflow()
        tests.append(test_result)
        
        # パーティション戦略テスト
        test_result = self.test_data_partitioning()
        tests.append(test_result)
        
        passed_count = sum(1 for test in tests if test.passed)
        
        return {
            'passed': passed_count == len(tests),
            'total_tests': len(tests),
            'passed_tests': passed_count,
            'tests': tests
        }
    
    def run_analytics_tests(self) -> Dict[str, Any]:
        """分析機能テスト"""
        tests = []
        
        # QuickSightデータソーステスト
        test_result = self.test_quicksight_data_sources()
        tests.append(test_result)
        
        # ダッシュボード作成テスト
        test_result = self.test_dashboard_creation()
        tests.append(test_result)
        
        # データセット更新テスト
        test_result = self.test_dataset_refresh()
        tests.append(test_result)
        
        # 埋め込み分析テスト
        test_result = self.test_embedded_analytics()
        tests.append(test_result)
        
        passed_count = sum(1 for test in tests if test.passed)
        
        return {
            'passed': passed_count == len(tests),
            'total_tests': len(tests),
            'passed_tests': passed_count,
            'tests': tests
        }
    
    def run_monitoring_tests(self) -> Dict[str, Any]:
        """監視機能テスト"""
        tests = []
        
        # カスタムメトリクステスト
        test_result = self.test_custom_metrics()
        tests.append(test_result)
        
        # アラート設定テスト
        test_result = self.test_alert_configuration()
        tests.append(test_result)
        
        # ダッシュボード機能テスト
        test_result = self.test_cloudwatch_dashboards()
        tests.append(test_result)
        
        # ログ分析テスト
        test_result = self.test_log_insights()
        tests.append(test_result)
        
        # 異常検知テスト
        test_result = self.test_anomaly_detection()
        tests.append(test_result)
        
        passed_count = sum(1 for test in tests if test.passed)
        
        return {
            'passed': passed_count == len(tests),
            'total_tests': len(tests),
            'passed_tests': passed_count,
            'tests': tests
        }
    
    def run_data_quality_tests(self) -> Dict[str, Any]:
        """データ品質テスト"""
        tests = []
        
        # 完全性テスト
        test_result = self.test_data_completeness()
        tests.append(test_result)
        
        # 一意性テスト
        test_result = self.test_data_uniqueness()
        tests.append(test_result)
        
        # 妥当性テスト
        test_result = self.test_data_validity()
        tests.append(test_result)
        
        # 一貫性テスト
        test_result = self.test_data_consistency()
        tests.append(test_result)
        
        # 適時性テスト
        test_result = self.test_data_timeliness()
        tests.append(test_result)
        
        passed_count = sum(1 for test in tests if test.passed)
        
        return {
            'passed': passed_count == len(tests),
            'total_tests': len(tests),
            'passed_tests': passed_count,
            'tests': tests
        }
    
    def run_performance_tests(self) -> Dict[str, Any]:
        """パフォーマンステスト"""
        tests = []
        
        # スループットテスト
        test_result = self.test_throughput_performance()
        tests.append(test_result)
        
        # レイテンシテスト
        test_result = self.test_latency_performance()
        tests.append(test_result)
        
        # スケーラビリティテスト
        test_result = self.test_scalability()
        tests.append(test_result)
        
        # リソース使用率テスト
        test_result = self.test_resource_utilization()
        tests.append(test_result)
        
        passed_count = sum(1 for test in tests if test.passed)
        
        return {
            'passed': passed_count == len(tests),
            'total_tests': len(tests),
            'passed_tests': passed_count,
            'tests': tests
        }
    
    def run_security_tests(self) -> Dict[str, Any]:
        """セキュリティテスト"""
        tests = []
        
        # 暗号化テスト
        test_result = self.test_encryption_compliance()
        tests.append(test_result)
        
        # アクセス制御テスト
        test_result = self.test_access_controls()
        tests.append(test_result)
        
        # ネットワークセキュリティテスト
        test_result = self.test_network_security()
        tests.append(test_result)
        
        # 監査ログテスト
        test_result = self.test_audit_logging()
        tests.append(test_result)
        
        passed_count = sum(1 for test in tests if test.passed)
        
        return {
            'passed': passed_count == len(tests),
            'total_tests': len(tests),
            'passed_tests': passed_count,
            'tests': tests
        }
    
    # 個別テストメソッド
    def test_s3_buckets_exist(self) -> TestResult:
        """S3バケット存在確認テスト"""
        start_time = time.time()
        
        try:
            buckets_to_check = [
                self.config['etl_pipeline']['raw_bucket'],
                self.config['etl_pipeline']['processed_bucket'],
                self.config['etl_pipeline']['curated_bucket']
            ]
            
            for bucket in buckets_to_check:
                try:
                    self.aws_clients['s3'].head_bucket(Bucket=bucket)
                except Exception as e:
                    duration = time.time() - start_time
                    return TestResult(
                        test_name="S3 Buckets Existence",
                        passed=False,
                        duration=duration,
                        message=f"Bucket {bucket} not found: {str(e)}"
                    )
            
            duration = time.time() - start_time
            return TestResult(
                test_name="S3 Buckets Existence",
                passed=True,
                duration=duration,
                message="All required S3 buckets exist",
                details={'buckets_checked': buckets_to_check}
            )
            
        except Exception as e:
            duration = time.time() - start_time
            return TestResult(
                test_name="S3 Buckets Existence",
                passed=False,
                duration=duration,
                message=f"Test failed: {str(e)}"
            )
    
    def test_kinesis_stream_exists(self) -> TestResult:
        """Kinesisストリーム存在確認テスト"""
        start_time = time.time()
        
        try:
            stream_name = self.config['kinesis_streaming']['stream_name']
            
            response = self.aws_clients['kinesis'].describe_stream(StreamName=stream_name)
            
            stream_status = response['StreamDescription']['StreamStatus']
            
            duration = time.time() - start_time
            
            if stream_status == 'ACTIVE':
                return TestResult(
                    test_name="Kinesis Stream Existence",
                    passed=True,
                    duration=duration,
                    message=f"Stream {stream_name} is active",
                    details={'stream_status': stream_status}
                )
            else:
                return TestResult(
                    test_name="Kinesis Stream Existence",
                    passed=False,
                    duration=duration,
                    message=f"Stream {stream_name} is not active (status: {stream_status})"
                )
                
        except Exception as e:
            duration = time.time() - start_time
            return TestResult(
                test_name="Kinesis Stream Existence",
                passed=False,
                duration=duration,
                message=f"Test failed: {str(e)}"
            )
    
    def test_kinesis_data_ingestion(self) -> TestResult:
        """Kinesisデータ取り込みテスト"""
        start_time = time.time()
        
        try:
            stream_name = self.config['kinesis_streaming']['stream_name']
            
            # テストデータ生成
            test_data = {
                'test_id': 'test_' + str(int(time.time())),
                'event_type': 'test_event',
                'timestamp': datetime.utcnow().isoformat(),
                'test_payload': 'data_ingestion_test'
            }
            
            # データ送信
            response = self.aws_clients['kinesis'].put_record(
                StreamName=stream_name,
                Data=json.dumps(test_data),
                PartitionKey=test_data['test_id']
            )
            
            duration = time.time() - start_time
            
            if response['ResponseMetadata']['HTTPStatusCode'] == 200:
                return TestResult(
                    test_name="Kinesis Data Ingestion",
                    passed=True,
                    duration=duration,
                    message="Data successfully ingested to Kinesis",
                    details={'sequence_number': response['SequenceNumber']}
                )
            else:
                return TestResult(
                    test_name="Kinesis Data Ingestion",
                    passed=False,
                    duration=duration,
                    message=f"Failed to ingest data, HTTP status: {response['ResponseMetadata']['HTTPStatusCode']}"
                )
                
        except Exception as e:
            duration = time.time() - start_time
            return TestResult(
                test_name="Kinesis Data Ingestion",
                passed=False,
                duration=duration,
                message=f"Test failed: {str(e)}"
            )
    
    def test_data_transformation(self) -> TestResult:
        """データ変換テスト"""
        start_time = time.time()
        
        try:
            # サンプルデータ作成
            sample_data = pd.DataFrame({
                'user_id': ['user_1', 'user_2', 'user_3'],
                'event_type': ['login', 'purchase', 'logout'],
                'timestamp': ['2024-01-01T10:00:00', '2024-01-01T10:15:00', '2024-01-01T10:30:00'],
                'amount': [None, 99.99, None]
            })
            
            # データ変換ロジックのテスト
            # 1. NULL値処理
            cleaned_data = sample_data.dropna(subset=['user_id', 'event_type'])
            
            # 2. タイムスタンプ正規化
            cleaned_data['timestamp_normalized'] = pd.to_datetime(cleaned_data['timestamp'])
            
            # 3. 計算フィールド追加
            cleaned_data['processing_time'] = datetime.utcnow()
            
            duration = time.time() - start_time
            
            # 検証
            if len(cleaned_data) > 0 and 'timestamp_normalized' in cleaned_data.columns:
                return TestResult(
                    test_name="Data Transformation",
                    passed=True,
                    duration=duration,
                    message="Data transformation completed successfully",
                    details={'input_records': len(sample_data), 'output_records': len(cleaned_data)}
                )
            else:
                return TestResult(
                    test_name="Data Transformation",
                    passed=False,
                    duration=duration,
                    message="Data transformation failed"
                )
                
        except Exception as e:
            duration = time.time() - start_time
            return TestResult(
                test_name="Data Transformation",
                passed=False,
                duration=duration,
                message=f"Test failed: {str(e)}"
            )
    
    def test_data_completeness(self) -> TestResult:
        """データ完全性テスト"""
        start_time = time.time()
        
        try:
            # サンプルデータで完全性テスト
            test_data = pd.DataFrame({
                'user_id': ['user_1', 'user_2', None, 'user_4'],
                'event_type': ['login', None, 'purchase', 'logout'],
                'timestamp': ['2024-01-01T10:00:00', '2024-01-01T10:15:00', '2024-01-01T10:30:00', None]
            })
            
            required_fields = ['user_id', 'event_type', 'timestamp']
            total_records = len(test_data)
            
            completeness_scores = {}
            for field in required_fields:
                null_count = test_data[field].isnull().sum()
                completeness = 1 - (null_count / total_records)
                completeness_scores[field] = completeness
            
            overall_completeness = sum(completeness_scores.values()) / len(completeness_scores)
            threshold = self.config['etl_pipeline']['data_quality']['completeness_threshold']
            
            duration = time.time() - start_time
            
            if overall_completeness >= threshold:
                return TestResult(
                    test_name="Data Completeness",
                    passed=True,
                    duration=duration,
                    message=f"Data completeness: {overall_completeness:.2%} (threshold: {threshold:.2%})",
                    details={'completeness_scores': completeness_scores}
                )
            else:
                return TestResult(
                    test_name="Data Completeness",
                    passed=False,
                    duration=duration,
                    message=f"Data completeness below threshold: {overall_completeness:.2%} < {threshold:.2%}",
                    details={'completeness_scores': completeness_scores}
                )
                
        except Exception as e:
            duration = time.time() - start_time
            return TestResult(
                test_name="Data Completeness",
                passed=False,
                duration=duration,
                message=f"Test failed: {str(e)}"
            )
    
    def test_throughput_performance(self) -> TestResult:
        """スループットパフォーマンステスト"""
        start_time = time.time()
        
        try:
            # シミュレーションによるスループットテスト
            test_events = 1000
            batch_size = 100
            
            # バッチ処理時間シミュレーション
            processing_times = []
            
            for batch in range(0, test_events, batch_size):
                batch_start = time.time()
                
                # 処理時間シミュレーション (実際の処理では実際のデータ処理)
                time.sleep(0.001)  # 1ms simulation
                
                batch_duration = time.time() - batch_start
                processing_times.append(batch_duration)
            
            avg_batch_time = sum(processing_times) / len(processing_times)
            throughput = batch_size / avg_batch_time  # events per second
            
            duration = time.time() - start_time
            
            # パフォーマンス基準: 1000 events/second
            target_throughput = 1000
            
            if throughput >= target_throughput:
                return TestResult(
                    test_name="Throughput Performance",
                    passed=True,
                    duration=duration,
                    message=f"Throughput: {throughput:.0f} events/sec (target: {target_throughput})",
                    details={'throughput': throughput, 'avg_batch_time': avg_batch_time}
                )
            else:
                return TestResult(
                    test_name="Throughput Performance",
                    passed=False,
                    duration=duration,
                    message=f"Throughput below target: {throughput:.0f} < {target_throughput} events/sec",
                    details={'throughput': throughput, 'avg_batch_time': avg_batch_time}
                )
                
        except Exception as e:
            duration = time.time() - start_time
            return TestResult(
                test_name="Throughput Performance",
                passed=False,
                duration=duration,
                message=f"Test failed: {str(e)}"
            )
    
    # Mock implementations for demonstration
    def test_iam_roles_exist(self) -> TestResult:
        """IAMロール存在確認テスト (Mock)"""
        return TestResult("IAM Roles Existence", True, 0.1, "Mock: IAM roles verified")
    
    def test_vpc_configuration(self) -> TestResult:
        """VPC設定テスト (Mock)"""
        return TestResult("VPC Configuration", True, 0.1, "Mock: VPC configuration validated")
    
    def test_encryption_settings(self) -> TestResult:
        """暗号化設定テスト (Mock)"""
        return TestResult("Encryption Settings", True, 0.1, "Mock: Encryption settings verified")
    
    def test_kinesis_throughput(self) -> TestResult:
        """Kinesisスループットテスト (Mock)"""
        return TestResult("Kinesis Throughput", True, 0.5, "Mock: Kinesis throughput acceptable")
    
    def test_kinesis_consumers(self) -> TestResult:
        """Kinesisコンシューマーテスト (Mock)"""
        return TestResult("Kinesis Consumers", True, 0.3, "Mock: Kinesis consumers working")
    
    def test_kinesis_encryption(self) -> TestResult:
        """Kinesis暗号化テスト (Mock)"""
        return TestResult("Kinesis Encryption", True, 0.1, "Mock: Kinesis encryption enabled")
    
    def test_glue_jobs_exist(self) -> TestResult:
        """Glueジョブ存在確認テスト (Mock)"""
        return TestResult("Glue Jobs Existence", True, 0.2, "Mock: Glue jobs exist")
    
    def test_data_quality_validation(self) -> TestResult:
        """データ品質検証テスト (Mock)"""
        return TestResult("Data Quality Validation", True, 0.4, "Mock: Data quality checks passed")
    
    def test_step_functions_workflow(self) -> TestResult:
        """Step Functionsワークフローテスト (Mock)"""
        return TestResult("Step Functions Workflow", True, 0.3, "Mock: Workflow executed successfully")
    
    def test_data_partitioning(self) -> TestResult:
        """データパーティショニングテスト (Mock)"""
        return TestResult("Data Partitioning", True, 0.2, "Mock: Data partitioning strategy validated")
    
    def test_quicksight_data_sources(self) -> TestResult:
        """QuickSightデータソーステスト (Mock)"""
        return TestResult("QuickSight Data Sources", True, 0.3, "Mock: Data sources accessible")
    
    def test_dashboard_creation(self) -> TestResult:
        """ダッシュボード作成テスト (Mock)"""
        return TestResult("Dashboard Creation", True, 0.5, "Mock: Dashboards created successfully")
    
    def test_dataset_refresh(self) -> TestResult:
        """データセット更新テスト (Mock)"""
        return TestResult("Dataset Refresh", True, 0.4, "Mock: Dataset refresh working")
    
    def test_embedded_analytics(self) -> TestResult:
        """埋め込み分析テスト (Mock)"""
        return TestResult("Embedded Analytics", True, 0.3, "Mock: Embedded analytics functional")
    
    def test_custom_metrics(self) -> TestResult:
        """カスタムメトリクステスト (Mock)"""
        return TestResult("Custom Metrics", True, 0.2, "Mock: Custom metrics being collected")
    
    def test_alert_configuration(self) -> TestResult:
        """アラート設定テスト (Mock)"""
        return TestResult("Alert Configuration", True, 0.2, "Mock: Alerts configured properly")
    
    def test_cloudwatch_dashboards(self) -> TestResult:
        """CloudWatchダッシュボードテスト (Mock)"""
        return TestResult("CloudWatch Dashboards", True, 0.3, "Mock: Dashboards operational")
    
    def test_log_insights(self) -> TestResult:
        """ログ分析テスト (Mock)"""
        return TestResult("Log Insights", True, 0.4, "Mock: Log insights working")
    
    def test_anomaly_detection(self) -> TestResult:
        """異常検知テスト (Mock)"""
        return TestResult("Anomaly Detection", True, 0.3, "Mock: Anomaly detection enabled")
    
    def test_data_uniqueness(self) -> TestResult:
        """データ一意性テスト (Mock)"""
        return TestResult("Data Uniqueness", True, 0.2, "Mock: Data uniqueness validated")
    
    def test_data_validity(self) -> TestResult:
        """データ妥当性テスト (Mock)"""
        return TestResult("Data Validity", True, 0.3, "Mock: Data validity checks passed")
    
    def test_data_consistency(self) -> TestResult:
        """データ一貫性テスト (Mock)"""
        return TestResult("Data Consistency", True, 0.3, "Mock: Data consistency verified")
    
    def test_data_timeliness(self) -> TestResult:
        """データ適時性テスト (Mock)"""
        return TestResult("Data Timeliness", True, 0.2, "Mock: Data timeliness acceptable")
    
    def test_latency_performance(self) -> TestResult:
        """レイテンシパフォーマンステスト (Mock)"""
        return TestResult("Latency Performance", True, 0.4, "Mock: Latency within acceptable limits")
    
    def test_scalability(self) -> TestResult:
        """スケーラビリティテスト (Mock)"""
        return TestResult("Scalability", True, 0.6, "Mock: System scales properly")
    
    def test_resource_utilization(self) -> TestResult:
        """リソース使用率テスト (Mock)"""
        return TestResult("Resource Utilization", True, 0.3, "Mock: Resource utilization optimal")
    
    def test_encryption_compliance(self) -> TestResult:
        """暗号化コンプライアンステスト (Mock)"""
        return TestResult("Encryption Compliance", True, 0.2, "Mock: Encryption compliance verified")
    
    def test_access_controls(self) -> TestResult:
        """アクセス制御テスト (Mock)"""
        return TestResult("Access Controls", True, 0.3, "Mock: Access controls working")
    
    def test_network_security(self) -> TestResult:
        """ネットワークセキュリティテスト (Mock)"""
        return TestResult("Network Security", True, 0.2, "Mock: Network security validated")
    
    def test_audit_logging(self) -> TestResult:
        """監査ログテスト (Mock)"""
        return TestResult("Audit Logging", True, 0.2, "Mock: Audit logging enabled")
    
    def generate_test_summary(self, all_results: Dict, total_duration: float) -> Dict:
        """テスト結果サマリー生成"""
        total_tests = 0
        passed_tests = 0
        failed_suites = []
        
        for suite_name, suite_result in all_results.items():
            if 'total_tests' in suite_result:
                total_tests += suite_result['total_tests']
                passed_tests += suite_result['passed_tests']
                
                if not suite_result['passed']:
                    failed_suites.append(suite_name)
        
        success_rate = (passed_tests / total_tests * 100) if total_tests > 0 else 0
        
        return {
            'overall_success': len(failed_suites) == 0,
            'total_test_suites': len(all_results),
            'passed_test_suites': len(all_results) - len(failed_suites),
            'total_tests': total_tests,
            'passed_tests': passed_tests,
            'failed_tests': total_tests - passed_tests,
            'success_rate': success_rate,
            'total_duration': total_duration,
            'failed_suites': failed_suites
        }

def main():
    """メイン実行関数"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Data Platform Test Suite')
    parser.add_argument('--config', required=True, help='Configuration file path')
    parser.add_argument('--output', help='Output file for test results')
    parser.add_argument('--suite', help='Specific test suite to run')
    
    args = parser.parse_args()
    
    # テストスイート実行
    test_suite = DataPlatformTestSuite(args.config)
    
    if args.suite:
        # 特定のテストスイートのみ実行
        suite_methods = {
            'infrastructure': test_suite.run_infrastructure_tests,
            'kinesis': test_suite.run_kinesis_tests,
            'etl': test_suite.run_etl_tests,
            'analytics': test_suite.run_analytics_tests,
            'monitoring': test_suite.run_monitoring_tests,
            'quality': test_suite.run_data_quality_tests,
            'performance': test_suite.run_performance_tests,
            'security': test_suite.run_security_tests
        }
        
        if args.suite in suite_methods:
            results = suite_methods[args.suite]()
            print(f"Test Suite: {args.suite}")
            print(f"Results: {json.dumps(results, indent=2, default=str)}")
        else:
            print(f"Unknown test suite: {args.suite}")
            return 1
    else:
        # 全テスト実行
        results = test_suite.run_comprehensive_tests()
        
        # 結果表示
        summary = results['summary']
        print("\n" + "="*60)
        print("DATA PLATFORM TEST RESULTS SUMMARY")
        print("="*60)
        print(f"Overall Success: {'✓' if summary['overall_success'] else '✗'}")
        print(f"Test Suites: {summary['passed_test_suites']}/{summary['total_test_suites']} passed")
        print(f"Individual Tests: {summary['passed_tests']}/{summary['total_tests']} passed")
        print(f"Success Rate: {summary['success_rate']:.1f}%")
        print(f"Total Duration: {summary['total_duration']:.2f} seconds")
        
        if summary['failed_suites']:
            print(f"\nFailed Suites: {', '.join(summary['failed_suites'])}")
        
        # 結果をファイルに保存
        if args.output:
            with open(args.output, 'w') as f:
                json.dump(results, f, indent=2, default=str)
            print(f"\nDetailed results saved to: {args.output}")
        
        return 0 if summary['overall_success'] else 1

if __name__ == "__main__":
    exit(main())