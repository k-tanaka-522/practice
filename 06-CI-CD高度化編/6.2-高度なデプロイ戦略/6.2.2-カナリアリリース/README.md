# 6.2.2 カナリアリリース

## 概要

カナリアリリースは、新しいバージョンを少数のユーザーまたはトラフィックに対して段階的に展開し、リスクを最小化しながら安全にリリースを行う手法です。このセクションでは、AWS Lambda、API Gateway、CloudFrontを使用したカナリアリリースを実装します。

## 学習目標

- ✅ カナリアデプロイメント戦略の理解
- ✅ Lambda Aliasとバージョニング
- ✅ API Gatewayステージ管理
- ✅ CloudFrontでの段階的配信
- ✅ メトリクスベースの自動判定
- ✅ フィーチャーフラグとの連携

## アーキテクチャ

```
┌─────────────────────────────────────────────────────────────────┐
│                      CloudFront                                 │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │              Origin Request Policy                           ││
│  │   ┌─────────────────┐       ┌─────────────────┐           ││
│  │   │   90% Traffic   │       │   10% Traffic   │           ││
│  │   │   (Stable)      │       │   (Canary)      │           ││
│  │   └─────────────────┘       └─────────────────┘           ││
│  └─────────────────────────────────────────────────────────────┘│
└──────────────────────┬──────────────────────┬───────────────────┘
                       │                      │
                       ▼                      ▼
┌──────────────────────────┐         ┌──────────────────────────┐
│     API Gateway          │         │     API Gateway          │
│      (Production)        │         │       (Canary)           │
│  ┌────────────────────┐  │         │  ┌────────────────────┐  │
│  │   Lambda Alias     │  │         │  │   Lambda Alias     │  │
│  │     (stable)       │  │         │  │     (canary)       │  │
│  │  ┌──────────────┐  │  │         │  │  ┌──────────────┐  │  │
│  │  │ Function v1  │  │  │         │  │  │ Function v2  │  │  │
│  │  │   Weight:90% │  │  │         │  │  │  Weight:10% │  │  │
│  │  └──────────────┘  │  │         │  │  └──────────────┘  │  │
│  └────────────────────┘  │         │  └────────────────────┘  │
└──────────────────────────┘         └──────────────────────────┘
```

## 実装戦略

### 1. Lambda ベースのカナリアリリース

#### Lambda Aliasによる重み付けルーティング

```yaml
# lambda-canary-config.yaml
LambdaAlias:
  Type: AWS::Lambda::Alias
  Properties:
    FunctionName: !Ref MyFunction
    FunctionVersion: !GetAtt MyFunctionVersion.Version
    Name: live
    RoutingConfig:
      AdditionalVersionWeights:
        - FunctionVersion: !GetAtt MyFunctionVersion.Version
          FunctionWeight: 0.1  # 10%のトラフィックを新バージョンに
    ProvisionedConcurrencyConfig:
      - AllocatedConcurrency: 50
        FunctionVersion: !GetAtt MyFunctionVersion.Version
```

#### 段階的重み付け調整

