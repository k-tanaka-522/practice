# 9.5 実践ケーススタディ2: 水産養殖統合管理システム

## 🎯 このケーススタディで学ぶこと

**マイクロサービスアーキテクチャ**で水産養殖事業者向けの統合管理システムを構築し、**ECS Fargate + DocumentDB**の実践的な活用を学びます。

### プロジェクト概要

```yaml
プロジェクト名: 水産養殖統合管理システム (Aqua Estimaits)
ベース: aqua-estimaits リポジトリ

機能:
  - 施設管理: 養殖池監視、設備保守
  - 生産管理: 計画立案、餌料管理、生育トラッキング
  - 販売管理: 受注、在庫、出荷管理
  - 財務管理: 収支管理、原価計算、財務分析
```

### 学習目標

- マイクロサービスアーキテクチャの設計と実装
- ECS Fargate でのマルチコンテナ運用
- DocumentDB (MongoDB互換) の活用
- API Gateway + Lambda によるBFF層構築
- マルチアカウント環境でのマイクロサービス

**学習時間**: 180分

## 🏗️ システム構成

### マイクロサービスアーキテクチャ

```
┌────────────── Frontend (React SPA) ──────────────┐
│                                                   │
│  CloudFront + S3                                  │
└───────────────────────┬───────────────────────────┘
                        │
┌───────────────────────▼─────────── BFF Layer ────┐
│                                                   │
│  API Gateway + Lambda (Backend for Frontend)     │
│  - ルーティング                                   │
│  - 認証・認可                                     │
│  - データ集約                                     │
└───────────┬───────────────────────────────────────┘
            │
┌───────────▼────── Microservices (ECS Fargate) ───┐
│                                                   │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌──────┐│
│  │Facility │  │Production│  │ Sales  │  │Finance││
│  │Service  │  │ Service │  │Service │  │Service││
│  │         │  │         │  │        │  │       ││
│  │10.1.1.0 │  │10.1.2.0 │  │10.1.3.0│  │10.1.4.││
│  └────┬────┘  └────┬────┘  └────┬───┘  └───┬───┘│
│       │            │            │          │    │
│  ┌────▼────────────▼────────────▼──────────▼───┐│
│  │         DocumentDB Cluster                  ││
│  │         (MongoDB互換)                       ││
│  └─────────────────────────────────────────────┘│
└───────────────────────────────────────────────────┘
```

### 技術スタック

```yaml
Frontend:
  - React 18
  - TypeScript
  - Material-UI
  - React Query

BFF (Backend for Frontend):
  - API Gateway
  - Lambda (Node.js 18)
  - Cognito認証

Microservices:
  - ECS Fargate
  - Node.js 18 + Express + TypeScript
  - Docker

Database:
  - Amazon DocumentDB (MongoDB 5.0互換)
  - Multi-AZ構成

Infrastructure:
  - Terraform (IaC)
  - Application Load Balancer
  - Route 53 (DNS)

CI/CD:
  - GitHub Actions
  - ECR (コンテナレジストリ)
```

## 📋 マイクロサービス設計

### サービス分割

#### 1. Facility Service (施設管理)

```yaml
責務:
  - 養殖池の情報管理
  - センサーデータ収集
  - 設備保守スケジュール
  - アラート管理

API:
  GET /facilities
  POST /facilities
  GET /facilities/:id
  PUT /facilities/:id
  GET /facilities/:id/sensors
  POST /facilities/:id/alerts

データモデル:
  - facilities (養殖池情報)
  - sensors (センサーデータ)
  - maintenance (保守記録)
  - alerts (アラート)
```

#### 2. Production Service (生産管理)

```yaml
責務:
  - 生産計画立案
  - 餌料管理
  - 生育状況トラッキング
  - 収穫管理

API:
  GET /production/plans
  POST /production/plans
  GET /production/feeds
  POST /production/feeds
  GET /production/growth/:facilityId
  POST /production/harvest

データモデル:
  - production_plans
  - feed_records
  - growth_tracking
  - harvests
```

#### 3. Sales Service (販売管理)

