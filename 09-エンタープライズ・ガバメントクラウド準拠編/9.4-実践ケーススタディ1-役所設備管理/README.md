# 9.4 実践ケーススタディ1: 役所設備管理システム

## 🎯 このケーススタディで学ぶこと

**EC2ベースの既存システムをECS Fargateに移行**し、**ISMAP機密性レベル3準拠**のマルチアカウント構成で実装します。

### プロジェクト概要

```yaml
プロジェクト名: 役所設備管理システムECS移行
ベース: Sample-AWS-SubAgent リポジトリ

目標:
  - 運用工数: 40時間/月 → 10時間/月
  - 可用性: 99.9%以上
  - ISMAP機密性レベル3準拠
  - マルチアカウント構成
```

### 学習目標

- EC2 → ECS Fargate 移行の実践
- マルチアカウント構成での構築
- ISMAP準拠のセキュリティ実装
- CloudFormationによるIaC実装
- 運用自動化の実現

**学習時間**: 180分

## 🏗️ システム構成

### アーキテクチャ

```
┌───────────────── Shared Account ──────────────────┐
│                                                    │
│  ┌─────────────────────────────────────┐          │
│  │      Transit Gateway                │          │
│  └───────────┬─────────────────────────┘          │
│              │                                     │
│  ┌───────────┴──────────┐                         │
│  │  Security & Logging  │                         │
│  │  - Security Hub      │                         │
│  │  - GuardDuty         │                         │
│  │  - CloudTrail        │                         │
│  └──────────────────────┘                         │
└────────────────────────────────────────────────────┘
              │
┌─────────────▼─── Service Account ─────────────────┐
│                                                    │
│  ┌────────────────── VPC (10.1.0.0/16) ─────────┐ │
│  │                                               │ │
│  │  Public Subnet          Private Subnet       │ │
│  │  ┌──────────┐          ┌────────────────┐   │ │
│  │  │   ALB    │          │  ECS Fargate   │   │ │
│  │  │          │──────────│  - Frontend    │   │ │
│  │  └──────────┘          │  - Backend API │   │ │
│  │                        └────────────────┘   │ │
│  │                                               │ │
│  │                        ┌────────────────┐   │ │
│  │                        │  RDS           │   │ │
│  │                        │  PostgreSQL 14 │   │ │
│  │                        └────────────────┘   │ │
│  └───────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────┘
```

### 技術スタック

```yaml
インフラ:
  - CloudFormation (IaC)
  - Transit Gateway (ネットワーク統合)
  - VPC, Subnets, Security Groups

コンピューティング:
  - ECS Fargate (コンテナ)
  - Application Load Balancer

データベース:
  - Amazon RDS PostgreSQL 14
  - Multi-AZ構成
  - 自動バックアップ

アプリケーション:
  Frontend: React 18 + TypeScript
  Backend: Node.js 18 + Express + TypeScript

セキュリティ:
  - Cognito (認証)
  - KMS (暗号化)
  - Security Hub, GuardDuty
  - CloudTrail (監査ログ)
```

## 📋 移行前後の比較

### Before (EC2ベース)

```yaml
構成:
  - EC2インスタンス (t3.medium × 2)
  - 手動デプロイ
  - 手動スケーリング
  - パッチ適用が手動

課題:
  - 運用工数: 40時間/月
  - 可用性: 95%程度
  - スケールに時間がかかる
  - セキュリティパッチ適用が遅れる
```

### After (ECS Fargate)

```yaml
構成:
  - ECS Fargate (自動スケール)
  - CI/CDパイプライン
  - 自動デプロイ
  - 自動パッチ適用

改善:
  - 運用工数: 10時間/月（75%削減）
  - 可用性: 99.9%以上
  - 即座にスケール
  - コンテナイメージ更新で自動適用
```

## 🚀 ハンズオン: システム構築

### 前提条件

```bash
# 9.1-9.3の完了
# - Organizations セットアップ
# - Transit Gateway 構築
# - セキュリティ基盤構築

# 必要なツール
- Docker
- AWS CLI
- Node.js 18+
```

