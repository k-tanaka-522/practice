# 08-運用・監視・障害対応編

## 🚀 モジュール概要

**学習時間**: 12時間 | **レベル**: 上級 | **前提モジュール**: 06-07完了

このモジュールでは、エンタープライズ環境でのプロダクション運用に必要な包括的なSRE（Site Reliability Engineering）スキルを習得します。高可用性、障害対応、予防的監視、自動復旧、そしてAI駆動運用まで、現代的な運用の全領域をカバーします。

## 🎯 学習目標

### 主要スキル習得
- 🔍 **プロアクティブ監視**: 障害予測とアノマリー検知
- 🚨 **インシデント対応**: 組織的な障害対応プロセス
- 🤖 **自動修復**: AI/ML駆動の自動復旧システム
- 📈 **SLO/SLI管理**: 信頼性工学のベストプラクティス
- 💰 **運用コスト最適化**: FinOpsとリソース効率化
- 🔧 **Chaos Engineering**: 障害耐性テストと改善

## 🏗️ アーキテクチャ概要

```
┌─────────────────────────────────────────────────────────────────┐
│                    Observability Layer                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────┐ │
│  │  CloudWatch │  │    X-Ray    │  │   OpenTel   │  │ Grafana │ │
│  │  Synthetics │  │   Tracing   │  │  Collector  │  │ Prometheus │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                Incident Management Platform                    │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────┐ │
│  │ PagerDuty   │  │Event Bridge │  │   Slack     │  │ Jira    │ │
│  │Integration  │  │  Routing    │  │Notification │  │Service  │ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│               Automated Response System                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────┐ │
│  │Auto Scaling │  │ Lambda      │  │Systems      │  │Bedrock  │ │
│  │    &        │  │Remediation  │  │ Manager     │  │AI Ops   │ │
│  │  Healing    │  │  Functions  │  │Automation   │  │Assistant│ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## 📚 学習パス

### 8.1 プロアクティブ監視基盤（4時間）
- **8.1.1** [オブザーバビリティ実装](8.1-プロアクティブ監視基盤/8.1.1-オブザーバビリティ実装/README.md)
  - 統合監視ダッシュボード
  - カスタムメトリクス設計
  - 分散トレーシング
- **8.1.2** [アノマリー検知とアラート](8.1-プロアクティブ監視基盤/8.1.2-アノマリー検知とアラート/README.md)
  - AI/ML異常検知
  - 予測的アラート
  - スマートノイズリダクション

### 8.2 インシデント対応・SRE実践（4時間）
- **8.2.1** [インシデント管理システム](8.2-インシデント対応・SRE実践/8.2.1-インシデント管理システム/README.md)
  - PagerDuty/Slack統合
  - エスカレーション管理
  - ポストモーテム自動化
- **8.2.2** [SLO/SLI実装](8.2-インシデント対応・SRE実践/8.2.2-SLO-SLI実装/README.md)
  - エラーバジェット管理
  - 信頼性ターゲット設定
  - SRE文化の浸透

### 8.3 自動修復・AI駆動運用（4時間）
- **8.3.1** [自動修復システム](8.3-自動修復・AI駆動運用/8.3.1-自動修復システム/README.md)
  - Lambda自動修復
  - Systems Manager自動化
  - Chaos Engineeringテスト
- **8.3.2** [AI運用アシスタント](8.3-自動修復・AI駆動運用/8.3.2-AI運用アシスタント/README.md)
  - Bedrockによるログ分析
  - 自動レコメンデーション
  - 予防的メンテナンス

## 🚀 前提条件

### 必須要件
- ✅ **モジュール06-07完了**: CI/CDとAI駆動開発の理解
- ✅ **プロダクション経験**: 実際の本番環境運用経験推奨
- ✅ **監視ツール理解**: CloudWatch、Grafana等の基本操作
- ✅ **AWS権限**: CloudWatch、EventBridge、Systems Manager等のフルアクセス

### 推奨知識
- Linux/Unixシステム管理経験
- ネットワーク・セキュリティ基礎知識
- データベース運用経験
- 障害対応経験

## 🏗️ 実装手順

### Step 1: 統合監視基盤構築

```bash
# OpenTelemetry Collector設定
cat > otel-collector-config.yaml << EOF
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318
  awsxray:
    endpoint: 0.0.0.0:2000
    transport: udp

