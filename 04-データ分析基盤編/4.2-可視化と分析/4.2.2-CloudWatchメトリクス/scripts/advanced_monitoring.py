#!/usr/bin/env python3
"""
高度なCloudWatch監視スクリプト
エンタープライズ級のメトリクス収集・分析・アラート管理
"""

import json
import boto3
import time
import logging
import numpy as np
import pandas as pd
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional, Tuple
import argparse
from dataclasses import dataclass, field
import concurrent.futures
import statistics
from enum import Enum

# ログ設定
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class MetricType(Enum):
    """メトリクスタイプ"""
    COUNTER = "counter"
    GAUGE = "gauge"
    HISTOGRAM = "histogram"
    TIMER = "timer"

class AlertSeverity(Enum):
    """アラート重要度"""
    CRITICAL = "critical"
    HIGH = "high"
    MEDIUM = "medium"
    LOW = "low"
    INFO = "info"

@dataclass
class MetricDefinition:
    """メトリクス定義"""
    name: str
    namespace: str
    metric_type: MetricType
    dimensions: Dict[str, str] = field(default_factory=dict)
    unit: str = "Count"
    description: str = ""

@dataclass
class AlertRule:
    """アラートルール定義"""
    name: str
    metric_name: str
    namespace: str
    statistic: str
    threshold: float
    comparison_operator: str
    evaluation_periods: int
    period: int
    severity: AlertSeverity
    dimensions: Dict[str, str] = field(default_factory=dict)
    actions: List[str] = field(default_factory=list)

