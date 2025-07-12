# 1.5 ロードバランサー

## 🎯 このステップで学ぶこと

Application Load Balancer (ALB) を設定して、高可用性なWebアプリケーションを構築します。Multi-AZ構成でのロードバランシングと自動スケーリングを学習します。

## 📋 作成するリソース

- **Application Load Balancer**: インターネットからのトラフィックを分散
- **Target Group**: EC2インスタンスのグループ管理
- **Multi-AZ Subnets**: 高可用性のための複数AZ配置
- **Multi-AZ EC2**: 複数AZでのEC2インスタンス配置

## 🏗️ アーキテクチャ図

```
┌─────────────────────────────────────────────────────────────────┐
│                        VPC (10.0.0.0/16)                       │
│                                                                 │
│  ┌─────────────────────────┐  ┌─────────────────────────┐       │
│  │     AZ-1a               │  │     AZ-1c               │       │
│  │                         │  │                         │       │
│  │  ┌─────────────────┐    │  │  ┌─────────────────┐    │       │
│  │  │ Public Subnet   │    │  │  │ Public Subnet   │    │       │
│  │  │ (10.0.1.0/24)   │    │  │  │ (10.0.3.0/24)   │    │       │
│  │  │                 │    │  │  │                 │    │       │
│  │  │ ┌─────────────┐ │    │  │  │ ┌─────────────┐ │    │       │
│  │  │ │     ALB     │ │    │  │  │ │     ALB     │ │    │       │
│  │  │ └─────────────┘ │    │  │  │ └─────────────┘ │    │       │
│  │  └─────────────────┘    │  │  └─────────────────┘    │       │
│  │                         │  │                         │       │
│  │  ┌─────────────────┐    │  │  ┌─────────────────┐    │       │
│  │  │ Private Subnet  │    │  │  │ Private Subnet  │    │       │
│  │  │ (10.0.2.0/24)   │    │  │  │ (10.0.4.0/24)   │    │       │
│  │  │                 │    │  │  │                 │    │       │
│  │  │ ┌─────────────┐ │    │  │  │ ┌─────────────┐ │    │       │
│  │  │ │ EC2 Instance│ │    │  │  │ │ EC2 Instance│ │    │       │
│  │  │ │ (Web Server)│ │    │  │  │ │ (Web Server)│ │    │       │
│  │  │ └─────────────┘ │    │  │  │ └─────────────┘ │    │       │
│  │  └─────────────────┘    │  │  └─────────────────┘    │       │
│  └─────────────────────────┘  └─────────────────────────┘       │
│                                                                 │
│                    Internet Gateway                             │
│                          │                                      │
│                          ▼                                      │
│                      Internet                                   │
└─────────────────────────────────────────────────────────────────┘
```

## 🔑 事前準備

### 1. EC2 Key Pairの作成

```bash
# Key Pairを作成 (SSH接続用)
aws ec2 create-key-pair \
  --key-name aws-practice-keypair \
  --query 'KeyMaterial' \
  --output text > aws-practice-keypair.pem

# 権限を設定
chmod 600 aws-practice-keypair.pem
```

## 🚀 デプロイ手順

### 前提条件
- **実行ディレクトリ**: このREADMEがあるディレクトリ（`1.5-ロードバランサー/`）から実行してください
- **AWS CLI**: 設定済みであること
- **権限**: CloudFormationとVPC作成権限があること

### 1. 前のステップのクリーンアップ (必要に応じて)

```bash
# 前のステップのスタックを削除 (必要に応じて)
aws cloudformation delete-stack --stack-name aws-practice-ec2
```

### 2. 新しいスタックの作成

```bash
# メインスタックの作成 (完全なWebアプリケーション)
aws cloudformation create-stack \
  --stack-name aws-practice-alb \
  --template-body file://cloudformation/templates/main-stack.yaml \
  --parameters ParameterKey=ProjectName,ParameterValue=aws-practice \
               ParameterKey=EnvironmentName,ParameterValue=dev \
               ParameterKey=KeyPairName,ParameterValue=aws-practice-keypair \
  --capabilities CAPABILITY_IAM
```

### 3. デプロイ完了の確認

```bash
# スタックの状態確認
aws cloudformation describe-stacks \
  --stack-name aws-practice-alb \
  --query 'Stacks[0].StackStatus'

# ALBのDNS名を取得
ALB_DNS=$(aws cloudformation describe-stacks \
  --stack-name aws-practice-alb \
  --query 'Stacks[0].Outputs[?OutputKey==`ApplicationLoadBalancerDNS`].OutputValue' \
  --output text)

echo "Website URL: http://$ALB_DNS"
```

## 📊 確認事項