processors:
  batch:
  memory_limiter:
    limit_mib: 512

exporters:
  awsxray:
  awscloudwatchmetrics:
    namespace: 'CWAgent'
    region: 'ap-northeast-1'
  awscloudwatchlogs:
    log_group_name: '/aws/otel/collector'
    region: 'ap-northeast-1'

service:
  pipelines:
    traces:
      receivers: [otlp, awsxray]
      processors: [memory_limiter, batch]
      exporters: [awsxray]
    metrics:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [awscloudwatchmetrics]
    logs:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [awscloudwatchlogs]
EOF

# 統合監視スタック作成
aws cloudformation create-stack \
  --stack-name comprehensive-observability \
  --template-body file://08-運用・監視・障害対応編/8.1-プロアクティブ監視基盤/8.1.1-オブザーバビリティ実装/cloudformation/comprehensive-observability.yaml \
  --parameters ParameterKey=ApplicationName,ParameterValue=enterprise-app \
               ParameterKey=Environment,ParameterValue=production \
  --capabilities CAPABILITY_NAMED_IAM
```

### Step 2: AI駆動アノマリー検知

```bash
# アノマリー検知システム作成
aws cloudformation create-stack \
  --stack-name ai-anomaly-detection \
  --template-body file://08-運用・監視・障害対応編/8.1-プロアクティブ監視基盤/8.1.2-アノマリー検知とアラート/cloudformation/ai-anomaly-detection.yaml \
  --parameters ParameterKey=NotificationEmail,ParameterValue=sre-team@company.com \
               ParameterKey=SlackWebhookUrl,ParameterValue=https://hooks.slack.com/... \
  --capabilities CAPABILITY_NAMED_IAM
```

### Step 3: インシデント管理プラットフォーム

```bash
# PagerDuty統合とインシデント管理
aws cloudformation create-stack \
  --stack-name incident-management \
  --template-body file://08-運用・監視・障害対応編/8.2-インシデント対応・SRE実践/8.2.1-インシデント管理システム/cloudformation/incident-management.yaml \
  --parameters ParameterKey=PagerDutyRoutingKey,ParameterValue=your-routing-key \
               ParameterKey=JiraApiToken,ParameterValue=your-jira-token \
  --capabilities CAPABILITY_NAMED_IAM
```

### Step 4: SLO/SLI監視システム

```bash
# SLO/SLI追跡システム構築
aws cloudformation create-stack \
  --stack-name slo-sli-monitoring \
  --template-body file://08-運用・監視・障害対応編/8.2-インシデント対応・SRE実践/8.2.2-SLO-SLI実装/cloudformation/slo-sli-monitoring.yaml \
  --parameters ParameterKey=AvailabilitySLO,ParameterValue=99.9 \
               ParameterKey=LatencySLO,ParameterValue=500 \
  --capabilities CAPABILITY_NAMED_IAM
```

### Step 5: 自動修復システム

```bash
# 自動修復ランブック実装
aws cloudformation create-stack \
  --stack-name auto-remediation \
  --template-body file://08-運用・監視・障害対応編/8.3-自動修復・AI駆動運用/8.3.1-自動修復システム/cloudformation/auto-remediation.yaml \
  --parameters ParameterKey=AutoApprovalThreshold,ParameterValue=HIGH \
  --capabilities CAPABILITY_NAMED_IAM
```

### Step 6: AI運用アシスタント

```bash
# Bedrock運用AI導入
aws cloudformation create-stack \
  --stack-name ai-ops-assistant \
  --template-body file://08-運用・監視・障害対応編/8.3-自動修復・AI駆動運用/8.3.2-AI運用アシスタント/cloudformation/ai-ops-assistant.yaml \
  --parameters ParameterKey=BedrockModel,ParameterValue=claude-3-sonnet \
  --capabilities CAPABILITY_NAMED_IAM
