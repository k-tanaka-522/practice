# 基礎インフラストラクチャー編

## 概要

このセクションでは、AWS上でセキュアで拡張性のあるインフラストラクチャーを構築するための基礎を学習します。IAMからネットワーク、CI/CDまで、実運用に必要な要素を段階的に習得できます。

## 学習目標

- 🔐 **IAMとセキュリティ**: ユーザー管理、ロール設計、セキュリティポリシー
- 🌐 **VPCネットワーク**: ネットワーク設計、サブネット、セキュリティグループ
- 🚀 **CI/CD連携**: GitHub ActionsとAWS連携
- 💻 **コンピューティング**: EC2、ECS、Lambda
- 📊 **Infrastructure as Code**: CloudFormationベストプラクティス

## アーキテクチャ概要

```
┌─────────────────────────────────────────────────────────────────┐
│                        AWS Account                               │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                    VPC (10.0.0.0/16)                     │  │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌────────────┐ │  │
│  │  │  Public Subnet  │  │ Private Subnet  │  │ DB Subnet  │ │  │
│  │  │   (Web Tier)    │  │  (App Tier)     │  │            │ │  │
│  │  └─────────────────┘  └─────────────────┘  └────────────┘ │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌───────────────┐    ┌──────────────┐    ┌─────────────────┐  │
│  │      IAM      │    │ GitHub OIDC  │    │   CloudTrail    │  │
│  │   Policies    │    │  Integration │    │   Monitoring    │  │
│  └───────────────┘    └──────────────┘    └─────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## 学習パス

### 1.1 AWS環境セットアップ
- **1.1.1** アカウント設定とIAM
- **1.1.2** VPCとネットワーク基礎  
- **1.1.3** GitHub ActionsとAWS連携

### 1.2 コンピューティング基礎
- **1.2.1** EC2インスタンス管理
- **1.2.2** ECSとコンテナ基礎
- **1.2.3** Lambda関数デプロイ

## クイックスタート

### 前提条件

```bash
# AWS CLI インストール確認
aws --version
# aws-cli/2.13.0 以上必要

# 認証設定確認
aws sts get-caller-identity

# 必要な権限の確認
aws iam get-user
```

### 全体デプロイ

```bash
# 基礎インフラストラクチャーの一括デプロイ
./scripts/deploy-infrastructure.sh deploy-all

# 段階的デプロイ
./scripts/deploy-infrastructure.sh deploy-iam
./scripts/deploy-infrastructure.sh deploy-vpc
./scripts/deploy-infrastructure.sh deploy-compute
```

## 学習コンテンツ詳細

### 🔐 1.1.1 アカウント設定とIAM

**学習内容:**
- AWS アカウントのセキュリティ設定
- IAM ユーザー、グループ、ロールの設計
- パスワードポリシーとMFA設定
- CloudTrailによる監査ログ

**実装内容:**
- IAM グループとポリシーの作成
- パスワードポリシーの設定
- CloudTrail 監査設定
- セキュリティアラートの設定

### 🌐 1.1.2 VPCとネットワーク基礎

**学習内容:**
- VPCの設計原則
- サブネット設計（Public/Private/DB）
- セキュリティグループとNACL
- NATゲートウェイとインターネットゲートウェイ

**実装内容:**
- マルチAZ対応VPC構築
- 3層ネットワーク設計
- セキュリティグループ設定
- ネットワーク監視設定

### 🚀 1.1.3 GitHub ActionsとAWS連携

**学習内容:**
- OIDC による認証設定
- GitHub Actions ワークフロー設計
- CI/CD パイプライン構築
- セキュリティベストプラクティス

**実装内容:**
- OIDC プロバイダー設定
- GitHub Actions 用 IAM ロール
- デプロイワークフロー
- セキュリティスキャン設定

### 💻 1.2.1 EC2インスタンス管理

**学習内容:**
- EC2 インスタンスタイプ選択
- Auto Scaling 設定
- ELB による負荷分散
- 監視とログ管理

**実装内容:**
- Auto Scaling Group 構築
- Application Load Balancer 設定
- CloudWatch 監視設定
- Systems Manager 連携

### 🐳 1.2.2 ECSとコンテナ基礎

**学習内容:**
- コンテナ化の基礎
- ECS クラスター設計
- Fargate vs EC2 起動タイプ
- サービス発見とロードバランシング

**実装内容:**
- ECS クラスター構築
- コンテナアプリケーションデプロイ
- サービス連携設定
- 監視とログ設定

### ⚡ 1.2.3 Lambda関数デプロイ

**学習内容:**
- サーバーレス アーキテクチャ
- Lambda 関数設計
- イベント駆動処理
- 監視とエラーハンドリング

**実装内容:**
- Lambda 関数デプロイ
- API Gateway 連携
- EventBridge 連携
- 監視とアラート設定

## 🧪 動作確認とテスト

### インフラテスト

```bash
# VPC ネットワーク疎通確認
./scripts/test-infrastructure.sh test-network