```yaml
責務:
  - 受注管理
  - 在庫管理
  - 出荷管理
  - 顧客管理

API:
  GET /sales/orders
  POST /sales/orders
  GET /sales/inventory
  PUT /sales/inventory
  GET /sales/shipments
  POST /sales/shipments

データモデル:
  - orders
  - inventory
  - shipments
  - customers
```

#### 4. Finance Service (財務管理)

```yaml
責務:
  - 収支管理
  - 原価計算
  - 財務分析
  - レポート生成

API:
  GET /finance/transactions
  POST /finance/transactions
  GET /finance/cost-analysis
  GET /finance/reports
  POST /finance/reports

データモデル:
  - transactions
  - cost_analysis
  - financial_reports
```

## 🚀 ハンズオン: システム構築

### 前提条件

```bash
# 9.1-9.3の完了
# Terraform インストール
terraform --version

# Docker
docker --version

# Node.js 18+
node --version
```

### Step 1: Terraform初期化とVPC作成

```bash
cd terraform

# 変数ファイル作成
cat > terraform.tfvars << EOF
project_name    = "aqua-estimaits"
environment     = "prod"
aws_region      = "ap-northeast-1"
vpc_cidr        = "10.2.0.0/16"
account_id      = "${ACCOUNT_ID}"
EOF

# Terraform初期化
terraform init

# VPC作成
terraform apply -target=module.vpc -auto-approve
```

### Step 2: DocumentDB クラスター作成

```bash
# DocumentDBクラスター作成
terraform apply -target=module.documentdb -auto-approve

# 接続情報の取得
DOCDB_ENDPOINT=$(terraform output -raw documentdb_endpoint)
DOCDB_PORT=$(terraform output -raw documentdb_port)

echo "DocumentDB Endpoint: $DOCDB_ENDPOINT:$DOCDB_PORT"
```

### Step 3: マイクロサービスのビルドとデプロイ

#### ECRリポジトリ作成

```bash
# 各サービスのECRリポジトリ作成
for service in facility production sales finance; do
  aws ecr create-repository \
    --repository-name aqua-estimaits/${service}-service \
    --encryption-configuration encryptionType=KMS
done
```

#### Dockerイメージビルド

```bash
cd ../services

# ECRログイン
aws ecr get-login-password --region ap-northeast-1 | \
  docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com

# 各サービスのビルドとプッシュ
for service in facility production sales finance; do
  echo "Building ${service}-service..."

  docker build -t aqua-estimaits/${service}-service:latest \
    -f ${service}-service/Dockerfile \
    ${service}-service/

  docker tag aqua-estimaits/${service}-service:latest \
    ${ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/aqua-estimaits/${service}-service:latest

  docker push ${ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/aqua-estimaits/${service}-service:latest

  echo "${service}-service pushed successfully"
done
```

### Step 4: ECS Fargate クラスターとサービス作成

```bash
cd ../terraform

# ECSクラスターとサービス作成
terraform apply -target=module.ecs -auto-approve

# サービス起動確認
aws ecs list-services \
  --cluster aqua-estimaits-cluster \
  --region ap-northeast-1
```

### Step 5: API Gateway + Lambda (BFF層) 構築

```bash
# Lambda関数のデプロイ
cd ../bff
npm install
npm run build

# Lambda関数パッケージ作成
zip -r function.zip dist/ node_modules/

# Terraformでデプロイ
cd ../terraform
terraform apply -target=module.api_gateway -auto-approve

# API Gateway URLの取得
API_GATEWAY_URL=$(terraform output -raw api_gateway_url)
echo "API Gateway URL: $API_GATEWAY_URL"
```

### Step 6: フロントエンドデプロイ

```bash
# Reactアプリビルド
cd ../frontend

# 環境変数設定
cat > .env.production << EOF
REACT_APP_API_URL=$API_GATEWAY_URL
REACT_APP_COGNITO_USER_POOL_ID=$USER_POOL_ID
REACT_APP_COGNITO_CLIENT_ID=$CLIENT_ID
EOF

# ビルド
npm install
npm run build

# S3にデプロイ
cd ../terraform
terraform apply -target=module.frontend -auto-approve

# CloudFront URLの取得
CLOUDFRONT_URL=$(terraform output -raw cloudfront_url)
echo "Application URL: https://$CLOUDFRONT_URL"
```