```

## 📋 実装例とテンプレート

### SLO/SLI定義例

```yaml
# SLO定義 (Service Level Objectives)
ServiceLevelObjectives:
  Availability:
    Target: 99.9%
    Window: monthly
    ErrorBudget: 0.1%
    
  Latency:
    Target: 95th percentile < 500ms
    Window: weekly
    ErrorBudget: 5%
    
  Throughput:
    Target: "> 1000 requests/second"
    Window: daily
    
  ErrorRate:
    Target: "< 0.1%"
    Window: hourly
    ErrorBudget: 0.1%

# SLI実装 (Service Level Indicators)
ServiceLevelIndicators:
  - Name: "HTTP Availability"
    Query: |
      (
        sum(rate(http_requests_total{status!~"5.."}[5m])) /
        sum(rate(http_requests_total[5m]))
      ) * 100
    Threshold: 99.9
    
  - Name: "Response Time P95"
    Query: |
      histogram_quantile(0.95, 
        sum(rate(http_request_duration_seconds_bucket[5m])) by (le)
      ) * 1000
    Threshold: 500
    
  - Name: "Error Rate"
    Query: |
      (
        sum(rate(http_requests_total{status=~"5.."}[5m])) /
        sum(rate(http_requests_total[5m]))
      ) * 100
    Threshold: 0.1
```

### インシデント対応ランブック

```python
# Lambda関数による自動インシデント対応
import boto3
import json
import os
from datetime import datetime, timedelta

def incident_response_handler(event, context):
    """
    統合インシデント対応システム
    - 自動診断とトリアージ
    - ステークホルダー通知
    - 初期修復アクション
    - エスカレーション管理
    """
    
    try:
        # イベント分析
        incident = analyze_incident(event)
        
        # 重要度判定
        severity = classify_severity(incident)
        
        # 自動診断実行
        diagnosis = run_automated_diagnosis(incident)
        
        # 通知とエスカレーション
        notify_stakeholders(incident, severity, diagnosis)
        
        # 自動修復試行
        if severity in ['LOW', 'MEDIUM']:
            auto_remediation_result = attempt_auto_remediation(incident)
        
        # インシデント追跡開始
        track_incident(incident, severity, diagnosis)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'incident_id': incident['id'],
                'severity': severity,
                'auto_remediation': auto_remediation_result if 'auto_remediation_result' in locals() else None
            })
        }
        
    except Exception as e:
        # フォールバック通知
        send_emergency_notification(str(e))
        return {'statusCode': 500, 'body': str(e)}

def analyze_incident(event):
    """インシデント分析とコンテキスト抽出"""
    return {
        'id': generate_incident_id(),
        'timestamp': datetime.utcnow().isoformat(),
        'source': event.get('source', 'unknown'),
        'alarm_name': event.get('AlarmName', ''),
        'metric_data': extract_metric_data(event),
        'affected_services': identify_affected_services(event),
        'customer_impact': assess_customer_impact(event)
    }

def classify_severity(incident):
    """AI/ルールベース重要度分類"""
    
    # カスタマー影響度
    if incident['customer_impact']['severity'] == 'CRITICAL':
        return 'CRITICAL'
    
    # サービス可用性
    if 'availability' in incident['alarm_name'].lower():
        if incident['metric_data']['current_value'] < 95:
            return 'HIGH'
        elif incident['metric_data']['current_value'] < 99:
            return 'MEDIUM'
    
    # レスポンス時間
    if 'latency' in incident['alarm_name'].lower():
        if incident['metric_data']['current_value'] > 5000:  # 5秒
            return 'HIGH'
        elif incident['metric_data']['current_value'] > 1000:  # 1秒
            return 'MEDIUM'
    
    return 'LOW'