```python
# canary-deployment.py
import boto3
import time
import json

class CanaryDeployment:
    def __init__(self, function_name, alias_name='live'):
        self.lambda_client = boto3.client('lambda')
        self.cloudwatch = boto3.client('cloudwatch')
        self.function_name = function_name
        self.alias_name = alias_name
        
    def deploy_canary(self, new_version, target_weights=[0.1, 0.25, 0.5, 1.0], 
                      wait_time=300, success_threshold=0.99):
        """
        段階的カナリアデプロイメント
        """
        for weight in target_weights:
            print(f"Setting canary weight to {weight*100}%...")
            
            # Alias更新
            self.lambda_client.update_alias(
                FunctionName=self.function_name,
                Name=self.alias_name,
                FunctionVersion=new_version,
                RoutingConfig={
                    'AdditionalVersionWeights': {
                        new_version: weight
                    }
                }
            )
            
            # メトリクス監視期間
            time.sleep(wait_time)
            
            # 成功率チェック
            success_rate = self._get_success_rate(new_version, wait_time)
            
            if success_rate < success_threshold:
                print(f"Success rate {success_rate} below threshold {success_threshold}")
                self._rollback()
                return False
                
            print(f"Success rate: {success_rate} - Continuing deployment")
        
        print("Canary deployment completed successfully!")
        return True
    
    def _get_success_rate(self, version, period):
        """
        指定バージョンの成功率を取得
        """
        end_time = time.time()
        start_time = end_time - period
        
        # エラー数取得
        errors = self.cloudwatch.get_metric_statistics(
            Namespace='AWS/Lambda',
            MetricName='Errors',
            Dimensions=[
                {'Name': 'FunctionName', 'Value': self.function_name},
                {'Name': 'Version', 'Value': version}
            ],
            StartTime=start_time,
            EndTime=end_time,
            Period=period,
            Statistics=['Sum']
        )
        
        # 実行数取得
        invocations = self.cloudwatch.get_metric_statistics(
            Namespace='AWS/Lambda',
            MetricName='Invocations',
            Dimensions=[
                {'Name': 'FunctionName', 'Value': self.function_name},
                {'Name': 'Version', 'Value': version}
            ],
            StartTime=start_time,
            EndTime=end_time,
            Period=period,
            Statistics=['Sum']
        )
        
        error_count = errors['Datapoints'][0]['Sum'] if errors['Datapoints'] else 0
        invocation_count = invocations['Datapoints'][0]['Sum'] if invocations['Datapoints'] else 0
        
        if invocation_count == 0:
            return 1.0
            
        return (invocation_count - error_count) / invocation_count
    
    def _rollback(self):
        """
        ロールバック実行
        """
        print("Rolling back to stable version...")
        self.lambda_client.update_alias(
            FunctionName=self.function_name,
            Name=self.alias_name,
            RoutingConfig={}  # 全トラフィックを安定版に戻す
        )
```

### 2. API Gateway ステージベースカナリア

```python
# api-gateway-canary.py
import boto3

def setup_api_gateway_canary(api_id, stage_name, deployment_id, canary_percentage=10):
    """
    API Gatewayでのカナリアデプロイメント設定
    """
    client = boto3.client('apigateway')
    
    # カナリア設定でステージ更新
    response = client.update_stage(
        restApiId=api_id,
        stageName=stage_name,
        patchOps=[
            {
                'op': 'replace',
                'path': '/deploymentId',
                'value': deployment_id
            },
            {
                'op': 'replace',
                'path': '/canarySettings/percentTraffic',
                'value': str(canary_percentage)
            },
            {
                'op': 'replace',
                'path': '/canarySettings/deploymentId',
                'value': deployment_id
            },
            {
                'op': 'replace',
                'path': '/canarySettings/useStageCache',
                'value': 'false'
            }
        ]
    )
    
    return response

def promote_canary(api_id, stage_name):
    """
    カナリアを本番に昇格
    """
    client = boto3.client('apigateway')
    
    response = client.update_stage(
        restApiId=api_id,
        stageName=stage_name,
        patchOps=[
            {
                'op': 'remove',
                'path': '/canarySettings'
            }
        ]
    )
    
    return response
```

### 3. CloudFront + Lambda@Edge カナリア

```javascript
// edge-canary-function.js
'use strict';

const CANARY_PERCENTAGE = 10; // 10%のトラフィックをカナリアに

exports.handler = (event, context, callback) => {
    const request = event.Records[0].cf.request;
    const headers = request.headers;
    
    // ユーザーエージェントやその他の属性でカナリア対象を決定
    const canaryHash = hashCode(headers['cloudfront-viewer-address'][0].value);
    const isCanary = (canaryHash % 100) < CANARY_PERCENTAGE;
    
    if (isCanary) {
        // カナリア環境にルーティング
        request.origin = {
            custom: {
                domainName: 'canary-api.example.com',
                port: 443,
                protocol: 'https',
                path: '/canary'
            }
        };
        
        // カナリアフラグヘッダー追加
        request.headers['x-canary-deployment'] = [{
            key: 'X-Canary-Deployment',
            value: 'true'
        }];
    } else {
        // 安定版環境にルーティング
        request.origin = {
            custom: {
                domainName: 'stable-api.example.com',
                port: 443,
                protocol: 'https',
                path: '/stable'
            }
        };
    }
    
    callback(null, request);
};

function hashCode(str) {
    let hash = 0;
    for (let i = 0; i < str.length; i++) {
        const char = str.charCodeAt(i);
        hash = ((hash << 5) - hash) + char;
        hash = hash & hash; // 32bit整数に変換
    }
    return Math.abs(hash);
}
```