# セキュリティ設定確認
./scripts/test-infrastructure.sh test-security

# CI/CD パイプラインテスト
./scripts/test-infrastructure.sh test-cicd
```

### セキュリティ監査

```bash
# IAM ポリシー監査
aws iam generate-credential-report
aws iam get-credential-report

# CloudTrail ログ確認
aws logs filter-log-events \
  --log-group-name "CloudTrail/ManagementEvents"

# セキュリティグループ監査
aws ec2 describe-security-groups \
  --query 'SecurityGroups[?IpPermissions[?IpRanges[?CidrIp==`0.0.0.0/0`]]]'
```

## 📊 監視とアラート

### CloudWatch ダッシュボード

- **IAM**: ログイン試行、権限エラー
- **VPC**: ネットワーク使用量、フローログ
- **EC2**: CPU、メモリ、ディスク使用率
- **Lambda**: 実行時間、エラー率

### アラート設定

```bash
# 高権限操作の監視
aws cloudwatch put-metric-alarm \
  --alarm-name "Root-Account-Usage" \
  --alarm-description "Root account login detected"

# 異常なネットワークトラフィック
aws cloudwatch put-metric-alarm \
  --alarm-name "High-Network-Traffic" \
  --alarm-description "Unusual network activity"
```

## 🛠️ トラブルシューティング

### よくある問題

#### 1. IAM 権限エラー

```bash
# ポリシーシミュレーター使用
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::123456789012:user/testuser \
  --action-names s3:GetObject \
  --resource-arns arn:aws:s3:::mybucket/mykey
```

#### 2. VPC ネットワーク問題

```bash
# ルートテーブル確認
aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=vpc-12345678"

# セキュリティグループ確認
aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=vpc-12345678"
```

#### 3. CI/CD パイプライン失敗

```bash
# CloudFormation スタックイベント確認
aws cloudformation describe-stack-events \
  --stack-name infrastructure-stack

# Lambda ログ確認
aws logs tail /aws/lambda/deployment-function --follow
```

## 📚 参考資料

### AWS ドキュメント
- [IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [VPC User Guide](https://docs.aws.amazon.com/vpc/latest/userguide/)
- [Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)

### セキュリティガイドライン
- [AWS Security Best Practices](https://aws.amazon.com/security/)
- [CIS AWS Foundations Benchmark](https://www.cisecurity.org/benchmark/amazon_web_services)

## 🔧 カスタマイズポイント

### 環境別設定

```yaml
# development 環境
Environment: dev
InstanceType: t3.micro
MultiAZ: false

# production 環境  
Environment: prod
InstanceType: t3.medium
MultiAZ: true
BackupRetention: 30
```

### コスト最適化

```yaml
# スポットインスタンス使用
SpotFleetConfig:
  TargetCapacity: 2
  AllocationStrategy: diversified

# 自動停止設定
AutoShutdown:
  Enabled: true
  Schedule: "cron(0 18 * * MON-FRI)"
```

## 🧹 クリーンアップ

```bash
# 全リソース削除
./scripts/deploy-infrastructure.sh cleanup-all

# 段階的削除
./scripts/deploy-infrastructure.sh cleanup-compute
./scripts/deploy-infrastructure.sh cleanup-vpc
./scripts/deploy-infrastructure.sh cleanup-iam
```

## 📈 次のステップ

完了後は以下に進んでください：

1. **[Web三層アーキテクチャ編](../02-Web三層アーキテクチャ編/README.md)** - アプリケーション層の構築
2. **[CRUDシステム実装編](../03-CRUDシステム実装編/README.md)** - 認証とデータ操作
3. **[データ分析基盤編](../04-データ分析基盤編/README.md)** - データパイプライン構築

---

## 🎯 学習チェックリスト

### 基礎知識
- [ ] AWSアカウントセキュリティ設定
- [ ] IAMの基本概念（ユーザー、グループ、ロール、ポリシー）
- [ ] VPCネットワーク設計原則
- [ ] セキュリティグループとNACLの違い

### 実装スキル
- [ ] CloudFormationテンプレート作成
- [ ] IAMポリシー設計と実装
- [ ] VPCとサブネット設計
- [ ] GitHub Actions連携設定

### 運用知識
- [ ] CloudWatch監視設定
- [ ] CloudTrail監査設定  
- [ ] セキュリティベストプラクティス適用
- [ ] トラブルシューティング手法

**準備ができたら次のセクションへ進みましょう！**