def run_automated_diagnosis(incident):
    """自動診断とルートコーズ分析"""
    
    diagnosis = {
        'health_checks': run_health_checks(incident['affected_services']),
        'resource_utilization': check_resource_utilization(),
        'network_connectivity': test_network_connectivity(),
        'dependency_status': check_dependencies(),
        'recent_deployments': check_recent_deployments(),
        'log_analysis': analyze_error_logs(incident)
    }
    
    # AI分析でパターン検出
    if os.environ.get('ENABLE_AI_DIAGNOSIS') == 'true':
        diagnosis['ai_insights'] = get_ai_insights(incident, diagnosis)
    
    return diagnosis

def attempt_auto_remediation(incident):
    """自動修復アクション"""
    
    remediation_actions = []
    
    # EC2インスタンス問題
    if 'ec2' in incident['affected_services']:
        remediation_actions.extend(remediate_ec2_issues())
    
    # RDS問題
    if 'rds' in incident['affected_services']:
        remediation_actions.extend(remediate_rds_issues())
    
    # Lambda問題
    if 'lambda' in incident['affected_services']:
        remediation_actions.extend(remediate_lambda_issues())
    
    # Auto Scaling調整
    if 'high_cpu' in incident['alarm_name'].lower():
        remediation_actions.extend(scale_out_resources())
    
    return {
        'actions_taken': remediation_actions,
        'success_rate': calculate_success_rate(remediation_actions),
        'follow_up_required': any(action['status'] == 'FAILED' for action in remediation_actions)
    }

def notify_stakeholders(incident, severity, diagnosis):
    """ステークホルダー通知"""
    
    # Slack通知
    slack_message = format_slack_message(incident, severity, diagnosis)
    send_slack_notification(slack_message)
    
    # PagerDuty連携
    if severity in ['CRITICAL', 'HIGH']:
        trigger_pagerduty_alert(incident, severity)
    
    # Jiraチケット作成
    if severity in ['CRITICAL', 'HIGH', 'MEDIUM']:
        create_jira_ticket(incident, severity, diagnosis)
    
    # 経営層エスカレーション
    if severity == 'CRITICAL':
        notify_executives(incident)

def get_ai_insights(incident, diagnosis):
    """BedrockによるAI分析"""
    
    bedrock = boto3.client('bedrock-runtime')
    
    prompt = f"""
    以下のインシデント情報を分析し、根本原因と推奨アクションを提供してください：

    インシデント: {incident}
    診断結果: {diagnosis}

    分析項目：
    1. 最も可能性の高い根本原因
    2. 推奨される修復アクション
    3. 再発防止策
    4. 類似の過去インシデント
    """
    
    response = bedrock.invoke_model(
        modelId='anthropic.claude-3-sonnet-20240229-v1:0',
        body=json.dumps({
            'anthropic_version': 'bedrock-2023-05-31',
            'max_tokens': 1000,
            'messages': [{'role': 'user', 'content': prompt}]
        })
    )
    
    return json.loads(response['body'].read())['content'][0]['text']

def format_slack_message(incident, severity, diagnosis):
    """Slack通知フォーマット"""
    
    color_map = {
        'CRITICAL': '#ff0000',
        'HIGH': '#ff8800',
        'MEDIUM': '#ffcc00',
        'LOW': '#00ff00'
    }
    
    return {
        'attachments': [{
            'color': color_map[severity],
            'title': f"🚨 {severity} Incident: {incident['alarm_name']}",
            'fields': [
                {'title': 'Incident ID', 'value': incident['id'], 'short': True},
                {'title': 'Affected Services', 'value': ', '.join(incident['affected_services']), 'short': True},
                {'title': 'Customer Impact', 'value': incident['customer_impact']['description'], 'short': False},
                {'title': 'Health Status', 'value': diagnosis['health_checks']['summary'], 'short': False}
            ],
            'actions': [
                {'type': 'button', 'text': 'View Dashboard', 'url': f"https://console.aws.amazon.com/cloudwatch/home#dashboards:name={incident['id']}"},
                {'type': 'button', 'text': 'Join War Room', 'url': f"https://company.slack.com/channels/incident-{incident['id']}"}
            ]
        }]
    }
