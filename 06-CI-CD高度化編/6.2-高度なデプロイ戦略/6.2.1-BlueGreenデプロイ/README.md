# 6.2.1 Blue/Greenデプロイメント

## 概要

Blue/Greenデプロイメントは、ゼロダウンタイムでアプリケーションを更新する最も信頼性の高い手法の一つです。このセクションでは、ECSとEC2の両方でBlue/Green戦略を実装します。

## 学習目標

- ✅ Blue/Green戦略の理解と実装
- ✅ ECSでのBlue/Greenデプロイメント
- ✅ ALBを使用したトラフィック切り替え
- ✅ 自動ロールバック機能の実装
- ✅ ヘルスチェックとメトリクス監視

## アーキテクチャ

```
┌─────────────────────────────────────────────────────────────────┐
│                      Route 53                                   │
│                   (DNS Weighted Routing)                        │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│                Application Load Balancer                        │
│  ┌─────────────────┐                    ┌────────────────────┐ │
│  │  Target Group   │                    │  Target Group      │ │
│  │     (Blue)      │◄───────────────────│     (Green)       │ │
│  └─────────────────┘                    └────────────────────┘ │
└──────────────────────┬──────────────────────┬──────────────────┘
                       │                      │
                       ▼                      ▼
┌──────────────────────────┐         ┌──────────────────────────┐
│     Blue Environment     │         │    Green Environment     │
│  ┌────────────────────┐  │         │  ┌────────────────────┐  │
│  │   ECS Service v1   │  │         │  │   ECS Service v2   │  │
│  │  ┌──────┐ ┌──────┐│  │         │  │  ┌──────┐ ┌──────┐│  │
│  │  │Task 1│ │Task 2││  │         │  │  │Task 1│ │Task 2││  │
│  │  └──────┘ └──────┘│  │         │  │  └──────┘ └──────┘│  │
│  └────────────────────┘  │         │  └────────────────────┘  │
└──────────────────────────┘         └──────────────────────────┘
```

## 実装手順

### Step 1: 基本インフラストラクチャの準備

```bash
# VPCとネットワーク設定の確認
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=web-app-vpc"

# ECSクラスターの作成（まだない場合）
aws ecs create-cluster --cluster-name production-cluster
```

### Step 2: Blue/Green用のCodeDeployアプリケーション作成

```bash
# CodeDeployアプリケーション作成
aws deploy create-application \
  --application-name my-web-app \
  --compute-platform ECS

# デプロイメントグループ作成
aws deploy create-deployment-group \
  --application-name my-web-app \
  --deployment-group-name production-deployment \
  --service-role-arn arn:aws:iam::123456789012:role/CodeDeployServiceRole \
  --deployment-config-name CodeDeployDefault.ECSAllAtOnceBlueGreen \
  --blue-green-deployment-configuration file://blue-green-config.json
```

### Step 3: CloudFormationでBlue/Green環境構築

```bash
# Blue/Greenスタック作成
aws cloudformation create-stack \
  --stack-name blue-green-ecs-stack \
  --template-body file://cloudformation/blue-green-ecs.yaml \
  --parameters ParameterKey=ApplicationName,ParameterValue=my-web-app \
  --capabilities CAPABILITY_NAMED_IAM
```

## 設定ファイル例

### blue-green-config.json

```json
{
  "terminateBlueInstancesOnDeploymentSuccess": {
    "action": "TERMINATE",
    "terminationWaitTimeInMinutes": 5
  },
  "deploymentReadyOption": {
    "actionOnTimeout": "CONTINUE_DEPLOYMENT"
  },
  "greenFleetProvisioningOption": {
    "action": "COPY_AUTO_SCALING_GROUP"
  }
}
```

### appspec.yml (ECS用)