### 4. フィーチャーフラグ連携

```python
# feature-flag-canary.py
import boto3
import json

class FeatureFlagCanary:
    def __init__(self, table_name='feature-flags'):
        self.dynamodb = boto3.resource('dynamodb')
        self.table = self.dynamodb.Table(table_name)
        
    def set_canary_flag(self, feature_name, canary_percentage, criteria=None):
        """
        フィーチャーフラグでカナリア制御
        """
        flag_config = {
            'feature_name': feature_name,
            'enabled': True,
            'canary_percentage': canary_percentage,
            'criteria': criteria or {},
            'rollout_strategy': 'canary',
            'created_at': int(time.time())
        }
        
        self.table.put_item(Item=flag_config)
        
    def should_use_canary(self, feature_name, user_context):
        """
        ユーザーがカナリア対象かどうか判定
        """
        try:
            response = self.table.get_item(
                Key={'feature_name': feature_name}
            )
            
            if 'Item' not in response:
                return False
                
            flag = response['Item']
            
            if not flag.get('enabled', False):
                return False
                
            # ユーザーベース判定
            if 'user_id' in user_context:
                user_hash = hash(user_context['user_id']) % 100
                return user_hash < flag.get('canary_percentage', 0)
                
            # その他の基準
            criteria = flag.get('criteria', {})
            if criteria.get('region') and user_context.get('region') in criteria['region']:
                return True
                
            return False
            
        except Exception as e:
            print(f"Error checking feature flag: {e}")
            return False
```

## 監視とメトリクス

### カスタムメトリクス実装

```python
# canary-metrics.py
import boto3
from datetime import datetime, timedelta

class CanaryMetrics:
    def __init__(self):
        self.cloudwatch = boto3.client('cloudwatch')
        
    def send_deployment_metrics(self, version, environment, metrics):
        """
        カナリアデプロイメントメトリクス送信
        """
        metric_data = []
        
        for metric_name, value in metrics.items():
            metric_data.append({
                'MetricName': metric_name,
                'Value': value,
                'Unit': 'Count',
                'Dimensions': [
                    {'Name': 'Version', 'Value': version},
                    {'Name': 'Environment', 'Value': environment},
                    {'Name': 'DeploymentType', 'Value': 'canary'}
                ],
                'Timestamp': datetime.utcnow()
            })
        
        self.cloudwatch.put_metric_data(
            Namespace='CanaryDeployment',
            MetricData=metric_data
        )
    
    def get_canary_comparison(self, stable_version, canary_version, metric_name, period_minutes=30):
        """
        安定版とカナリア版のメトリクス比較
        """
        end_time = datetime.utcnow()
        start_time = end_time - timedelta(minutes=period_minutes)
        
        # 安定版メトリクス
        stable_metrics = self.cloudwatch.get_metric_statistics(
            Namespace='AWS/Lambda',
            MetricName=metric_name,
            Dimensions=[
                {'Name': 'FunctionName', 'Value': 'my-function'},
                {'Name': 'Version', 'Value': stable_version}
            ],
            StartTime=start_time,
            EndTime=end_time,
            Period=300,
            Statistics=['Average', 'Sum']
        )
        
        # カナリア版メトリクス
        canary_metrics = self.cloudwatch.get_metric_statistics(
            Namespace='AWS/Lambda',
            MetricName=metric_name,
            Dimensions=[
                {'Name': 'FunctionName', 'Value': 'my-function'},
                {'Name': 'Version', 'Value': canary_version}
            ],
            StartTime=start_time,
            EndTime=end_time,
            Period=300,
            Statistics=['Average', 'Sum']
        )
        
        return {
            'stable': stable_metrics,
            'canary': canary_metrics,
            'comparison_period': period_minutes
        }
```