```

### Chaos Engineeringテスト

```python
# カオスエンジニアリング自動テスト
import boto3
import random
import time
from datetime import datetime, timedelta

class ChaosExperiments:
    def __init__(self):
        self.ec2 = boto3.client('ec2')
        self.elbv2 = boto3.client('elbv2')
        self.cloudwatch = boto3.client('cloudwatch')
        
    def chaos_monkey_experiment(self):
        """ランダムEC2インスタンス停止実験"""
        
        # テスト対象インスタンス取得
        instances = self.get_chaos_test_instances()
        
        if not instances:
            return {'error': 'No test instances found'}
        
        # ランダム選択
        target_instance = random.choice(instances)
        
        # ベースライン測定
        baseline_metrics = self.measure_baseline_metrics()
        
        # 停止実験実行
        print(f"Stopping instance: {target_instance['InstanceId']}")
        self.ec2.stop_instances(InstanceIds=[target_instance['InstanceId']])
        
        # 影響測定
        time.sleep(300)  # 5分間観測
        impact_metrics = self.measure_impact_metrics()
        
        # インスタンス復旧
        print(f"Starting instance: {target_instance['InstanceId']}")
        self.ec2.start_instances(InstanceIds=[target_instance['InstanceId']])
        
        # 復旧測定
        time.sleep(300)  # 5分間観測
        recovery_metrics = self.measure_recovery_metrics()
        
        return {
            'experiment': 'chaos_monkey',
            'target': target_instance['InstanceId'],
            'baseline': baseline_metrics,
            'impact': impact_metrics,
            'recovery': recovery_metrics,
            'resilience_score': self.calculate_resilience_score(baseline_metrics, impact_metrics, recovery_metrics)
        }
    
    def network_latency_experiment(self):
        """ネットワーク遅延注入実験"""
        
        # Systems Manager経由でネットワーク遅延注入
        ssm = boto3.client('ssm')
        
        # 遅延注入
        response = ssm.send_command(
            InstanceIds=self.get_test_instance_ids(),
            DocumentName='AWS-RunShellScript',
            Parameters={
                'commands': [
                    'sudo tc qdisc add dev eth0 root netem delay 100ms',
                    'sleep 300',  # 5分間遅延維持
                    'sudo tc qdisc del dev eth0 root netem'
                ]
            }
        )
        
        return {'experiment': 'network_latency', 'command_id': response['Command']['CommandId']}
    
    def database_failover_experiment(self):
        """RDS多可用性域フェイルオーバーテスト"""
        
        rds = boto3.client('rds')
        
        # Multi-AZ RDSインスタンス取得
        db_instances = rds.describe_db_instances()
        multi_az_instances = [
            db for db in db_instances['DBInstances']
            if db['MultiAZ'] and 'test' in db['DBInstanceIdentifier']
        ]
        
        if not multi_az_instances:
            return {'error': 'No Multi-AZ test instances found'}
        
        target_db = multi_az_instances[0]
        
        # ベースライン接続テスト
        baseline_connectivity = self.test_database_connectivity(target_db['Endpoint']['Address'])
        
        # フェイルオーバー実行
        rds.reboot_db_instance(
            DBInstanceIdentifier=target_db['DBInstanceIdentifier'],
            ForceFailover=True
        )
        
        # フェイルオーバー時間測定
        failover_start = datetime.utcnow()
        
        # 接続復旧まで監視
        while True:
            time.sleep(30)
            connectivity = self.test_database_connectivity(target_db['Endpoint']['Address'])
            if connectivity['status'] == 'connected':
                failover_end = datetime.utcnow()
                break
            
            if (datetime.utcnow() - failover_start).seconds > 600:  # 10分でタイムアウト
                break
        
        failover_duration = (failover_end - failover_start).seconds
        
        return {
            'experiment': 'database_failover',
            'target': target_db['DBInstanceIdentifier'],
            'baseline_connectivity': baseline_connectivity,
            'failover_duration_seconds': failover_duration,
            'rto_target_met': failover_duration < 120  # 2分以内のRTO目標
        }

    def calculate_resilience_score(self, baseline, impact, recovery):
        """回復力スコア計算"""
        
        # 可用性影響度 (0-100)
        availability_impact = max(0, 100 - (impact['error_rate'] - baseline['error_rate']) * 10)
        
        # 復旧時間スコア (0-100)
        recovery_time_score = max(0, 100 - recovery['time_to_recovery'] / 60)  # 分単位
        
        # 全体回復力スコア
        resilience_score = (availability_impact + recovery_time_score) / 2
        
        return {
            'overall_score': resilience_score,
            'availability_impact': availability_impact,
            'recovery_time_score': recovery_time_score,
            'recommendation': self.get_resilience_recommendation(resilience_score)
        }
