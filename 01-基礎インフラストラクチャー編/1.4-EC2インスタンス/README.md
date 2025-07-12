# 1.4 EC2インスタンス

## 🎯 このステップで学ぶこと

ステップ1-3で作成したインフラストラクチャーに、EC2インスタンスを追加します。Auto Scaling GroupとLaunch Templateを使用した自動スケーリング機能を学習します。

### ネストスタックを使う理由

このプロジェクトでは**ネストスタック**を採用しています：

1. **再利用性**: 個別のテンプレート（VPC、サブネット、セキュリティグループ等）を他のプロジェクトでも再利用可能
2. **保守性**: 機能ごとにテンプレートを分割することで、変更時の影響範囲を限定
3. **段階的学習**: 各ステップで少しずつ機能を追加していく学習スタイルに適している
4. **実務での標準**: 実際の業務でも複雑なインフラは機能別に分割して管理する

ネストスタックを使用するため、テンプレートをS3にアップロードする手順が含まれます。

## 📋 作成するリソース

- **Launch Template**: EC2インスタンスの設定テンプレート
- **Auto Scaling Group**: 自動スケーリング設定
- **IAM Role**: EC2インスタンス用のロール
- **Webアプリケーション**: 簡単なWebサーバー

## 🏗️ アーキテクチャ図

```
┌─────────────────────────────────────────────────────────────┐
│                      VPC (10.0.0.0/16)                     │
│                                                             │
│  ┌─────────────────────────┐  ┌─────────────────────────┐   │
│  │    Public Subnet        │  │    Private Subnet       │   │
│  │    (10.0.1.0/24)        │  │    (10.0.2.0/24)        │   │
│  │                         │  │                         │   │
│  │                         │  │  ┌─────────────────┐    │   │
│  │                         │  │  │ Auto Scaling    │    │   │
│  │                         │  │  │ Group           │    │   │
│  │                         │  │  │                 │    │   │
│  │                         │  │  │ ┌─────────────┐ │    │   │
│  │                         │  │  │ │ EC2 Instance│ │    │   │
│  │                         │  │  │ │ (Web Server)│ │    │   │
│  │                         │  │  │ │             │ │    │   │
│  │                         │  │  │ │  Apache     │ │    │   │
│  │                         │  │  │ │  CloudWatch │ │    │   │
│  │                         │  │  │ └─────────────┘ │    │   │
│  │                         │  │  └─────────────────┘    │   │
│  └─────────────────────────┘  └─────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
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
- **実行ディレクトリ**: このREADMEがあるディレクトリ（`1.4-EC2インスタンス/`）から実行してください
- **AWS CLI**: 設定済みであること
- **権限**: CloudFormationとVPC作成権限があること

### 1. S3バケットの作成とテンプレートアップロード

```bash
# S3バケットの作成（バケット名は一意である必要があります）
BUCKET_NAME="aws-practice-cf-templates-$(date +%s)"
aws s3 mb "s3://$BUCKET_NAME"

# ネストスタックテンプレートをS3にアップロード
aws s3 cp cloudformation/templates/ "s3://$BUCKET_NAME/templates/" --recursive

# アップロード確認
aws s3 ls "s3://$BUCKET_NAME/templates/"
```

### 2. テンプレートの検証

```bash
# CloudFormationテンプレートの検証
aws cloudformation validate-template \
  --template-body file://cloudformation/main-stack.yaml
```

### 3. 前のステップのクリーンアップ (必要に応じて)

```bash
# 前のステップのスタックを削除 (必要に応じて)
aws cloudformation delete-stack --stack-name aws-practice-security
```

### 4. 新しいスタックの作成

```bash
# メインスタックの作成 (VPC + サブネット + セキュリティグループ + EC2)
aws cloudformation create-stack \
  --stack-name aws-practice-ec2 \
  --template-body file://cloudformation/main-stack.yaml \
  --parameters ParameterKey=ProjectName,ParameterValue=aws-practice \
               ParameterKey=EnvironmentName,ParameterValue=dev \
               ParameterKey=S3BucketName,ParameterValue=$BUCKET_NAME \
               ParameterKey=KeyPairName,ParameterValue=aws-practice-keypair \
  --capabilities CAPABILITY_IAM