- [ ] Application Load Balancerが作成されている
- [ ] Target Groupが作成されている
- [ ] EC2インスタンスが複数AZに配置されている
- [ ] ヘルスチェックが正常に動作している
- [ ] Webサイトにアクセスできる

## 💡 ポイント

1. **Multi-AZ構成**: 複数のAZに配置することで高可用性を実現
2. **Target Group**: ヘルスチェックによる自動的な障害検知
3. **Auto Scaling**: 負荷に応じた自動スケーリング
4. **Load Balancing**: トラフィックの適切な分散

## 🧪 テスト

### 1. Webサイトの動作確認

```bash
# WebサイトにアクセスしてHTTPステータスを確認
curl -I http://$ALB_DNS

# 複数回アクセスして異なるインスタンスが応答することを確認
for i in {1..5}; do
  curl -s http://$ALB_DNS | grep "Instance ID"
  sleep 1
done
```

### 2. ヘルスチェックの確認

```bash
# Target Groupの状態確認
aws elbv2 describe-target-health \
  --target-group-arn $(aws elbv2 describe-target-groups \
    --names aws-practice-dev-web-tg \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text)
```

### 3. Auto Scalingの動作確認

```bash
# 現在のインスタンス数を確認
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names aws-practice-dev-web-asg \
  --query 'AutoScalingGroups[0].[MinSize,MaxSize,DesiredCapacity]'

# 手動でスケールアウトのテスト
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name aws-practice-dev-web-asg \
  --desired-capacity 3

# 新しいインスタンスがTarget Groupに追加されることを確認
aws elbv2 describe-target-health \
  --target-group-arn $(aws elbv2 describe-target-groups \
    --names aws-practice-dev-web-tg \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text) \
  --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]'
```

## 📈 監視とメトリクス

### 1. ALBメトリクスの確認

```bash
# リクエスト数の確認
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name RequestCount \
  --dimensions Name=LoadBalancer,Value=$(aws elbv2 describe-load-balancers \
    --names aws-practice-dev-alb \
    --query 'LoadBalancers[0].LoadBalancerArn' \
    --output text | cut -d'/' -f2-) \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum
```

### 2. レスポンス時間の確認

```bash
# レスポンス時間の確認
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name TargetResponseTime \
  --dimensions Name=LoadBalancer,Value=$(aws elbv2 describe-load-balancers \
    --names aws-practice-dev-alb \
    --query 'LoadBalancers[0].LoadBalancerArn' \
    --output text | cut -d'/' -f2-) \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

## 🔧 高度な設定

### 1. スケーリングポリシーの設定

```bash
# CPU使用率ベースのスケーリングポリシー
aws autoscaling put-scaling-policy \
  --auto-scaling-group-name aws-practice-dev-web-asg \
  --policy-name cpu-scale-out \
  --policy-type TargetTrackingScaling \
  --target-tracking-configuration '{
    "TargetValue": 70.0,
    "PredefinedMetricSpecification": {
      "PredefinedMetricType": "ASGAverageCPUUtilization"
    }
  }'
```

### 2. CloudWatch Alarmの設定

```bash
# 高CPU使用率のアラーム
aws cloudwatch put-metric-alarm \
  --alarm-name "aws-practice-high-cpu" \
  --alarm-description "High CPU usage on web servers" \
  --metric-name CPUUtilization \
  --namespace AWS/EC2 \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2
```

## 🚨 セキュリティのポイント

1. **ALBのセキュリティグループ**: インターネットからのHTTP/HTTPSのみを許可
2. **EC2のセキュリティグループ**: ALBからのトラフィックのみを許可
3. **プライベートサブネット**: EC2インスタンスは直接インターネットからアクセス不可
4. **ヘルスチェック**: 異常なインスタンスの自動検知と排除

## 🗑️ リソースの削除

```bash
# スケーリングポリシーとアラームの削除
aws autoscaling delete-policy \
  --auto-scaling-group-name aws-practice-dev-web-asg \
  --policy-name cpu-scale-out

aws cloudwatch delete-alarms \
  --alarm-names "aws-practice-high-cpu"

# Key Pairの削除
aws ec2 delete-key-pair --key-name aws-practice-keypair
rm aws-practice-keypair.pem

# スタックの削除
aws cloudformation delete-stack \
  --stack-name aws-practice-alb
```

## 📝 次のステップ

次は「1.6 RDSデータベース」でデータベースを追加し、完全な3層アーキテクチャを構築します。

---

**💰 コスト**: 
- ALB: 約$0.025/時間 + データ処理料金
- EC2 t3.micro x2: 約$0.02/時間
- 複数AZ配置により若干のコスト増加

**🌟 達成したこと**:
- 高可用性なWebアプリケーションの構築
- 自動スケーリング機能の実装
- ロードバランシングによるトラフィック分散