### Step 1: Service Account VPC 作成

```bash
# Service Accountに切り替え

cd cloudformation

# VPC作成
aws cloudformation create-stack \
  --stack-name facility-vpc \
  --template-body file://01-vpc.yaml \
  --parameters \
    ParameterKey=ProjectName,ParameterValue=facility-mgmt \
    ParameterKey=Environment,ParameterValue=prod \
    ParameterKey=VpcCidr,ParameterValue=10.1.0.0/16 \
  --capabilities CAPABILITY_IAM

# 完了待機
aws cloudformation wait stack-create-complete \
  --stack-name facility-vpc
```

### Step 2: RDS データベース作成

```bash
# RDSスタック作成
aws cloudformation create-stack \
  --stack-name facility-rds \
  --template-body file://02-rds.yaml \
  --parameters \
    ParameterKey=ProjectName,ParameterValue=facility-mgmt \
    ParameterKey=Environment,ParameterValue=prod \
    ParameterKey=DBInstanceClass,ParameterValue=db.t3.micro \
    ParameterKey=DBName,ParameterValue=facilitydb \
    ParameterKey=MasterUsername,ParameterValue=dbadmin \
    ParameterKey=MultiAZ,ParameterValue=true \
    ParameterKey=EnableKMSEncryption,ParameterValue=true \
  --capabilities CAPABILITY_IAM

# 完了待機
aws cloudformation wait stack-create-complete \
  --stack-name facility-rds

# DB接続情報の取得
DB_ENDPOINT=$(aws cloudformation describe-stacks \
  --stack-name facility-rds \
  --query 'Stacks[0].Outputs[?OutputKey==`DBEndpoint`].OutputValue' \
  --output text)

echo "RDS Endpoint: $DB_ENDPOINT"
```

### Step 3: ECR リポジトリ作成とイメージプッシュ

```bash
# ECRリポジトリ作成
aws ecr create-repository \
  --repository-name facility-mgmt/frontend \
  --encryption-configuration encryptionType=KMS

aws ecr create-repository \
  --repository-name facility-mgmt/backend \
  --encryption-configuration encryptionType=KMS

# ECRログイン
aws ecr get-login-password --region ap-northeast-1 | \
  docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com

# Dockerイメージビルドとプッシュ
cd ../app

# Frontendビルド
docker build -t facility-mgmt/frontend:latest -f frontend/Dockerfile frontend/
docker tag facility-mgmt/frontend:latest \
  ${ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/facility-mgmt/frontend:latest
docker push ${ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/facility-mgmt/frontend:latest

# Backendビルド
docker build -t facility-mgmt/backend:latest -f backend/Dockerfile backend/
docker tag facility-mgmt/backend:latest \
  ${ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/facility-mgmt/backend:latest
docker push ${ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/facility-mgmt/backend:latest
```

### Step 4: ECS Fargate クラスター作成

```bash
cd ../cloudformation

# ECSクラスターとサービス作成
aws cloudformation create-stack \
  --stack-name facility-ecs \
  --template-body file://03-ecs.yaml \
  --parameters \
    ParameterKey=ProjectName,ParameterValue=facility-mgmt \
    ParameterKey=Environment,ParameterValue=prod \
    ParameterKey=FrontendImage,ParameterValue=${ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/facility-mgmt/frontend:latest \
    ParameterKey=BackendImage,ParameterValue=${ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/facility-mgmt/backend:latest \
    ParameterKey=DesiredCount,ParameterValue=2 \
  --capabilities CAPABILITY_NAMED_IAM

# 完了待機
aws cloudformation wait stack-create-complete \
  --stack-name facility-ecs

# ALB URLの取得
ALB_URL=$(aws cloudformation describe-stacks \
  --stack-name facility-ecs \
  --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerURL`].OutputValue' \
  --output text)