class AdvancedCloudWatchMonitor:
    """高度なCloudWatch監視クラス"""
    
    def __init__(self, region: str = 'us-east-1'):
        """
        初期化
        
        Args:
            region: AWSリージョン
        """
        self.region = region
        self.cloudwatch = boto3.client('cloudwatch', region_name=region)
        self.logs = boto3.client('logs', region_name=region)
        self.sns = boto3.client('sns', region_name=region)
        self.events = boto3.client('events', region_name=region)
        
        # 内部状態
        self.metric_buffer = {}
        self.alert_history = {}
        self.anomaly_detectors = {}
        
        logger.info(f"Advanced CloudWatch Monitor initialized for region {region}")
    
    def setup_enterprise_monitoring(self, config: Dict[str, Any]) -> Dict[str, str]:
        """エンタープライズ監視セットアップ"""
        logger.info("Setting up enterprise monitoring suite")
        
        results = {}
        
        try:
            # 1. カスタムメトリクス定義
            self._setup_custom_metrics(config.get('custom_metrics', []))
            results['custom_metrics'] = 'configured'
            
            # 2. ダッシュボード作成
            dashboard_id = self._create_comprehensive_dashboard(config)
            results['dashboard'] = dashboard_id
            
            # 3. アラート設定
            alert_arns = self._setup_intelligent_alerts(config.get('alert_rules', []))
            results['alerts'] = alert_arns
            
            # 4. 異常検知設定
            anomaly_detectors = self._setup_anomaly_detection(config.get('anomaly_detection', {}))
            results['anomaly_detectors'] = anomaly_detectors
            
            # 5. ログ分析設定
            log_insights = self._setup_log_insights(config.get('log_insights', {}))
            results['log_insights'] = log_insights
            
            # 6. 自動応答設定
            automation_rules = self._setup_automated_responses(config.get('automation', {}))
            results['automation'] = automation_rules
            
            logger.info("Enterprise monitoring setup completed successfully")
            return results
            
        except Exception as e:
            logger.error(f"Failed to setup enterprise monitoring: {e}")
            raise
    
    def collect_advanced_metrics(self, applications: List[str], duration_minutes: int = 60):
        """高度なメトリクス収集"""
        logger.info(f"Starting advanced metrics collection for {duration_minutes} minutes")
        
        end_time = datetime.utcnow()
        start_time = end_time - timedelta(minutes=duration_minutes)
        
        metrics_data = {}
        
        # 並列でメトリクス収集
        with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
            futures = {}
            
            for app in applications:
                # システムメトリクス
                futures[f"{app}_system"] = executor.submit(
                    self._collect_system_metrics, app, start_time, end_time
                )
                
                # アプリケーションメトリクス
                futures[f"{app}_application"] = executor.submit(
                    self._collect_application_metrics, app, start_time, end_time
                )
                
                # ビジネスメトリクス
                futures[f"{app}_business"] = executor.submit(
                    self._collect_business_metrics, app, start_time, end_time
                )
            
            # 結果収集
            for future_name, future in futures.items():
                try:
                    result = future.result(timeout=60)
                    metrics_data[future_name] = result
                except Exception as e:
                    logger.error(f"Failed to collect metrics for {future_name}: {e}")
        
        # メトリクス分析
        analysis_results = self._analyze_collected_metrics(metrics_data)
        
        # 結果をCloudWatchに送信
        self._send_analysis_metrics(analysis_results)
        
        return analysis_results
    
    def perform_anomaly_analysis(self, metric_name: str, namespace: str, 
                                 lookback_days: int = 14) -> Dict[str, Any]:
        """異常分析実行"""
        logger.info(f"Performing anomaly analysis for {namespace}/{metric_name}")
        
        # 履歴データ取得
        end_time = datetime.utcnow()
        start_time = end_time - timedelta(days=lookback_days)
        
        historical_data = self._get_metric_data(
            metric_name, namespace, start_time, end_time, 'Average', 300
        )
        
        if not historical_data:
            return {'status': 'no_data', 'message': 'Insufficient historical data'}
        
        # 統計分析
        values = [point['Value'] for point in historical_data]
        timestamps = [point['Timestamp'] for point in historical_data]
        
        # 基本統計
        stats = {
            'mean': statistics.mean(values),
            'median': statistics.median(values),
            'std_dev': statistics.stdev(values) if len(values) > 1 else 0,
            'min': min(values),
            'max': max(values),
            'count': len(values)
        }
        
        # 異常値検出（Zスコア法）
        anomalies = self._detect_anomalies_zscore(values, timestamps, threshold=2.5)
        
        # 季節性分析
        seasonality = self._analyze_seasonality(values, timestamps)
        
        # トレンド分析
        trend = self._analyze_trend(values, timestamps)
        
        # 予測（シンプルな移動平均）
        forecast = self._simple_forecast(values, periods=12)
        
        result = {
            'metric': {'name': metric_name, 'namespace': namespace},
            'analysis_period': {'start': start_time.isoformat(), 'end': end_time.isoformat()},
            'statistics': stats,
            'anomalies': anomalies,
            'seasonality': seasonality,
            'trend': trend,
            'forecast': forecast,
            'recommendations': self._generate_recommendations(stats, anomalies, trend)
        }
        
        # 異常検知器の設定推奨
        if anomalies['count'] > 0:
            detector_config = self._recommend_anomaly_detector(stats, anomalies)
            result['recommended_detector'] = detector_config
        
        return result
    
    def create_intelligent_dashboard(self, dashboard_name: str, 
                                   applications: List[str]) -> str:
        """インテリジェントダッシュボード作成"""
        logger.info(f"Creating intelligent dashboard: {dashboard_name}")
        
        # ダッシュボード定義生成
        dashboard_body = self._generate_intelligent_dashboard_body(applications)
        
        try:
            response = self.cloudwatch.put_dashboard(
                DashboardName=dashboard_name,
                DashboardBody=json.dumps(dashboard_body)
            )
            
            logger.info(f"Intelligent dashboard created: {dashboard_name}")
            return dashboard_name
            
        except Exception as e:
            logger.error(f"Failed to create dashboard: {e}")
            raise
    
    def setup_predictive_scaling(self, resource_config: Dict[str, Any]) -> Dict[str, str]:
        """予測スケーリング設定"""
        logger.info("Setting up predictive scaling")
        
        scaling_policies = {}
        
        for resource_name, config in resource_config.items():
            try:
                # 履歴メトリクス分析
                metric_analysis = self.perform_anomaly_analysis(
                    config['metric_name'], 
                    config['namespace'], 
                    lookback_days=30
                )
                
                # スケーリング閾値計算
                thresholds = self._calculate_scaling_thresholds(metric_analysis)
                
                # スケーリングポリシー作成
                policy_arn = self._create_scaling_policy(resource_name, config, thresholds)
                scaling_policies[resource_name] = policy_arn
                
                logger.info(f"Predictive scaling configured for {resource_name}")
                
            except Exception as e:
                logger.error(f"Failed to setup scaling for {resource_name}: {e}")
        
        return scaling_policies
    
    def analyze_cost_metrics(self, services: List[str], period_days: int = 30) -> Dict[str, Any]:
        """コストメトリクス分析"""
        logger.info(f"Analyzing cost metrics for {period_days} days")
        
        # Cost Explorer APIを使用
        ce_client = boto3.client('ce')
        
        end_date = datetime.utcnow().date()
        start_date = end_date - timedelta(days=period_days)
        
        cost_analysis = {}
        
        for service in services:
            try:
                response = ce_client.get_cost_and_usage(
                    TimePeriod={
                        'Start': start_date.strftime('%Y-%m-%d'),
                        'End': end_date.strftime('%Y-%m-%d')
                    },
                    Granularity='DAILY',
                    Metrics=['BlendedCost', 'UsageQuantity'],
                    GroupBy=[
                        {'Type': 'DIMENSION', 'Key': 'SERVICE'}
                    ],
                    Filter={
                        'Dimensions': {
                            'Key': 'SERVICE',
                            'Values': [service]
                        }
                    }
                )
                
                # コストデータ処理
                daily_costs = []
                for result in response['ResultsByTime']:
                    date = result['TimePeriod']['Start']
                    for group in result['Groups']:
                        cost = float(group['Metrics']['BlendedCost']['Amount'])
                        usage = float(group['Metrics']['UsageQuantity']['Amount'])
                        daily_costs.append({
                            'date': date,
                            'cost': cost,
                            'usage': usage
                        })
                
                # コスト分析
                if daily_costs:
                    costs = [item['cost'] for item in daily_costs]
                    cost_analysis[service] = {
                        'total_cost': sum(costs),
                        'average_daily_cost': statistics.mean(costs),
                        'cost_trend': self._calculate_cost_trend(costs),
                        'cost_forecast': self._forecast_cost(costs),
                        'optimization_opportunities': self._identify_cost_optimizations(daily_costs)
                    }
                
            except Exception as e:
                logger.error(f"Failed to analyze costs for {service}: {e}")
        
        # コスト最適化推奨
        optimization_recommendations = self._generate_cost_optimization_recommendations(cost_analysis)
        
        return {
            'analysis_period': {'start': start_date.isoformat(), 'end': end_date.isoformat()},
            'service_costs': cost_analysis,
            'recommendations': optimization_recommendations
        }
    
    def create_sla_monitoring(self, sla_config: Dict[str, Any]) -> List[str]:
        """SLA監視設定"""
        logger.info("Setting up SLA monitoring")
        
        alarm_arns = []
        
        for sla_name, config in sla_config.items():
            try:
                # SLA計算用のメトリクス数式
                metric_math = self._create_sla_metric_math(config)
                
                # SLAアラーム作成
                alarm_name = f"SLA-{sla_name}-Violation"
                
                response = self.cloudwatch.put_metric_alarm(
                    AlarmName=alarm_name,
                    ComparisonOperator='LessThanThreshold',
                    EvaluationPeriods=config.get('evaluation_periods', 2),
                    Metrics=metric_math,
                    Threshold=config['sla_threshold'],
                    ActionsEnabled=True,
                    AlarmActions=config.get('alarm_actions', []),
                    AlarmDescription=f"SLA violation monitoring for {sla_name}",
                    TreatMissingData='breaching',
                    Tags=[
                        {'Key': 'Type', 'Value': 'SLA'},
                        {'Key': 'Service', 'Value': sla_name}
                    ]
                )
                
                alarm_arns.append(f"arn:aws:cloudwatch:{self.region}:*:alarm:{alarm_name}")
                logger.info(f"SLA monitoring configured for {sla_name}")
                
            except Exception as e:
                logger.error(f"Failed to setup SLA monitoring for {sla_name}: {e}")
        
        return alarm_arns
    
    def generate_monitoring_report(self, report_config: Dict[str, Any]) -> Dict[str, Any]:
        """監視レポート生成"""
        logger.info("Generating comprehensive monitoring report")
        
        report = {
            'generated_at': datetime.utcnow().isoformat(),
            'period': report_config.get('period', '24h'),
            'sections': {}
        }
        
        # システム健全性
        if 'system_health' in report_config.get('sections', []):
            report['sections']['system_health'] = self._generate_system_health_report()
        
        # パフォーマンス分析
        if 'performance' in report_config.get('sections', []):
            report['sections']['performance'] = self._generate_performance_report()
        
        # アラート分析
        if 'alerts' in report_config.get('sections', []):
            report['sections']['alerts'] = self._generate_alerts_report()
        
        # コスト分析
        if 'costs' in report_config.get('sections', []):
            report['sections']['costs'] = self._generate_costs_report()
        
        # 推奨事項
        report['recommendations'] = self._generate_overall_recommendations(report['sections'])
        
        return report
    
    # ヘルパーメソッド
    def _setup_custom_metrics(self, metrics: List[Dict]):
        """カスタムメトリクス設定"""
        for metric_config in metrics:
            metric_def = MetricDefinition(
                name=metric_config['name'],
                namespace=metric_config['namespace'],
                metric_type=MetricType(metric_config.get('type', 'gauge')),
                dimensions=metric_config.get('dimensions', {}),
                unit=metric_config.get('unit', 'Count'),
                description=metric_config.get('description', '')
            )
            self.metric_buffer[metric_def.name] = metric_def
    
    def _create_comprehensive_dashboard(self, config: Dict) -> str:
        """包括的ダッシュボード作成"""
        dashboard_name = config.get('dashboard_name', 'enterprise-monitoring-dashboard')
        
        # ダッシュボード本体生成
        dashboard_body = {
            "widgets": [
                # システム概要ウィジェット
                self._create_system_overview_widget(),
                # パフォーマンスメトリクス
                self._create_performance_metrics_widget(),
                # アラート状況
                self._create_alerts_status_widget(),
                # コストトレンド
                self._create_cost_trend_widget()
            ]
        }
        
        self.cloudwatch.put_dashboard(
            DashboardName=dashboard_name,
            DashboardBody=json.dumps(dashboard_body)
        )
        
        return dashboard_name
    
    def _setup_intelligent_alerts(self, alert_rules: List[Dict]) -> List[str]:
        """インテリジェントアラート設定"""
        alarm_arns = []
        
        for rule_config in alert_rules:
            alert_rule = AlertRule(
                name=rule_config['name'],
                metric_name=rule_config['metric_name'],
                namespace=rule_config['namespace'],
                statistic=rule_config.get('statistic', 'Average'),
                threshold=rule_config['threshold'],
                comparison_operator=rule_config.get('comparison_operator', 'GreaterThanThreshold'),
                evaluation_periods=rule_config.get('evaluation_periods', 2),
                period=rule_config.get('period', 300),
                severity=AlertSeverity(rule_config.get('severity', 'medium')),
                dimensions=rule_config.get('dimensions', {}),
                actions=rule_config.get('actions', [])
            )
            
            # 動的閾値の計算（履歴データベース）
            if rule_config.get('dynamic_threshold', False):
                alert_rule.threshold = self._calculate_dynamic_threshold(alert_rule)
            
            # アラーム作成
            alarm_arn = self._create_cloudwatch_alarm(alert_rule)
            alarm_arns.append(alarm_arn)
        
        return alarm_arns
    
    def _setup_anomaly_detection(self, config: Dict) -> List[str]:
        """異常検知設定"""
        detector_arns = []
        
        for detector_config in config.get('detectors', []):
            try:
                response = self.cloudwatch.put_anomaly_detector(
                    Namespace=detector_config['namespace'],
                    MetricName=detector_config['metric_name'],
                    Dimensions=detector_config.get('dimensions', []),
                    Stat=detector_config.get('stat', 'Average')
                )
                
                detector_arns.append(response.get('Arn', ''))
                
            except Exception as e:
                logger.error(f"Failed to create anomaly detector: {e}")
        
        return detector_arns
    
    def _collect_system_metrics(self, app_name: str, start_time: datetime, 
                               end_time: datetime) -> Dict:
        """システムメトリクス収集"""
        metrics = {}
        
        # CPU使用率
        cpu_data = self._get_metric_data(
            'CPUUtilization', 'AWS/EC2', start_time, end_time, 'Average', 300
        )
        if cpu_data:
            metrics['cpu_utilization'] = {
                'average': statistics.mean([p['Value'] for p in cpu_data]),
                'max': max([p['Value'] for p in cpu_data]),
                'trend': self._calculate_trend([p['Value'] for p in cpu_data])
            }
        
        # メモリ使用率
        memory_data = self._get_metric_data(
            'MemoryUtilization', 'CWAgent', start_time, end_time, 'Average', 300
        )
        if memory_data:
            metrics['memory_utilization'] = {
                'average': statistics.mean([p['Value'] for p in memory_data]),
                'max': max([p['Value'] for p in memory_data])
            }
        
        return metrics
    
    def _collect_application_metrics(self, app_name: str, start_time: datetime, 
                                   end_time: datetime) -> Dict:
        """アプリケーションメトリクス収集"""
        metrics = {}
        
        # レスポンス時間
        response_time_data = self._get_metric_data(
            'ResponseTime', f'Application/{app_name}', start_time, end_time, 'Average', 300
        )
        if response_time_data:
            values = [p['Value'] for p in response_time_data]
            metrics['response_time'] = {
                'average': statistics.mean(values),
                'p95': np.percentile(values, 95),
                'p99': np.percentile(values, 99)
            }
        
        return metrics
    
    def _collect_business_metrics(self, app_name: str, start_time: datetime, 
                                end_time: datetime) -> Dict:
        """ビジネスメトリクス収集"""
        metrics = {}
        
        # トランザクション数
        transaction_data = self._get_metric_data(
            'TransactionCount', f'Business/{app_name}', start_time, end_time, 'Sum', 300
        )
        if transaction_data:
            metrics['transaction_count'] = sum([p['Value'] for p in transaction_data])
        
        return metrics
    
    def _get_metric_data(self, metric_name: str, namespace: str, 
                        start_time: datetime, end_time: datetime, 
                        statistic: str, period: int) -> List[Dict]:
        """メトリクスデータ取得"""
        try:
            response = self.cloudwatch.get_metric_statistics(
                Namespace=namespace,
                MetricName=metric_name,
                StartTime=start_time,
                EndTime=end_time,
                Period=period,
                Statistics=[statistic]
            )
            
            return response.get('Datapoints', [])
            
        except Exception as e:
            logger.error(f"Failed to get metric data: {e}")
            return []
    
    def _detect_anomalies_zscore(self, values: List[float], timestamps: List[datetime], 
                                threshold: float = 2.5) -> Dict:
        """Zスコア法による異常検知"""
        if len(values) < 3:
            return {'count': 0, 'anomalies': []}
        
        mean_val = statistics.mean(values)
        std_dev = statistics.stdev(values)
        
        anomalies = []
        for i, value in enumerate(values):
            if std_dev > 0:
                z_score = abs((value - mean_val) / std_dev)
                if z_score > threshold:
                    anomalies.append({
                        'timestamp': timestamps[i].isoformat(),
                        'value': value,
                        'z_score': z_score,
                        'severity': 'high' if z_score > 3 else 'medium'
                    })
        
        return {
            'count': len(anomalies),
            'anomalies': anomalies,
            'threshold': threshold
        }
    
    def _analyze_seasonality(self, values: List[float], timestamps: List[datetime]) -> Dict:
        """季節性分析"""
        # 簡易的な季節性検出
        if len(values) < 24:  # 最低24データポイント必要
            return {'detected': False, 'period': None}
        
        # 時間別の平均を計算
        hourly_avg = {}
        for i, ts in enumerate(timestamps):
            hour = ts.hour
            if hour not in hourly_avg:
                hourly_avg[hour] = []
            hourly_avg[hour].append(values[i])
        
        # 時間別平均の分散を計算
        hour_means = [statistics.mean(hourly_avg[h]) for h in sorted(hourly_avg.keys())]
        if len(hour_means) > 1:
            variance = statistics.variance(hour_means)
            overall_mean = statistics.mean(values)
            coefficient_of_variation = (statistics.stdev(hour_means) / overall_mean) if overall_mean > 0 else 0
            
            return {
                'detected': coefficient_of_variation > 0.1,  # 10%以上の変動で季節性あり
                'period': 24,  # 時間
                'coefficient_of_variation': coefficient_of_variation,
                'hourly_pattern': {str(h): statistics.mean(hourly_avg[h]) for h in sorted(hourly_avg.keys())}
            }
        
        return {'detected': False, 'period': None}
    
    def _analyze_trend(self, values: List[float], timestamps: List[datetime]) -> Dict:
        """トレンド分析"""
        if len(values) < 3:
            return {'direction': 'unknown', 'strength': 0}
        
        # 線形回帰による傾き計算
        x = list(range(len(values)))
        correlation = np.corrcoef(x, values)[0, 1] if len(values) > 1 else 0
        
        if correlation > 0.3:
            direction = 'increasing'
        elif correlation < -0.3:
            direction = 'decreasing'
        else:
            direction = 'stable'
        
        return {
            'direction': direction,
            'strength': abs(correlation),
            'correlation_coefficient': correlation
        }

