# 1.6 RDSデータベース

## 🎯 このステップで学ぶこと

RDS MySQL データベースを追加して、完全な3層アーキテクチャのWebアプリケーションを構築します。データベース接続、セキュリティ、バックアップ設定を学習します。

## 📋 作成するリソース

- **RDS MySQL インスタンス**: マネージドデータベース
- **DB サブネットグループ**: データベース用のサブネット
- **DB パラメータグループ**: データベース設定
- **Secrets Manager**: データベース認証情報の管理
- **完全な3層アーキテクチャ**: プレゼンテーション・アプリケーション・データ層

## 🏗️ 完成アーキテクチャ図

```
┌─────────────────────────────────────────────────────────────────┐
│                        VPC (10.0.0.0/16)                       │
│                                                                 │
│  ┌─────────────────────────┐  ┌─────────────────────────┐       │
│  │        AZ-1a            │  │        AZ-1c            │       │
│  │                         │  │                         │       │
│  │  ┌─────────────────┐    │  │  ┌─────────────────┐    │       │
│  │  │ Public Subnet   │    │  │  │ Public Subnet   │    │       │
│  │  │                 │    │  │  │                 │    │       │
│  │  │ ┌─────────────┐ │    │  │  │ ┌─────────────┐ │    │       │
│  │  │ │     ALB     │ │    │  │  │ │     ALB     │ │    │       │
│  │  │ └─────────────┘ │    │  │  │ └─────────────┘ │    │       │
│  │  └─────────────────┘    │  │  └─────────────────┘    │       │
│  │                         │  │                         │       │
│  │  ┌─────────────────┐    │  │  ┌─────────────────┐    │       │
│  │  │ Private Subnet  │    │  │  │ Private Subnet  │    │       │
│  │  │                 │    │  │  │                 │    │       │
│  │  │ ┌─────────────┐ │    │  │  │ ┌─────────────┐ │    │       │
│  │  │ │ EC2 + PHP   │ │    │  │  │ │ EC2 + PHP   │ │    │       │
│  │  │ │ Web Server  │ │    │  │  │ │ Web Server  │ │    │       │
│  │  │ └─────────────┘ │    │  │  │ └─────────────┘ │    │       │
│  │  └─────────────────┘    │  │  └─────────────────┘    │       │
│  │           │              │  │           │             │       │
│  │           └──────────────┼──┼───────────┘             │       │
│  │                          │  │                         │       │
│  │  ┌─────────────────┐    │  │  ┌─────────────────┐    │       │
│  │  │ Database Subnet │    │  │  │ Database Subnet │    │       │
│  │  │                 │    │  │  │                 │    │       │
│  │  │ ┌─────────────┐ │    │  │  │ ┌─────────────┐ │    │       │
│  │  │ │ RDS MySQL   │ │    │  │  │ │ RDS MySQL   │ │    │       │
│  │  │ │ (Primary)   │ │    │  │  │ │ (Standby)   │ │    │       │
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

### 2. データベースパスワードの準備

```bash
# 強力なパスワードを生成（例）
echo "MySecurePassword123" # 実際の本番環境では、より複雑なパスワードを使用
```

## 🚀 デプロイ手順

### 前提条件
- **実行ディレクトリ**: このREADMEがあるディレクトリ（`1.6-RDSデータベース/`）から実行してください
- **AWS CLI**: 設定済みであること
- **権限**: CloudFormationとVPC作成権限があること

### 1. 前のステップのクリーンアップ (必要に応じて)

```bash
# 前のステップのスタックを削除 (必要に応じて)
aws cloudformation delete-stack --stack-name aws-practice-alb
```

### 2. 完全な3層アーキテクチャのデプロイ

```bash
# 完全なスタックの作成
aws cloudformation create-stack \
  --stack-name aws-practice-complete \
  --template-body file://cloudformation/templates/main-stack.yaml \
  --parameters ParameterKey=ProjectName,ParameterValue=aws-practice \
               ParameterKey=EnvironmentName,ParameterValue=dev \
               ParameterKey=KeyPairName,ParameterValue=aws-practice-keypair \
               ParameterKey=DatabasePassword,ParameterValue=MySecurePassword123 \
  --capabilities CAPABILITY_IAM
```

### 3. デプロイ完了の確認

```bash
# スタックの状態確認
aws cloudformation describe-stacks \
  --stack-name aws-practice-complete \
  --query 'Stacks[0].StackStatus'

# WebサイトURLの取得
WEBSITE_URL=$(aws cloudformation describe-stacks \
  --stack-name aws-practice-complete \
  --query 'Stacks[0].Outputs[?OutputKey==`WebsiteURL`].OutputValue' \
  --output text)