## 自動化されたカナリア制御

### CloudWatch アラームベース制御

```yaml
# canary-alarms.yaml
CanaryErrorRateAlarm:
  Type: AWS::CloudWatch::Alarm
  Properties:
    AlarmName: !Sub '${ApplicationName}-canary-high-error-rate'
    AlarmDescription: 'Canary version has high error rate'
    MetricName: ErrorRate
    Namespace: 'AWS/Lambda'
    Statistic: Average
    Period: 300
    EvaluationPeriods: 2
    Threshold: 0.05  # 5% エラー率
    ComparisonOperator: GreaterThanThreshold
    Dimensions:
      - Name: FunctionName
        Value: !Ref MyFunction
      - Name: Version
        Value: !Ref CanaryVersion
    AlarmActions:
      - !Ref CanaryRollbackTopic

CanaryLatencyAlarm:
  Type: AWS::CloudWatch::Alarm
  Properties:
    AlarmName: !Sub '${ApplicationName}-canary-high-latency'
    AlarmDescription: 'Canary version has high latency'
    MetricName: Duration
    Namespace: 'AWS/Lambda'
    Statistic: Average
    Period: 300
    EvaluationPeriods: 2
    Threshold: 5000  # 5秒
    ComparisonOperator: GreaterThanThreshold
    Dimensions:
      - Name: FunctionName
        Value: !Ref MyFunction
      - Name: Version
        Value: !Ref CanaryVersion
    AlarmActions:
      - !Ref CanaryRollbackTopic
```

### 自動ロールバック Lambda

```python
# auto-rollback-lambda.py
import boto3
import json

def lambda_handler(event, context):
    """
    CloudWatch アラームトリガーによる自動ロールバック
    """
    lambda_client = boto3.client('lambda')
    
    # SNSメッセージからアラーム情報解析
    message = json.loads(event['Records'][0]['Sns']['Message'])
    alarm_name = message['AlarmName']
    
    if 'canary' in alarm_name.lower():
        function_name = extract_function_name(alarm_name)
        
        # カナリアデプロイメントロールバック
        try:
            lambda_client.update_alias(
                FunctionName=function_name,
                Name='live',
                RoutingConfig={}  # カナリア重み付けを削除
            )
            
            # 通知送信
            send_notification(f"Canary deployment rolled back for {function_name} due to alarm: {alarm_name}")
            
        except Exception as e:
            print(f"Rollback failed: {str(e)}")
            raise
    
    return {
        'statusCode': 200,
        'body': 'Rollback completed'
    }

def extract_function_name(alarm_name):
    # アラーム名から関数名を抽出
    return alarm_name.split('-')[0]

def send_notification(message):
    sns = boto3.client('sns')
    sns.publish(
        TopicArn='arn:aws:sns:region:account:canary-notifications',
        Message=message,
        Subject='Canary Deployment Rollback'
    )
```

## A/Bテストとの統合

### A/Bテスト実装

```python
# ab-test-canary.py
import random
import boto3
import json

class ABTestCanary:
    def __init__(self):
        self.cloudwatch = boto3.client('cloudwatch')
        
    def assign_variant(self, user_id, experiment_name, variants=['control', 'treatment']):
        """
        ユーザーを実験グループに割り当て
        """
        # 一貫したハッシュベース割り当て
        hash_input = f"{user_id}-{experiment_name}"
        user_hash = hash(hash_input) % 100
        
        # 50/50分割（カスタマイズ可能）
        if user_hash < 50:
            return 'control'
        else:
            return 'treatment'
    
    def track_conversion(self, user_id, experiment_name, variant, event_type, value=1):
        """
        コンバージョンイベントを追跡
        """
        self.cloudwatch.put_metric_data(
            Namespace='ABTest',
            MetricData=[
                {
                    'MetricName': event_type,
                    'Value': value,
                    'Unit': 'Count',
                    'Dimensions': [
                        {'Name': 'Experiment', 'Value': experiment_name},
                        {'Name': 'Variant', 'Value': variant},
                        {'Name': 'UserId', 'Value': user_id}
                    ]
                }
            ]
        )
    
    def get_experiment_results(self, experiment_name, start_time, end_time):
        """
        実験結果の統計取得
        """
        variants = ['control', 'treatment']
        results = {}
        
        for variant in variants:
            metrics = self.cloudwatch.get_metric_statistics(
                Namespace='ABTest',
                MetricName='conversion',
                Dimensions=[
                    {'Name': 'Experiment', 'Value': experiment_name},
                    {'Name': 'Variant', 'Value': variant}
                ],
                StartTime=start_time,
                EndTime=end_time,
                Period=3600,
                Statistics=['Sum']
            )
            
            results[variant] = metrics
            
        return results
```