## 🔍 動作確認

### サービス間通信テスト

```bash
# Facility Serviceのヘルスチェック
curl http://$ALB_URL/facility/health

# 施設一覧取得
curl http://$ALB_URL/facility/facilities

# 生産計画取得
curl http://$ALB_URL/production/plans

# 在庫確認
curl http://$ALB_URL/sales/inventory

# 財務レポート取得
curl http://$ALB_URL/finance/reports
```

### DocumentDB接続確認

```bash
# DocumentDBに接続
mongo --ssl --host $DOCDB_ENDPOINT:$DOCDB_PORT \
  --sslCAFile rds-combined-ca-bundle.pem \
  --username admin \
  --password <password>

# データベース確認
show dbs
use aqua_estimaits
show collections
```

## 💰 コスト見積もり

```yaml
ECS Fargate (4サービス):
  - 0.5vCPU × 4 = $70/月

DocumentDB:
  - db.t3.medium × 3 (1 primary + 2 replicas): $210/月

API Gateway:
  - 100万リクエスト/月: $3.50/月

Lambda (BFF):
  - 100万リクエスト/月: $0.20/月

CloudFront + S3:
  - $10/月

ALB:
  - $20/月

その他(CloudWatch等):
  - $15/月

合計: 約$328/月
```

## 📊 パフォーマンス目標

```yaml
可用性: 99.9%以上
レスポンスタイム:
  - API Gateway: < 100ms
  - マイクロサービス: < 200ms
  - データベースクエリ: < 50ms

スループット:
  - 1000 requests/秒以上

スケーリング:
  - CPU 70%でオートスケール
  - 最小2タスク、最大10タスク
```

## 📝 まとめ

### 学んだこと

- ✅ マイクロサービスアーキテクチャの設計と実装
- ✅ ECS Fargate でのマルチコンテナ運用
- ✅ DocumentDB (MongoDB互換) の活用
- ✅ API Gateway + Lambda によるBFF層
- ✅ Terraform によるIaC実装
- ✅ マルチアカウント環境での構築

### 実務への応用

```yaml
このケーススタディで学んだスキル:
  - マイクロサービス分割の考え方
  - サービス間通信の設計
  - ドメイン駆動設計の基礎
  - コンテナオーケストレーション
  - NoSQLデータベース設計
  - フルスタックアプリケーション構築

応用可能な業界:
  - 農業管理システム
  - 製造業MES
  - 物流管理システム
  - 小売業POS/在庫管理
  - ヘルスケア管理システム
```

## 🎓 09編 完了！

おめでとうございます！9.1-9.5すべてのセクションを完了しました。

### 習得したスキル

1. **マルチアカウント戦略** (9.1)
   - AWS Organizations
   - OU設計
   - Service Control Policies

2. **ネットワーク統合** (9.2)
   - Transit Gateway
   - クロスアカウントVPC接続
   - Direct Connect基礎

3. **セキュリティ・コンプライアンス** (9.3)
   - ISMAP機密性レベル3準拠
   - ガバメントクラウド要件
   - セキュリティ監視基盤

4. **実践: 役所設備管理システム** (9.4)
   - EC2 → ECS Fargate移行
   - 運用工数75%削減
   - 可用性99.9%達成

5. **実践: 水産養殖統合管理** (9.5)
   - マイクロサービスアーキテクチャ
   - DocumentDB活用
   - フルスタック構築

### 次のステップ

```yaml
実務での活用:
  - 学んだ構成を自社システムに適用
  - チームメンバーへの知識共有
  - ベストプラクティスの確立

さらなる学習:
  - AWS認定資格取得
    - Solutions Architect Professional
    - Security Specialty
  - Advanced トピック
    - Service Mesh (App Mesh)
    - Kubernetes (EKS)
    - Serverless Framework
```

---

**お疲れ様でした！エンタープライズ級AWSエンジニアへの道を歩み始めています。** 🎉