echo "Website URL: $WEBSITE_URL"
echo "Database Test URL: $WEBSITE_URL/dbtest.php"
```

## 📊 確認事項

- [ ] RDS MySQL インスタンスが作成されている
- [ ] DB サブネットグループが設定されている
- [ ] Secrets Manager に認証情報が保存されている
- [ ] EC2 インスタンスからデータベースに接続できる
- [ ] Webアプリケーションが正常に動作している
- [ ] データベーステストページが動作している

## 💡 ポイント

1. **3層アーキテクチャ**: プレゼンテーション・アプリケーション・データ層の分離
2. **Secrets Manager**: データベース認証情報の安全な管理
3. **DB サブネットグループ**: データベース専用のネットワーク分離
4. **セキュリティ**: データベースはプライベートサブネットに配置
5. **バックアップ**: 自動バックアップとポイントインタイム復旧

## 🧪 テスト

### 1. Webアプリケーションの動作確認

```bash
# メインページのアクセス
curl -I $WEBSITE_URL

# データベース接続テスト
curl -s "$WEBSITE_URL/dbtest.php"

# PHP情報の確認
curl -s "$WEBSITE_URL/info.php" | grep -i mysql
```

### 2. データベース接続の確認

```bash
# データベースのエンドポイント取得
DB_ENDPOINT=$(aws cloudformation describe-stacks \
  --stack-name aws-practice-complete \
  --query 'Stacks[0].Outputs[?OutputKey==`DatabaseEndpoint`].OutputValue' \
  --output text)

echo "Database Endpoint: $DB_ENDPOINT"

# データベースの状態確認
aws rds describe-db-instances \
  --db-instance-identifier aws-practice-dev-mysql \
  --query 'DBInstances[0].DBInstanceStatus'
```

### 3. バックアップの確認

```bash
# 自動バックアップの確認
aws rds describe-db-instances \
  --db-instance-identifier aws-practice-dev-mysql \
  --query 'DBInstances[0].[BackupRetentionPeriod,PreferredBackupWindow,PreferredMaintenanceWindow]'

# バックアップスナップショットの確認
aws rds describe-db-snapshots \
  --db-instance-identifier aws-practice-dev-mysql \
  --query 'DBSnapshots[*].[DBSnapshotIdentifier,SnapshotCreateTime,Status]'
```

## 📈 監視とメトリクス

### 1. データベースメトリクス

```bash
# データベース接続数の確認
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name DatabaseConnections \
  --dimensions Name=DBInstanceIdentifier,Value=aws-practice-dev-mysql \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average,Maximum
```

### 2. アプリケーションメトリクス

```bash
# ALB のターゲット応答時間
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

## 🔧 データベース管理

### 1. 手動スナップショットの作成

```bash
# データベースのスナップショット作成
aws rds create-db-snapshot \
  --db-instance-identifier aws-practice-dev-mysql \
  --db-snapshot-identifier aws-practice-dev-mysql-manual-$(date +%Y%m%d%H%M%S)
```

### 2. データベースのスケーリング

```bash
# インスタンスクラスの変更（例：db.t3.small に変更）
aws rds modify-db-instance \
  --db-instance-identifier aws-practice-dev-mysql \
  --db-instance-class db.t3.small \
  --apply-immediately
```

### 3. データベースのパフォーマンス確認

```bash
# CPU使用率の確認
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name CPUUtilization \
  --dimensions Name=DBInstanceIdentifier,Value=aws-practice-dev-mysql \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average,Maximum
```

## 🚨 セキュリティのポイント

1. **ネットワーク分離**: データベースは専用サブネットに配置
2. **暗号化**: データベースの保存時暗号化を有効化
3. **認証情報管理**: Secrets Manager による安全な認証情報管理
4. **アクセス制御**: セキュリティグループによるアクセス制限
5. **監査**: CloudTrail による API 活動の監視

## 🗑️ リソースの削除

```bash
# Key Pairの削除
aws ec2 delete-key-pair --key-name aws-practice-keypair
rm aws-practice-keypair.pem

# スタックの削除
aws cloudformation delete-stack \
  --stack-name aws-practice-complete

# 削除の確認
aws cloudformation describe-stacks \
  --stack-name aws-practice-complete \
  --query 'Stacks[0].StackStatus'
```

## 🎉 学習完了

### 習得したスキル

✅ **VPC ネットワーク設計**
- Multi-AZ でのサブネット設計
- セキュリティグループの適切な設定

✅ **Auto Scaling と Load Balancing**
- EC2 インスタンスの自動スケーリング
- Application Load Balancer の設定

✅ **RDS データベース管理**
- マネージドデータベースの設定
- バックアップとセキュリティ設定

✅ **3層アーキテクチャ**
- プレゼンテーション・アプリケーション・データ層の分離
- 高可用性と拡張性の実現

✅ **セキュリティベストプラクティス**
- 最小権限の原則
- 認証情報の安全な管理

## 📝 次のステップ

おめでとうございます！AWS 基礎インフラストラクチャーの学習が完了しました。

次は「**02-Web三層アーキテクチャ編**」で、より高度なWebアプリケーションの構築を学習します。

---

**💰 総コスト**: 
- ALB: 約$0.025/時間
- EC2 t3.micro x2: 約$0.02/時間
- RDS db.t3.micro: 約$0.015/時間
- **合計: 約$0.06/時間 (月額約$43)**

**🌟 達成したアーキテクチャ**:
完全な3層アーキテクチャによる高可用性Webアプリケーション！