```yaml
version: 0.0
Resources:
  - TargetService:
      Type: AWS::ECS::Service
      Properties:
        TaskDefinition: <TASK_DEFINITION>
        LoadBalancerInfo:
          ContainerName: "my-app"
          ContainerPort: 80
        PlatformVersion: "LATEST"
        NetworkConfiguration:
          AwsvpcConfiguration:
            Subnets:
              - "subnet-12345678"
              - "subnet-87654321"
            SecurityGroups:
              - "sg-12345678"
            AssignPublicIp: "DISABLED"

Hooks:
  - BeforeInstall: "Lambda:arn:aws:lambda:region:account:function:BeforeInstallHook"
  - AfterInstall: "Lambda:arn:aws:lambda:region:account:function:AfterInstallHook"
  - AfterAllowTestTraffic: "Lambda:arn:aws:lambda:region:account:function:AfterAllowTestTrafficHook"
  - BeforeAllowTraffic: "Lambda:arn:aws:lambda:region:account:function:BeforeAllowTrafficHook"
  - AfterAllowTraffic: "Lambda:arn:aws:lambda:region:account:function:AfterAllowTrafficHook"
```

## 検証とロールバック

### ヘルスチェック設定

```python
# Lambda関数でのヘルスチェック例
import boto3
import json
import requests

def lambda_handler(event, context):
    """
    Blue/Greenデプロイメント後のヘルスチェック
    """
    codedeploy = boto3.client('codedeploy')
    
    # 新しい環境のエンドポイント取得
    deployment_id = event['DeploymentId']
    lifecycle_event_hook_execution_id = event['LifecycleEventHookExecutionId']
    
    try:
        # アプリケーションのヘルスチェック
        response = requests.get('http://internal-alb-dns/health', timeout=10)
        
        if response.status_code == 200:
            # デプロイメント成功
            codedeploy.put_lifecycle_event_hook_execution_status(
                deploymentId=deployment_id,
                lifecycleEventHookExecutionId=lifecycle_event_hook_execution_id,
                status='Succeeded'
            )
        else:
            # デプロイメント失敗
            codedeploy.put_lifecycle_event_hook_execution_status(
                deploymentId=deployment_id,
                lifecycleEventHookExecutionId=lifecycle_event_hook_execution_id,
                status='Failed'
            )
    except Exception as e:
        print(f"Health check failed: {str(e)}")
        codedeploy.put_lifecycle_event_hook_execution_status(
            deploymentId=deployment_id,
            lifecycleEventHookExecutionId=lifecycle_event_hook_execution_id,
            status='Failed'
        )
    
    return {
        'statusCode': 200,
        'body': json.dumps('Health check completed')
    }
```

### 自動ロールバック条件

```yaml
# CloudWatch Alarmによるロールバック
HighErrorRateAlarm:
  Type: AWS::CloudWatch::Alarm
  Properties:
    AlarmName: !Sub '${ApplicationName}-high-error-rate'
    AlarmDescription: 'Trigger rollback on high error rate'
    MetricName: 5XXError
    Namespace: AWS/ApplicationELB
    Statistic: Sum
    Period: 60
    EvaluationPeriods: 2
    Threshold: 10
    ComparisonOperator: GreaterThanThreshold
    TreatMissingData: notBreaching
    AlarmActions:
      - !Ref RollbackTopic
```

## トラフィック切り替え戦略

### 段階的切り替え

```bash
#!/bin/bash
# gradual-traffic-shift.sh

BLUE_TARGET_GROUP="arn:aws:elasticloadbalancing:region:account:targetgroup/blue/xxx"
GREEN_TARGET_GROUP="arn:aws:elasticloadbalancing:region:account:targetgroup/green/xxx"
LISTENER_ARN="arn:aws:elasticloadbalancing:region:account:listener/app/my-alb/xxx"

# 10% -> 25% -> 50% -> 100% の段階的切り替え
for WEIGHT in 10 25 50 100; do
    echo "Shifting ${WEIGHT}% traffic to Green environment..."
    
    aws elbv2 modify-listener \
        --listener-arn $LISTENER_ARN \
        --default-actions \
            "Type=forward,ForwardConfig={TargetGroups=[{TargetGroupArn=$BLUE_TARGET_GROUP,Weight=$((100-WEIGHT))},{TargetGroupArn=$GREEN_TARGET_GROUP,Weight=$WEIGHT}]}"
    
    # メトリクス監視
    sleep 300  # 5分待機
    
    # エラー率チェック
    ERROR_RATE=$(aws cloudwatch get-metric-statistics \
        --namespace AWS/ApplicationELB \
        --metric-name HTTPCode_Target_5XX_Count \
        --dimensions Name=TargetGroup,Value=$GREEN_TARGET_GROUP \
        --start-time $(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%S) \
        --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
        --period 300 \
        --statistics Sum \
        --query 'Datapoints[0].Sum' \
        --output text)
    
    if [ "$ERROR_RATE" -gt "10" ]; then
        echo "High error rate detected. Rolling back..."
        # ロールバック実行
        aws elbv2 modify-listener \
            --listener-arn $LISTENER_ARN \
            --default-actions "Type=forward,TargetGroupArn=$BLUE_TARGET_GROUP"
        exit 1
    fi
done

echo "Blue/Green deployment completed successfully!"
```