def main():
    """メイン実行関数"""
    parser = argparse.ArgumentParser(description='Advanced CloudWatch Monitoring')
    parser.add_argument('--region', default='us-east-1', help='AWS Region')
    parser.add_argument('--config-file', required=True, help='Monitoring configuration file')
    parser.add_argument('--action', choices=['setup', 'analyze', 'report'], default='setup', help='Action to perform')
    parser.add_argument('--applications', nargs='+', help='Applications to monitor')
    
    args = parser.parse_args()
    
    # 設定ファイル読み込み
    with open(args.config_file, 'r', encoding='utf-8') as f:
        config = json.load(f)
    
    # 監視マネージャー初期化
    monitor = AdvancedCloudWatchMonitor(args.region)
    
    try:
        if args.action == 'setup':
            results = monitor.setup_enterprise_monitoring(config)
            print(f"Monitoring setup completed: {json.dumps(results, indent=2)}")
        
        elif args.action == 'analyze':
            if not args.applications:
                raise ValueError("Applications must be specified for analysis")
            
            analysis = monitor.collect_advanced_metrics(args.applications)
            print(f"Metrics analysis: {json.dumps(analysis, indent=2, default=str)}")
        
        elif args.action == 'report':
            report = monitor.generate_monitoring_report(config.get('report', {}))
            print(f"Monitoring report: {json.dumps(report, indent=2, default=str)}")
            
    except Exception as e:
        logger.error(f"Advanced monitoring operation failed: {e}")
        raise

if __name__ == "__main__":
    main()