```

### 5. スタックの確認

```bash
# スタックの状態確認
aws cloudformation describe-stacks \
  --stack-name aws-practice-ec2

# 作成されたEC2インスタンスの確認
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=aws-practice" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PrivateIpAddress]'
```

## 📊 確認事項

- [ ] Launch Templateが作成されている
- [ ] Auto Scaling Groupが作成されている
- [ ] EC2インスタンスが起動している
- [ ] IAM Roleが作成されている
- [ ] CloudWatch Agentが動作している
- [ ] Webサーバーが起動している

## 💡 ポイント

1. **Launch Template**: 再利用可能なEC2設定テンプレート
2. **Auto Scaling**: 負荷に応じた自動スケーリング
3. **User Data**: 起動時の自動設定スクリプト
4. **IAM Role**: EC2インスタンスに必要な権限を付与
5. **CloudWatch Agent**: 詳細なメトリクス収集

## 🧪 テスト

### 1. Auto Scaling Groupの確認

```bash
# Auto Scaling Groupの詳細確認
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names aws-practice-dev-web-asg

# インスタンスの詳細確認
aws autoscaling describe-auto-scaling-instances \
  --query 'AutoScalingInstances[*].[InstanceId,AutoScalingGroupName,HealthStatus]'
```

### 2. Webサーバーの動作確認

```bash
# プライベートIPアドレスの取得
PRIVATE_IP=$(aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=aws-practice" "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].PrivateIpAddress' \
  --output text)

echo "Web Server Private IP: $PRIVATE_IP"
```

### 3. SSH接続での確認

```bash
# Bastion Hostからの接続 (後のステップで設定)
# ssh -i aws-practice-keypair.pem ec2-user@$PRIVATE_IP

# Webサーバーの状態確認
# sudo systemctl status httpd
```

## 📈 CloudWatch メトリクス

### 1. メトリクスの確認

```bash
# CPU使用率の確認
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=AutoScalingGroupName,Value=aws-practice-dev-web-asg \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

### 2. カスタムメトリクス

```bash
# カスタムメトリクス (CloudWatch Agent) の確認
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2/Custom \
  --metric-name mem_used_percent \
  --dimensions Name=AutoScalingGroupName,Value=aws-practice-dev-web-asg \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

## 🔧 Auto Scaling設定

### 1. スケーリングポリシーの追加

```bash
# スケールアウトポリシーの作成
aws autoscaling put-scaling-policy \
  --auto-scaling-group-name aws-practice-dev-web-asg \
  --policy-name scale-out-policy \
  --policy-type TargetTrackingScaling \
  --target-tracking-configuration '{
    "TargetValue": 70.0,
    "PredefinedMetricSpecification": {
      "PredefinedMetricType": "ASGAverageCPUUtilization"
    }
  }'
```

### 2. 手動スケーリングのテスト

```bash
# 手動でインスタンス数を変更
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name aws-practice-dev-web-asg \
  --desired-capacity 2

# 変更を確認
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names aws-practice-dev-web-asg \
  --query 'AutoScalingGroups[0].[MinSize,MaxSize,DesiredCapacity]'
```

## 🚨 セキュリティのポイント

1. **プライベートサブネット配置**: Webサーバーは直接インターネットからアクセス不可
2. **IAM Role使用**: インスタンスプロファイルによる権限管理
3. **セキュリティグループ**: 必要最小限のポート開放
4. **Key Pair管理**: SSH接続用の鍵の適切な管理

## 🗑️ リソースの削除

```bash
# Key Pairの削除
aws ec2 delete-key-pair --key-name aws-practice-keypair
rm aws-practice-keypair.pem

# スタックの削除
aws cloudformation delete-stack \
  --stack-name aws-practice-ec2

# スタック削除の完了を待機
aws cloudformation wait stack-delete-complete \
  --stack-name aws-practice-ec2

# S3バケットを空にして削除
aws s3 rm "s3://$BUCKET_NAME" --recursive
aws s3 rb "s3://$BUCKET_NAME"
```

## 📝 次のステップ

次は「1.5 ロードバランサー」でApplication Load Balancerを設定し、インターネットからWebサーバーにアクセスできるようにします。

---

**💰 コスト**: EC2 t3.microインスタンス1台で約$0.01/時間。Auto Scalingで複数台起動された場合はその分コストが発生します。