echo "Application URL: http://$ALB_URL"
```

### Step 5: Cognito認証設定

```bash
# Cognitoユーザープール作成
aws cloudformation create-stack \
  --stack-name facility-cognito \
  --template-body file://04-cognito.yaml \
  --parameters \
    ParameterKey=ProjectName,ParameterValue=facility-mgmt \
    ParameterKey=Environment,ParameterValue=prod \
    ParameterKey=CallbackURL,ParameterValue=http://${ALB_URL}/callback \
  --capabilities CAPABILITY_IAM

# 完了待機
aws cloudformation wait stack-create-complete \
  --stack-name facility-cognito

# Cognito情報の取得
USER_POOL_ID=$(aws cloudformation describe-stacks \
  --stack-name facility-cognito \
  --query 'Stacks[0].Outputs[?OutputKey==`UserPoolId`].OutputValue' \
  --output text)

echo "User Pool ID: $USER_POOL_ID"
```

### Step 6: CI/CD パイプライン構築

```bash
# CodePipelineスタック作成
aws cloudformation create-stack \
  --stack-name facility-cicd \
  --template-body file://05-cicd.yaml \
  --parameters \
    ParameterKey=ProjectName,ParameterValue=facility-mgmt \
    ParameterKey=GitHubRepo,ParameterValue=your-org/facility-mgmt \
    ParameterKey=GitHubBranch,ParameterValue=main \
    ParameterKey=ECSClusterName,ParameterValue=facility-mgmt-cluster \
  --capabilities CAPABILITY_NAMED_IAM
```

## 🔍 動作確認

### システムアクセス

```bash
# ALB URLにアクセス
echo "Application URL: http://$ALB_URL"

# ヘルスチェック
curl http://$ALB_URL/health

# API動作確認
curl http://$ALB_URL/api/facilities
```

### セキュリティ確認

```bash
# Security Hubのコンプライアンススコア確認
aws securityhub get-findings \
  --filters 'ComplianceStatus=[{Value=FAILED,Comparison=EQUALS}]' \
  --max-results 10

# GuardDuty検知内容確認
aws guardduty list-findings \
  --detector-id $(aws guardduty list-detectors --query 'DetectorIds[0]' --output text) \
  --max-results 10
```

## 💰 コスト比較

### Before (EC2)

```yaml
EC2 (t3.medium × 2): $60/月
EBS: $20/月
RDS (db.t3.small): $30/月
ALB: $20/月

合計: 約$130/月
```

### After (ECS Fargate)

```yaml
ECS Fargate (0.5vCPU × 2): $35/月
RDS (db.t3.micro Multi-AZ): $30/月
ALB: $20/月
ECR: $1/月
その他(CloudWatch等): $10/月

合計: 約$96/月（26%削減）
```

## 📊 成果

### 運用工数削減

```yaml
Before:
  - パッチ適用: 8時間/月
  - デプロイ作業: 12時間/月
  - スケーリング作業: 8時間/月
  - 監視・対応: 12時間/月
  合計: 40時間/月

After:
  - パッチ適用: 自動
  - デプロイ作業: 自動（CI/CD）
  - スケーリング: 自動
  - 監視・対応: 8時間/月（アラート対応のみ）
  - その他運用: 2時間/月
  合計: 10時間/月（75%削減）
```

### 可用性向上

```yaml
Before: 95%
  - ダウンタイム: 年間438時間

After: 99.9%
  - ダウンタイム: 年間8.76時間
  - Multi-AZ, Auto Scaling, ヘルスチェック
```

## 📝 まとめ

### 学んだこと

- ✅ EC2 → ECS Fargate 移行の実践
- ✅ マルチアカウント構成での構築
- ✅ ISMAP機密性レベル3準拠の実装
- ✅ CloudFormationによる完全IaC化
- ✅ CI/CDパイプラインによる自動化
- ✅ 運用工数75%削減の実現

### 次のステップ

**[9.5 実践ケーススタディ2: 水産養殖統合管理システム](../9.5-実践ケーススタディ2-水産養殖管理/README.md)** に進んで、マイクロサービスアーキテクチャを学びます。

---

**次へ**: [9.5 実践ケーススタディ2: 水産養殖統合管理システム](../9.5-実践ケーススタディ2-水産養殖管理/README.md)