```

## 🔗 モジュール統合

### 他モジュールとの連携
- **モジュール02-05**: 全アプリケーションの統合監視
- **モジュール06**: CI/CDパイプラインの監視とアラート
- **モジュール07**: AI駆動の障害予測と対応

### エンタープライズ統合
- オンプレミス環境との混合監視
- マルチクラウド環境対応
- レガシーシステム統合

## 📈 成果測定とKPI

### SRE成熟度メトリクス

```yaml
SRE_Maturity_Metrics:
  Reliability:
    - MTTR: "< 30 minutes"
    - MTBF: "> 30 days"
    - Availability: "> 99.9%"
    - Error_Budget_Utilization: "< 80%"
    
  Operational_Excellence:
    - Automated_Remediation_Rate: "> 70%"
    - Alert_Noise_Ratio: "< 5%"
    - Runbook_Coverage: "> 90%"
    - Chaos_Engineering_Coverage: "> 50%"
    
  Business_Impact:
    - Customer_Satisfaction_Score: "> 4.5/5"
    - Revenue_Impact_Reduction: "> 50%"
    - Operational_Cost_Optimization: "> 20%"
    - Team_Productivity_Increase: "> 30%"
```

## 🎯 実践演習

### 演習1: インシデント対応シミュレーション
1. 意図的な障害注入
2. アラート検証
3. 対応プロセス実行
4. ポストモーテム作成

### 演習2: SLO/SLI設計
1. ビジネス要件分析
2. SLI定義と実装
3. SLO設定と監視
4. エラーバジェット管理

### 演習3: Chaos Engineering
1. 実験設計
2. 仮説設定
3. 実験実行
4. 結果分析と改善

## 📚 参考資料

### 必読書籍
- 「Site Reliability Engineering」- Google
- 「The Site Reliability Workbook」- Google
- 「Database Reliability Engineering」- O'Reilly
- 「Chaos Engineering」- O'Reilly

### 認定資格
- AWS Solutions Architect Professional
- AWS DevOps Engineer Professional
- Certified Kubernetes Administrator (CKA)
- Site Reliability Engineering Certificate

## 🏁 モジュール完了基準

### 基礎レベル
- [ ] 基本監視ダッシュボード構築
- [ ] アラート設定と通知
- [ ] インシデント対応プロセス理解
- [ ] 基本的なSLO/SLI設定

### 中級レベル
- [ ] 自動修復システム実装
- [ ] 分散トレーシング統合
- [ ] カスタムメトリクス設計
- [ ] Chaos Engineering実験

### 上級レベル
- [ ] AI駆動異常検知
- [ ] エンタープライズ監視統合
- [ ] SRE文化浸透
- [ ] 運用コスト20%削減達成

---

<div align="center">

**🚀 SREマスターへの道 - 信頼性の追求は永続的な旅 🚀**

[![Next Module](https://img.shields.io/badge/Complete-全8モジュール完了-green?style=for-the-badge)](#)
[![Previous Module](https://img.shields.io/badge/Previous-07--AI駆動開発編-blue?style=for-the-badge)](../07-Claude-Code-Bedrock-AI駆動開発編/README.md)

</div>