## ベストプラクティス

### 1. カナリア対象の選定

```python
# smart-canary-selection.py
def select_canary_users(user_context, canary_percentage=10):
    """
    スマートなカナリア対象選定
    """
    # 内部ユーザーは常にカナリア対象
    if user_context.get('is_internal', False):
        return True
    
    # ベータユーザーは優先的にカナリア対象
    if user_context.get('is_beta_user', False):
        return True
    
    # 地域別段階展開
    region = user_context.get('region', 'us-east-1')
    region_weights = {
        'us-east-1': canary_percentage,
        'us-west-2': canary_percentage * 0.5,  # より慎重に
        'eu-west-1': canary_percentage * 0.3,
        'ap-northeast-1': canary_percentage * 0.2
    }
    
    threshold = region_weights.get(region, canary_percentage)
    user_hash = hash(user_context['user_id']) % 100
    
    return user_hash < threshold
```

### 2. 段階的展開戦略

```python
# gradual-rollout.py
class GradualRollout:
    def __init__(self, function_name):
        self.function_name = function_name
        self.lambda_client = boto3.client('lambda')
        
    def execute_rollout(self, new_version, rollout_schedule):
        """
        段階的ロールアウト実行
        rollout_schedule: [(weight, duration_minutes, success_criteria), ...]
        """
        for weight, duration, criteria in rollout_schedule:
            print(f"Rolling out to {weight*100}% for {duration} minutes...")
            
            # 重み付け更新
            self._update_traffic_weight(new_version, weight)
            
            # 監視期間
            time.sleep(duration * 60)
            
            # 成功基準チェック
            if not self._check_success_criteria(new_version, criteria):
                print("Success criteria not met. Rolling back...")
                self._rollback()
                return False
                
        print("Gradual rollout completed successfully!")
        return True
    
    def _update_traffic_weight(self, version, weight):
        self.lambda_client.update_alias(
            FunctionName=self.function_name,
            Name='live',
            RoutingConfig={
                'AdditionalVersionWeights': {
                    version: weight
                }
            }
        )
    
    def _check_success_criteria(self, version, criteria):
        # エラー率、レイテンシ、ビジネスメトリクスをチェック
        return True  # 実装省略
    
    def _rollback(self):
        self.lambda_client.update_alias(
            FunctionName=self.function_name,
            Name='live',
            RoutingConfig={}
        )
```

## ハンズオン演習

### 演習1: Lambda カナリアデプロイメント

1. Lambda関数の新バージョン作成
2. Aliasを使用したカナリア設定
3. 段階的トラフィック増加
4. メトリクス監視とロールバック

### 演習2: API Gateway カナリア

1. API Gatewayでのカナリアステージ作成
2. トラフィック分割設定
3. カナリア昇格プロセス
4. 自動ロールバック実装

### 演習3: フィーチャーフラグ統合

1. DynamoDBでのフラグ管理
2. アプリケーションでのフラグ判定
3. 段階的機能公開
4. A/Bテスト実装

## 次のステップ

- [6.3.1 APM実装](../../6.3-モニタリングと最適化/6.3.1-APM実装/README.md) - カナリアデプロイメントの詳細監視
- フィーチャーフラグサービス（AWS AppConfig）の活用
- 高度なA/Bテストプラットフォームの構築