## モニタリングとメトリクス

### カスタムメトリクス送信

```python
# custom_metrics.py
import boto3
from datetime import datetime

def send_deployment_metrics(deployment_id, environment, success_rate):
    """
    デプロイメントメトリクスをCloudWatchに送信
    """
    cloudwatch = boto3.client('cloudwatch')
    
    cloudwatch.put_metric_data(
        Namespace='BlueGreenDeployment',
        MetricData=[
            {
                'MetricName': 'DeploymentSuccessRate',
                'Value': success_rate,
                'Unit': 'Percent',
                'Dimensions': [
                    {
                        'Name': 'DeploymentId',
                        'Value': deployment_id
                    },
                    {
                        'Name': 'Environment',
                        'Value': environment
                    }
                ],
                'Timestamp': datetime.utcnow()
            }
        ]
    )
```

## ベストプラクティス

### 1. データベースマイグレーション

```bash
# Blue/Green対応のDBマイグレーション戦略
# 1. 後方互換性のあるスキーマ変更
# 2. Blue環境でマイグレーション実行
# 3. Green環境デプロイ
# 4. 古いカラム/テーブルの削除は次回デプロイで
```

### 2. セッション管理

```yaml
# ElastiCacheでのセッション共有
SessionStore:
  Type: AWS::ElastiCache::CacheCluster
  Properties:
    CacheNodeType: cache.t3.micro
    Engine: redis
    NumCacheNodes: 1
    VpcSecurityGroupIds:
      - !Ref CacheSecurityGroup
```

### 3. 静的アセット管理

```nginx
# CloudFrontでの静的アセット配信
location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
    proxy_pass http://cloudfront.example.com;
}
```

## トラブルシューティング

### よくある問題と解決策

1. **ターゲットグループのヘルスチェック失敗**
   ```bash
   # ヘルスチェックステータス確認
   aws elbv2 describe-target-health \
     --target-group-arn arn:aws:elasticloadbalancing:region:account:targetgroup/green/xxx
   ```

2. **デプロイメントタイムアウト**
   ```bash
   # タイムアウト設定の調整
   aws deploy update-deployment-group \
     --application-name my-app \
     --deployment-group-name production \
     --deployment-config-name CodeDeployDefault.ECSAllAtOnceBlueGreenTimeout30Minutes
   ```

3. **ロールバック失敗**
   ```bash
   # 手動ロールバック実行
   aws deploy stop-deployment \
     --deployment-id d-XXXXXXXXX \
     --auto-rollback-enabled
   ```

## ハンズオン演習

### 演習1: 基本的なBlue/Greenデプロイメント

1. サンプルアプリケーションのデプロイ
2. 新バージョンの作成とGreen環境へのデプロイ
3. トラフィック切り替えの実行
4. メトリクス監視とロールバック

### 演習2: カスタムヘルスチェック実装

1. Lambda関数でのヘルスチェック作成
2. CodeDeployフックへの統合
3. 失敗時の自動ロールバック確認

### 演習3: A/Bテスト実装

1. Route 53での重み付けルーティング設定
2. CloudWatchでのメトリクス比較
3. 勝者バージョンへの完全切り替え

## 次のステップ

- [6.2.2 カナリアリリース](../6.2.2-カナリアリリース/README.md) - より細かい制御でのリリース戦略
- [6.3.1 APM実装](../../6.3-モニタリングと最適化/6.3.1-APM実装/README.md) - デプロイメント後の詳細監視